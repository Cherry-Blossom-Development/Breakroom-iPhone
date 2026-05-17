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

            // Page Sections
            Section {
                ForEach($sections) { $section in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.type == "content" ? "Content" : "Collections")
                                .font(.subheadline)
                            Text(section.type == "content"
                                ? "Custom text and formatting"
                                : "Your product collections")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $section.visible)
                            .labelsHidden()
                    }
                }
            } header: {
                Text("Page Sections")
            } footer: {
                Text("Toggle to show or hide sections on your public store.")
            }

            // Collections section title
            if let collectionsSection = sections.first(where: { $0.type == "collections" && $0.visible }) {
                Section {
                    TextField("My Collections", text: Binding(
                        get: { collectionsSection.title ?? "" },
                        set: { newValue in
                            if let index = sections.firstIndex(where: { $0.id == "collections" }) {
                                sections[index].title = newValue.isEmpty ? nil : newValue
                            }
                        }
                    ))
                } header: {
                    Text("Collections Section Title")
                }
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

    // MARK: - Actions

    private func loadStorefront() async {
        isLoading = true
        do {
            if let storefront = try await CollectionsAPIService.getStorefront() {
                storeUrl = storefront.storeUrl ?? ""
                pageTitle = storefront.pageTitle ?? ""
                contentBody = storefront.content ?? ""
                if let savedSections = storefront.settings?.sections {
                    sections = savedSections
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

        let settings = StorefrontSettings(sections: sections)

        do {
            try await CollectionsAPIService.saveStorefront(
                storeUrl: storeUrl.isEmpty ? nil : storeUrl,
                pageTitle: pageTitle.isEmpty ? nil : pageTitle,
                content: contentBody.isEmpty ? nil : contentBody,
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
