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

// MARK: - Company Detail View

struct CompanyDetailView: View {
    let companyId: Int

    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case employees = "Employees"
        case positions = "Positions"
        case projects = "Projects"
    }

    @State private var selectedTab: DetailTab = .info
    @State private var detail: CompanyDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showEditSheet = false

    // Employees tab
    @State private var showAddEmployeeSheet = false
    @State private var editingEmployee: CompanyEmployee?
    @State private var employeeToDelete: CompanyEmployee?
    @State private var showDeleteEmployeeConfirm = false

    // Positions tab
    @State private var positions: [Position] = []
    @State private var isLoadingPositions = false
    @State private var showAddPositionSheet = false
    @State private var editingPosition: Position?
    @State private var positionToDelete: Position?
    @State private var showDeletePositionConfirm = false

    private var canEdit: Bool {
        guard let role = detail?.userRole else { return false }
        return role.isOwnerBool || role.isAdminBool
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail {
                VStack(spacing: 0) {
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Group {
                        switch selectedTab {
                        case .info:
                            infoTab(detail)
                        case .employees:
                            employeesTab(detail)
                        case .positions:
                            positionsTab
                        case .projects:
                            projectsTab
                        }
                    }
                }
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
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    switch selectedTab {
                    case .info:
                        Button("Edit", systemImage: "pencil") {
                            showEditSheet = true
                        }
                    case .employees:
                        Button("Add", systemImage: "plus") {
                            showAddEmployeeSheet = true
                        }
                    case .positions:
                        Button("Add", systemImage: "plus") {
                            showAddPositionSheet = true
                        }
                    case .projects:
                        EmptyView()
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
        .sheet(isPresented: $showAddEmployeeSheet) {
            AddEmployeeSheet(companyId: companyId) { newEmployee in
                if let current = detail {
                    var emps = current.employees
                    emps.append(newEmployee)
                    detail = CompanyDetailResponse(
                        company: current.company,
                        employees: emps,
                        userRole: current.userRole
                    )
                }
            }
        }
        .sheet(item: $editingEmployee) { emp in
            EditEmployeeSheet(companyId: companyId, employee: emp) { updated in
                if let detail {
                    var emps = detail.employees
                    if let idx = emps.firstIndex(where: { $0.id == updated.id }) {
                        emps[idx] = updated
                    }
                    self.detail = CompanyDetailResponse(
                        company: detail.company,
                        employees: emps,
                        userRole: detail.userRole
                    )
                }
            }
        }
        .sheet(isPresented: $showAddPositionSheet) {
            AddPositionSheet(companyId: companyId) { newPosition in
                positions.insert(newPosition, at: 0)
            }
        }
        .sheet(item: $editingPosition) { pos in
            EditPositionSheet(position: pos) { updated in
                if let idx = positions.firstIndex(where: { $0.id == updated.id }) {
                    positions[idx] = updated
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Delete Employee", isPresented: $showDeleteEmployeeConfirm) {
            Button("Delete", role: .destructive) {
                if let emp = employeeToDelete {
                    Task { await deleteEmployee(emp) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let emp = employeeToDelete {
                Text("Remove \(emp.displayName) from this company?")
            }
        }
        .alert("Delete Position", isPresented: $showDeletePositionConfirm) {
            Button("Delete", role: .destructive) {
                if let pos = positionToDelete {
                    Task { await deletePosition(pos) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let pos = positionToDelete {
                Text("Delete the position \"\(pos.title)\"?")
            }
        }
        .refreshable {
            await loadDetail()
            await loadPositions()
        }
        .task {
            await loadDetail()
            await loadPositions()
        }
    }

    // MARK: - Info Tab

    private func infoTab(_ detail: CompanyDetailResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
            }
            .padding()
        }
    }

    // MARK: - Employees Tab

    private func employeesTab(_ detail: CompanyDetailResponse) -> some View {
        Group {
            if detail.employees.isEmpty {
                ContentUnavailableView(
                    "No Employees",
                    systemImage: "person.3",
                    description: Text("No employees have been added yet.")
                )
            } else {
                List {
                    ForEach(detail.employees) { emp in
                        Button {
                            if canEdit {
                                editingEmployee = emp
                            }
                        } label: {
                            employeeRow(emp)
                        }
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canEdit && !emp.isOwnerBool {
                                Button(role: .destructive) {
                                    employeeToDelete = emp
                                    showDeleteEmployeeConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Positions Tab

    private var positionsTab: some View {
        Group {
            if isLoadingPositions {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if positions.isEmpty {
                ContentUnavailableView(
                    "No Positions",
                    systemImage: "briefcase",
                    description: Text("No positions have been posted yet.")
                )
            } else {
                List {
                    ForEach(positions) { pos in
                        Button {
                            if canEdit {
                                editingPosition = pos
                            }
                        } label: {
                            positionRow(pos)
                        }
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canEdit {
                                Button(role: .destructive) {
                                    positionToDelete = pos
                                    showDeletePositionConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Projects Tab

    private var projectsTab: some View {
        ContentUnavailableView(
            "Projects",
            systemImage: "folder",
            description: Text("Coming Soon")
        )
    }

    // MARK: - Row Views

    private func positionRow(_ pos: Position) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pos.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                positionStatusBadge(pos.status)
            }

            HStack(spacing: 8) {
                if !pos.formattedEmploymentType.isEmpty {
                    metaTag(pos.formattedEmploymentType)
                }
                if !pos.formattedLocationType.isEmpty {
                    metaTag(pos.formattedLocationType)
                }
                Text(pos.locationString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(pos.formattedPay)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if !pos.descriptionExcerpt.isEmpty {
                Text(pos.descriptionExcerpt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .opacity(pos.status != nil && pos.status != "open" ? 0.6 : 1.0)
    }

    private func metaTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.secondary)
    }

    private func positionStatusBadge(_ status: String?) -> some View {
        let label: String
        let color: Color
        switch status?.lowercased() {
        case "closed":
            label = "Closed"
            color = .red
        case "filled":
            label = "Filled"
            color = .purple
        default:
            label = "Open"
            color = .green
        }
        return Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func employeeRow(_ emp: CompanyEmployee) -> some View {
        HStack(spacing: 10) {
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

    // MARK: - Helpers

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

    // MARK: - Data Loading

    private func loadDetail() async {
        do {
            detail = try await CompanyAPIService.getCompany(id: companyId)
        } catch {
            errorMessage = error.localizedDescription
            if detail == nil { showError = true }
        }
        isLoading = false
    }

    private func loadPositions() async {
        isLoadingPositions = true
        do {
            positions = try await PositionsAPIService.getCompanyPositions(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoadingPositions = false
    }

    private func deleteEmployee(_ emp: CompanyEmployee) async {
        do {
            try await CompanyAPIService.deleteEmployee(companyId: companyId, employeeId: emp.id)
            if let detail {
                let emps = detail.employees.filter { $0.id != emp.id }
                self.detail = CompanyDetailResponse(
                    company: detail.company,
                    employees: emps,
                    userRole: detail.userRole
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deletePosition(_ pos: Position) async {
        do {
            try await PositionsAPIService.deletePosition(id: pos.id)
            positions.removeAll { $0.id == pos.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
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

// MARK: - Add Employee Sheet

struct AddEmployeeSheet: View {
    let companyId: Int
    let onAdd: (CompanyEmployee) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [EmployeeSearchUser] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedUser: EmployeeSearchUser?

    @State private var title = ""
    @State private var department = ""
    @State private var isAdmin = false
    @State private var hireDate = Date()
    @State private var includeHireDate = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Find User") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search by name or handle...", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { _, newValue in
                                debounceSearch(newValue)
                            }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Spacer()
                        }
                    }

                    ForEach(searchResults) { user in
                        Button {
                            selectedUser = user
                            searchText = ""
                            searchResults = []
                        } label: {
                            userSearchRow(user)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if let user = selectedUser {
                    Section("Selected User") {
                        HStack {
                            Text(user.displayName)
                                .font(.body.weight(.medium))
                            Spacer()
                            Button("Change") {
                                selectedUser = nil
                            }
                            .font(.caption)
                        }
                    }

                    Section("Employee Details") {
                        TextField("Job Title *", text: $title)
                        TextField("Department", text: $department)
                        Toggle("Admin Access", isOn: $isAdmin)
                        Toggle("Set Hire Date", isOn: $includeHireDate)
                        if includeHireDate {
                            DatePicker("Hire Date", selection: $hireDate, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle("Add Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await addEmployee() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(selectedUser == nil ||
                              title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func userSearchRow(_ user: EmployeeSearchUser) -> some View {
        HStack(spacing: 10) {
            Group {
                if let url = user.photoURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        userInitialsCircle(user)
                    }
                } else {
                    userInitialsCircle(user)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline.weight(.medium))
                if let handle = user.handle, !handle.isEmpty {
                    Text("@\(handle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func userInitialsCircle(_ user: EmployeeSearchUser) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .overlay {
                Text((user.displayName.first ?? Character("?")).uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
    }

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                searchResults = try await CompanyAPIService.searchUsers(
                    companyId: companyId, query: trimmed
                )
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            isSearching = false
        }
    }

    private func addEmployee() async {
        guard let user = selectedUser else { return }
        isSaving = true

        let hireDateString: String? = includeHireDate ? {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: hireDate)
        }() : nil

        let dept = department.trimmingCharacters(in: .whitespaces)

        do {
            let emp = try await CompanyAPIService.addEmployee(
                companyId: companyId,
                userId: user.id,
                title: title.trimmingCharacters(in: .whitespaces),
                department: dept.isEmpty ? nil : dept,
                isAdmin: isAdmin ? 1 : 0,
                hireDate: hireDateString
            )
            onAdd(emp)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Edit Employee Sheet

struct EditEmployeeSheet: View {
    let companyId: Int
    let employee: CompanyEmployee
    let onSave: (CompanyEmployee) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var department: String
    @State private var isAdmin: Bool
    @State private var hireDate: Date
    @State private var includeHireDate: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(companyId: Int, employee: CompanyEmployee, onSave: @escaping (CompanyEmployee) -> Void) {
        self.companyId = companyId
        self.employee = employee
        self.onSave = onSave
        _title = State(initialValue: employee.title ?? "")
        _department = State(initialValue: employee.department ?? "")
        _isAdmin = State(initialValue: employee.isAdminBool)

        if let dateStr = employee.hireDate, !dateStr.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            _hireDate = State(initialValue: f.date(from: dateStr) ?? Date())
            _includeHireDate = State(initialValue: true)
        } else {
            _hireDate = State(initialValue: Date())
            _includeHireDate = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text((employee.displayName.first ?? Character("?")).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.accentColor)
                            }
                        VStack(alignment: .leading) {
                            Text(employee.displayName)
                                .font(.body.weight(.medium))
                            if let handle = employee.handle, !handle.isEmpty {
                                Text("@\(handle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Employee Details") {
                    TextField("Job Title", text: $title)
                    TextField("Department", text: $department)
                    if !employee.isOwnerBool {
                        Toggle("Admin Access", isOn: $isAdmin)
                    }
                    Toggle("Set Hire Date", isOn: $includeHireDate)
                    if includeHireDate {
                        DatePicker("Hire Date", selection: $hireDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Edit Employee")
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
                    .disabled(isSaving)
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

        let t = title.trimmingCharacters(in: .whitespaces)
        let d = department.trimmingCharacters(in: .whitespaces)

        let hireDateString: String? = includeHireDate ? {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: hireDate)
        }() : nil

        do {
            let updated = try await CompanyAPIService.updateEmployee(
                companyId: companyId,
                employeeId: employee.id,
                title: t.isEmpty ? nil : t,
                department: d.isEmpty ? nil : d,
                isAdmin: employee.isOwnerBool ? nil : (isAdmin ? 1 : 0),
                hireDate: hireDateString,
                status: nil
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

// MARK: - Add Position Sheet

struct AddPositionSheet: View {
    let companyId: Int
    let onAdd: (Position) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var department = ""
    @State private var locationType = "onsite"
    @State private var city = ""
    @State private var state = ""
    @State private var country = ""
    @State private var employmentType = "full-time"
    @State private var payMin = ""
    @State private var payMax = ""
    @State private var payType = "salary"
    @State private var requirements = ""
    @State private var benefits = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let locationTypes = ["onsite", "remote", "hybrid"]
    private let employmentTypes = ["full-time", "part-time", "contract", "internship"]
    private let payTypes = ["salary", "hourly"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Position Info") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Department", text: $department)
                }

                Section("Location") {
                    Picker("Type", selection: $locationType) {
                        ForEach(locationTypes, id: \.self) { type in
                            Text(type.prefix(1).uppercased() + type.dropFirst()).tag(type)
                        }
                    }
                    if locationType != "remote" {
                        TextField("City", text: $city)
                        TextField("State / Province", text: $state)
                        TextField("Country", text: $country)
                    }
                }

                Section("Employment") {
                    Picker("Type", selection: $employmentType) {
                        ForEach(employmentTypes, id: \.self) { type in
                            Text(type.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "-")).tag(type)
                        }
                    }
                }

                Section("Pay") {
                    Picker("Pay Type", selection: $payType) {
                        ForEach(payTypes, id: \.self) { type in
                            Text(type.prefix(1).uppercased() + type.dropFirst()).tag(type)
                        }
                    }
                    TextField("Min", text: $payMin)
                        .keyboardType(.numberPad)
                    TextField("Max", text: $payMax)
                        .keyboardType(.numberPad)
                }

                Section("Details") {
                    TextField("Requirements", text: $requirements, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Benefits", text: $benefits, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createPosition() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func createPosition() async {
        isSaving = true

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }

        do {
            let pos = try await PositionsAPIService.createPosition(
                companyId: companyId,
                title: title.trimmingCharacters(in: .whitespaces),
                description: nilIfEmpty(description),
                department: nilIfEmpty(department),
                locationType: locationType,
                city: nilIfEmpty(city),
                state: nilIfEmpty(state),
                country: nilIfEmpty(country),
                employmentType: employmentType,
                payRateMin: Int(payMin),
                payRateMax: Int(payMax),
                payType: payType,
                requirements: nilIfEmpty(requirements),
                benefits: nilIfEmpty(benefits)
            )
            onAdd(pos)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Edit Position Sheet

struct EditPositionSheet: View {
    let position: Position
    let onSave: (Position) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var department: String
    @State private var locationType: String
    @State private var city: String
    @State private var state: String
    @State private var country: String
    @State private var employmentType: String
    @State private var payMin: String
    @State private var payMax: String
    @State private var payType: String
    @State private var requirements: String
    @State private var benefits: String
    @State private var status: String

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let locationTypes = ["onsite", "remote", "hybrid"]
    private let employmentTypes = ["full-time", "part-time", "contract", "internship"]
    private let payTypes = ["salary", "hourly"]
    private let statusOptions = ["open", "closed", "filled"]

    init(position: Position, onSave: @escaping (Position) -> Void) {
        self.position = position
        self.onSave = onSave
        _title = State(initialValue: position.title)
        _description = State(initialValue: position.description ?? "")
        _department = State(initialValue: position.department ?? "")
        _locationType = State(initialValue: position.locationType ?? "onsite")
        _city = State(initialValue: position.city ?? "")
        _state = State(initialValue: position.state ?? "")
        _country = State(initialValue: position.country ?? "")
        _employmentType = State(initialValue: position.employmentType ?? "full-time")
        _payMin = State(initialValue: position.payRateMin.map { String($0) } ?? "")
        _payMax = State(initialValue: position.payRateMax.map { String($0) } ?? "")
        _payType = State(initialValue: position.payType ?? "salary")
        _requirements = State(initialValue: position.requirements ?? "")
        _benefits = State(initialValue: position.benefits ?? "")
        _status = State(initialValue: position.status ?? "open")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Position Info") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Department", text: $department)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { opt in
                            Text(opt.prefix(1).uppercased() + opt.dropFirst()).tag(opt)
                        }
                    }
                }

                Section("Location") {
                    Picker("Type", selection: $locationType) {
                        ForEach(locationTypes, id: \.self) { type in
                            Text(type.prefix(1).uppercased() + type.dropFirst()).tag(type)
                        }
                    }
                    if locationType != "remote" {
                        TextField("City", text: $city)
                        TextField("State / Province", text: $state)
                        TextField("Country", text: $country)
                    }
                }

                Section("Employment") {
                    Picker("Type", selection: $employmentType) {
                        ForEach(employmentTypes, id: \.self) { type in
                            Text(type.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "-")).tag(type)
                        }
                    }
                }

                Section("Pay") {
                    Picker("Pay Type", selection: $payType) {
                        ForEach(payTypes, id: \.self) { type in
                            Text(type.prefix(1).uppercased() + type.dropFirst()).tag(type)
                        }
                    }
                    TextField("Min", text: $payMin)
                        .keyboardType(.numberPad)
                    TextField("Max", text: $payMax)
                        .keyboardType(.numberPad)
                }

                Section("Details") {
                    TextField("Requirements", text: $requirements, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Benefits", text: $benefits, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Position")
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
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
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
            let updated = try await PositionsAPIService.updatePosition(
                id: position.id,
                title: title.trimmingCharacters(in: .whitespaces),
                description: nilIfEmpty(description),
                department: nilIfEmpty(department),
                locationType: locationType,
                city: nilIfEmpty(city),
                state: nilIfEmpty(state),
                country: nilIfEmpty(country),
                employmentType: employmentType,
                payRateMin: Int(payMin),
                payRateMax: Int(payMax),
                payType: payType,
                requirements: nilIfEmpty(requirements),
                benefits: nilIfEmpty(benefits),
                status: status
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
