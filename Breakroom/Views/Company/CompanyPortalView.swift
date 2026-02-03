import SwiftUI

struct CompanyPortalView: View {
    enum Tab: String, CaseIterable {
        case myCompanies = "My Companies"
        case search = "Search"
        case create = "Create"
    }

    @State private var selectedTab: Tab = .myCompanies
    @State private var myCompanies: [MyCompany] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Search
    @State private var searchText = ""
    @State private var searchResults: [CompanySearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?

    // Create
    @State private var companyName = ""
    @State private var companyDescription = ""
    @State private var companyAddress = ""
    @State private var companyCity = ""
    @State private var companyState = ""
    @State private var companyCountry = ""
    @State private var companyPostalCode = ""
    @State private var companyPhone = ""
    @State private var companyEmail = ""
    @State private var companyWebsite = ""
    @State private var employeeTitle = ""
    @State private var isCreating = false

    // Detail navigation
    @State private var selectedCompanyId: Int?

    private var isShowingDetail: Binding<Bool> {
        Binding(
            get: { selectedCompanyId != nil },
            set: { if !$0 { selectedCompanyId = nil } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch selectedTab {
                case .myCompanies:
                    myCompaniesTab
                case .search:
                    searchTab
                case .create:
                    createTab
                }
            }
        }
        .navigationTitle("Company")
        .navigationDestination(isPresented: isShowingDetail) {
            if let id = selectedCompanyId {
                CompanyDetailView(companyId: id)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .task {
            await loadMyCompanies()
        }
    }

    // MARK: - My Companies Tab

    private var myCompaniesTab: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if myCompanies.isEmpty {
                ContentUnavailableView(
                    "No Companies",
                    systemImage: "building.2",
                    description: Text("You aren't part of any company yet. Create one or search for an existing company.")
                )
            } else {
                List(myCompanies) { company in
                    Button {
                        selectedCompanyId = company.id
                    } label: {
                        myCompanyRow(company)
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)
                .refreshable {
                    await loadMyCompanies()
                }
            }
        }
    }

    private func myCompanyRow(_ company: MyCompany) -> some View {
        HStack(spacing: 12) {
            // Company icon
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(company.name.prefix(1).uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(company.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if let badge = company.roleBadge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(company.isOwnerBool ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                            .foregroundStyle(company.isOwnerBool ? .orange : .blue)
                            .clipShape(Capsule())
                    }
                }

                if let title = company.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !company.locationString.isEmpty {
                    Text(company.locationString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search companies...", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .onSubmit { performSearch() }
                    .onChange(of: searchText) { _, newValue in
                        debounceSearch(newValue)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Results
            if isSearching {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if searchResults.isEmpty && hasSearched {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No companies match \"\(searchText)\".")
                )
            } else if !searchResults.isEmpty {
                List(searchResults) { company in
                    Button {
                        selectedCompanyId = company.id
                    } label: {
                        searchResultRow(company)
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView(
                    "Search Companies",
                    systemImage: "building.2.crop.circle",
                    description: Text("Type at least 2 characters to search.")
                )
            }
        }
    }

    private func searchResultRow(_ company: CompanySearchResult) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(company.name.prefix(1).uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(company.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if let desc = company.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !company.locationString.isEmpty {
                    Text(company.locationString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Create Tab

    private var createTab: some View {
        Form {
            Section("Company Info") {
                TextField("Company Name *", text: $companyName)
                TextField("Description", text: $companyDescription, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Your Role") {
                TextField("Your Job Title *", text: $employeeTitle)
            }

            Section("Location") {
                TextField("Address", text: $companyAddress)
                TextField("City", text: $companyCity)
                TextField("State / Province", text: $companyState)
                TextField("Country", text: $companyCountry)
                TextField("Postal Code", text: $companyPostalCode)
            }

            Section("Contact") {
                TextField("Phone", text: $companyPhone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $companyEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Website", text: $companyWebsite)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }

            Section {
                Button {
                    Task { await createCompany() }
                } label: {
                    HStack {
                        Spacer()
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                            Text("Creating...")
                        } else {
                            Text("Create Company")
                        }
                        Spacer()
                    }
                }
                .disabled(companyName.trimmingCharacters(in: .whitespaces).isEmpty ||
                          employeeTitle.trimmingCharacters(in: .whitespaces).isEmpty ||
                          isCreating)
            }
        }
    }

    // MARK: - Data Loading

    private func loadMyCompanies() async {
        do {
            myCompanies = try await CompanyAPIService.getMyCompanies()
        } catch {
            errorMessage = error.localizedDescription
            if isLoading { showError = true }
        }
        isLoading = false
    }

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            hasSearched = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearchQuery(trimmed)
        }
    }

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        Task { await performSearchQuery(trimmed) }
    }

    private func performSearchQuery(_ query: String) async {
        isSearching = true
        do {
            searchResults = try await CompanyAPIService.searchCompanies(query: query)
            hasSearched = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSearching = false
    }

    private func createCompany() async {
        isCreating = true
        let name = companyName.trimmingCharacters(in: .whitespaces)
        let title = employeeTitle.trimmingCharacters(in: .whitespaces)

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }

        do {
            _ = try await CompanyAPIService.createCompany(
                name: name,
                description: nilIfEmpty(companyDescription),
                address: nilIfEmpty(companyAddress),
                city: nilIfEmpty(companyCity),
                state: nilIfEmpty(companyState),
                country: nilIfEmpty(companyCountry),
                postalCode: nilIfEmpty(companyPostalCode),
                phone: nilIfEmpty(companyPhone),
                email: nilIfEmpty(companyEmail),
                website: nilIfEmpty(companyWebsite),
                employeeTitle: title
            )

            // Reset form
            companyName = ""
            companyDescription = ""
            companyAddress = ""
            companyCity = ""
            companyState = ""
            companyCountry = ""
            companyPostalCode = ""
            companyPhone = ""
            companyEmail = ""
            companyWebsite = ""
            employeeTitle = ""

            // Refresh my companies and switch tab
            await loadMyCompanies()
            selectedTab = .myCompanies
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isCreating = false
    }
}

// MARK: - Company Detail View (basic info for now)

struct CompanyDetailView: View {
    let companyId: Int

    @State private var detail: CompanyDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showEditSheet = false

    private var canEdit: Bool {
        guard let role = detail?.userRole else { return false }
        return role.isOwnerBool || role.isAdminBool
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail {
                companyContent(detail)
            } else {
                ContentUnavailableView(
                    "Could Not Load Company",
                    systemImage: "building.2",
                    description: Text("Pull to refresh and try again.")
                )
            }
        }
        .navigationTitle(detail?.company.name ?? "Company")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", systemImage: "pencil") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let company = detail?.company {
                EditCompanyView(company: company) { updated in
                    detail = CompanyDetailResponse(
                        company: updated,
                        employees: detail?.employees ?? [],
                        userRole: detail?.userRole
                    )
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .refreshable {
            await loadDetail()
        }
        .task {
            await loadDetail()
        }
    }

    private func companyContent(_ detail: CompanyDetailResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.company.name)
                        .font(.title2.bold())

                    if let role = detail.userRole {
                        HStack(spacing: 8) {
                            if let title = role.title, !title.isEmpty {
                                Text(title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if role.isOwnerBool {
                                roleBadge("Owner", color: .orange)
                            } else if role.isAdminBool {
                                roleBadge("Admin", color: .blue)
                            }
                        }
                    }
                }

                // Info section
                if hasCompanyInfo(detail.company) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let desc = detail.company.description, !desc.isEmpty {
                            infoSection("About", text: desc)
                        }

                        if !detail.company.locationString.isEmpty {
                            infoRow("Location", value: detail.company.locationString)
                        }
                        if let address = detail.company.address, !address.isEmpty {
                            infoRow("Address", value: address)
                        }
                        if let phone = detail.company.phone, !phone.isEmpty {
                            infoRow("Phone", value: phone)
                        }
                        if let email = detail.company.email, !email.isEmpty {
                            infoRow("Email", value: email)
                        }
                        if let website = detail.company.website, !website.isEmpty {
                            infoRow("Website", value: website)
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Employees section
                if !detail.employees.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Employees (\(detail.employees.count))")
                            .font(.headline)

                        ForEach(detail.employees) { emp in
                            employeeRow(emp)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func roleBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func infoSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(14)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func employeeRow(_ emp: CompanyEmployee) -> some View {
        HStack(spacing: 10) {
            // Avatar
            Group {
                if let url = emp.photoURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsCircle(emp)
                    }
                } else {
                    initialsCircle(emp)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(emp.displayName)
                        .font(.subheadline.weight(.medium))
                    if emp.isOwnerBool {
                        roleBadge("Owner", color: .orange)
                    } else if emp.isAdminBool {
                        roleBadge("Admin", color: .blue)
                    }
                }
                if let title = emp.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func initialsCircle(_ emp: CompanyEmployee) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .overlay {
                Text((emp.displayName.first ?? Character("?")).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
            }
    }

    private func hasCompanyInfo(_ company: CompanyDetail) -> Bool {
        (company.description != nil && !company.description!.isEmpty) ||
        !company.locationString.isEmpty ||
        (company.phone != nil && !company.phone!.isEmpty) ||
        (company.email != nil && !company.email!.isEmpty) ||
        (company.website != nil && !company.website!.isEmpty) ||
        (company.address != nil && !company.address!.isEmpty)
    }

    private func loadDetail() async {
        do {
            detail = try await CompanyAPIService.getCompany(id: companyId)
        } catch {
            errorMessage = error.localizedDescription
            if detail == nil { showError = true }
        }
        isLoading = false
    }
}

// MARK: - Edit Company View

struct EditCompanyView: View {
    let company: CompanyDetail
    let onSave: (CompanyDetail) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var companyDescription: String
    @State private var address: String
    @State private var city: String
    @State private var state: String
    @State private var country: String
    @State private var postalCode: String
    @State private var phone: String
    @State private var email: String
    @State private var website: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(company: CompanyDetail, onSave: @escaping (CompanyDetail) -> Void) {
        self.company = company
        self.onSave = onSave
        _name = State(initialValue: company.name)
        _companyDescription = State(initialValue: company.description ?? "")
        _address = State(initialValue: company.address ?? "")
        _city = State(initialValue: company.city ?? "")
        _state = State(initialValue: company.state ?? "")
        _country = State(initialValue: company.country ?? "")
        _postalCode = State(initialValue: company.postalCode ?? "")
        _phone = State(initialValue: company.phone ?? "")
        _email = State(initialValue: company.email ?? "")
        _website = State(initialValue: company.website ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company Info") {
                    TextField("Company Name *", text: $name)
                    TextField("Description", text: $companyDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Location") {
                    TextField("Address", text: $address)
                    TextField("City", text: $city)
                    TextField("State / Province", text: $state)
                    TextField("Country", text: $country)
                    TextField("Postal Code", text: $postalCode)
                }

                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Website", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Edit Company")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }

        do {
            let updated = try await CompanyAPIService.updateCompany(
                id: company.id,
                name: name.trimmingCharacters(in: .whitespaces),
                description: nilIfEmpty(companyDescription),
                address: nilIfEmpty(address),
                city: nilIfEmpty(city),
                state: nilIfEmpty(state),
                country: nilIfEmpty(country),
                postalCode: nilIfEmpty(postalCode),
                phone: nilIfEmpty(phone),
                email: nilIfEmpty(email),
                website: nilIfEmpty(website)
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}
