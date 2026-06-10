import SwiftUI

struct StorefrontSetupView: View {
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var showSuccess = false

    // Form fields
    @State private var storeUrl = ""
    @State private var pageTitle = ""
    @State private var contentBody = ""
    @State private var sections: [StorefrontSection] = [
        StorefrontSection(id: "content", type: "content", visible: true, title: nil),
        StorefrontSection(id: "collections", type: "collections", visible: true, title: "My Collections")
    ]

    // Display settings
    @State private var collectionsDisplaySize = "small"  // "small", "medium", "large"
    @State private var collectionsAspectRatio = "landscape"  // "portrait", "square", "landscape"

    // Custom domain
    @State private var externalUrl = ""

    // URL checking
    @State private var urlCheckTask: Task<Void, Never>?
    @State private var isCheckingUrl = false
    @State private var urlAvailable: Bool?
    @State private var urlReason: String?

    private var baseUrl: String {
        APIClient.shared.baseURL
    }

    private var canSave: Bool {
        !storeUrl.isEmpty && !isCheckingUrl && urlAvailable != false
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading storefront...")
            } else {
                formContent
            }
        }
        .navigationTitle("Storefront")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !storeUrl.isEmpty && urlAvailable != false {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openStore()
                    } label: {
                        Text("View ↗")
                    }
                }
            }
        }
        .task {
            await loadStorefront()
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error)
            }
        }
    }

    private var formContent: some View {
        Form {
            // Store URL section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your store will be publicly accessible at this address.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        Text("\(baseUrl)/store/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        TextField("my-store", text: $storeUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                            .onChange(of: storeUrl) { _, newValue in
                                // Sanitize input
                                let sanitized = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
                                if sanitized != newValue {
                                    storeUrl = sanitized
                                }
                                checkUrlAvailability()
                            }
                    }

                    // URL status
                    if isCheckingUrl {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !storeUrl.isEmpty {
                        if urlAvailable == true {
                            Text("Available")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if urlAvailable == false {
                            Text(urlReason ?? "Not available")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Store URL")
            }

            // Page Title section
            Section {
                TextField("e.g. My Art Store", text: $pageTitle)
            } header: {
                Text("Page Title")
            } footer: {
                Text("Shown as the main heading on your store page.")
            }

            // Custom Domain section
            Section {
                TextField("https://www.myshop.com", text: $externalUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if externalUrl.isEmpty {
                    NavigationLink {
                        CustomDomainSetupView()
                    } label: {
                        Text("Learn how to use your own domain")
                            .font(.caption)
                    }
                }
            } header: {
                Text("Custom Domain")
            } footer: {
                Text("If you've pointed your own domain at this store, enter it here so visitors know where to find you.")
            }

            // Page Sections
            Section {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.type == "content" ? "Content" : "Collections")
                                    .font(.subheadline.weight(.semibold))
                                Text(section.type == "content"
                                    ? "A free-form text block shown above your collections"
                                    : "Displays all your collections on the public store")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Reorder buttons
                            Button {
                                moveSectionUp(at: index)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(index == 0)

                            Button {
                                moveSectionDown(at: index)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(index == sections.count - 1)

                            Toggle("", isOn: Binding(
                                get: { sections[index].visible },
                                set: { sections[index].visible = $0 }
                            ))
                            .labelsHidden()
                        }

                        // Section-specific settings when visible
                        if section.visible {
                            if section.type == "collections" {
                                collectionsSettings
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Page Sections")
            } footer: {
                Text("Use arrows to reorder sections. Toggle to show or hide.")
            }

            // Save button
            Section {
                Button {
                    Task { await saveStorefront() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(showSuccess ? "Saved!" : "Save Storefront")
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave || isSaving)
            }
        }
    }

    // MARK: - Collections Settings

    private var collectionsSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section heading
            VStack(alignment: .leading, spacing: 4) {
                Text("Section heading")
                    .font(.caption.weight(.medium))
                TextField("My Collections", text: Binding(
                    get: {
                        sections.first(where: { $0.id == "collections" })?.title ?? ""
                    },
                    set: { newValue in
                        if let index = sections.firstIndex(where: { $0.id == "collections" }) {
                            sections[index].title = newValue.isEmpty ? nil : newValue
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Display size
            VStack(alignment: .leading, spacing: 4) {
                Text("Display size")
                    .font(.caption.weight(.medium))
                Text("Controls how many collections appear per row.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker("", selection: $collectionsDisplaySize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
            }

            // Aspect ratio
            VStack(alignment: .leading, spacing: 4) {
                Text("Aspect ratio")
                    .font(.caption.weight(.medium))
                Text("Shape of each collection card. Portrait and Landscape use the golden ratio.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker("", selection: $collectionsAspectRatio) {
                    Text("Portrait").tag("portrait")
                    Text("Square").tag("square")
                    Text("Landscape").tag("landscape")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Reordering

    private func moveSectionUp(at index: Int) {
        guard index > 0 else { return }
        sections.swapAt(index, index - 1)
    }

    private func moveSectionDown(at index: Int) {
        guard index < sections.count - 1 else { return }
        sections.swapAt(index, index + 1)
    }

    // MARK: - Actions

    private func loadStorefront() async {
        isLoading = true
        do {
            if let storefront = try await CollectionsAPIService.getStorefront() {
                storeUrl = storefront.storeUrl ?? ""
                pageTitle = storefront.pageTitle ?? ""
                contentBody = storefront.content ?? ""
                externalUrl = storefront.externalUrl ?? ""
                if let savedSections = storefront.settings?.sections {
                    sections = savedSections
                }
                if let displaySize = storefront.settings?.collectionsDisplaySize {
                    collectionsDisplaySize = displaySize
                }
                if let aspectRatio = storefront.settings?.collectionsAspectRatio {
                    collectionsAspectRatio = aspectRatio
                }
                if !storeUrl.isEmpty {
                    urlAvailable = true
                }
            }
        } catch {
            // No storefront yet - use defaults
        }
        isLoading = false
    }

    private func checkUrlAvailability() {
        urlCheckTask?.cancel()
        urlAvailable = nil
        urlReason = nil

        guard storeUrl.count >= 3 else { return }

        urlCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            isCheckingUrl = true
            do {
                let result = try await CollectionsAPIService.checkStoreUrl(storeUrl)
                if !Task.isCancelled {
                    urlAvailable = result.available
                    urlReason = result.reason
                }
            } catch {
                // Ignore errors during URL check
            }
            isCheckingUrl = false
        }
    }

    private func saveStorefront() async {
        isSaving = true
        error = nil
        showSuccess = false

        let settings = StorefrontSettings(
            sections: sections,
            collectionsDisplaySize: collectionsDisplaySize,
            collectionsAspectRatio: collectionsAspectRatio
        )

        do {
            try await CollectionsAPIService.saveStorefront(
                storeUrl: storeUrl.isEmpty ? nil : storeUrl,
                pageTitle: pageTitle.isEmpty ? nil : pageTitle,
                content: contentBody.isEmpty ? nil : contentBody,
                externalUrl: externalUrl.isEmpty ? nil : externalUrl,
                settings: settings
            )
            showSuccess = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSuccess = false
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    private func openStore() {
        guard !storeUrl.isEmpty else { return }
        if let url = URL(string: "\(baseUrl)/store/\(storeUrl)") {
            UIApplication.shared.open(url)
        }
    }
}
