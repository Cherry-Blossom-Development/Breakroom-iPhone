import SwiftUI

struct EmploymentView: View {
    @State private var positions: [Position] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Filters
    @State private var searchText = ""
    @State private var locationFilter = ""
    @State private var employmentFilter = ""

    // Detail navigation
    @State private var selectedPosition: Position?

    private var isEditing: Binding<Bool> {
        Binding(
            get: { selectedPosition != nil },
            set: { if !$0 { selectedPosition = nil } }
        )
    }

    private var filteredPositions: [Position] {
        var result = positions

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                ($0.companyName?.lowercased().contains(query) ?? false) ||
                ($0.description?.lowercased().contains(query) ?? false)
            }
        }

        if !locationFilter.isEmpty {
            result = result.filter { $0.locationType == locationFilter }
        }

        if !employmentFilter.isEmpty {
            result = result.filter { $0.employmentType == employmentFilter }
        }

        return result
    }

    private var hasActiveFilters: Bool {
        !locationFilter.isEmpty || !employmentFilter.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if positions.isEmpty {
                    ContentUnavailableView(
                        "No Positions",
                        systemImage: "briefcase",
                        description: Text("No open positions are currently available.")
                    )
                } else {
                    positionsList
                }
            }
            .navigationTitle("Jobs")
            .searchable(text: $searchText, prompt: "Search jobs by title, company...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .navigationDestination(isPresented: isEditing) {
                if let position = selectedPosition {
                    PositionDetailView(position: position)
                }
            }
            .refreshable {
                await loadPositions()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .task {
                await loadPositions()
            }
        }
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            // Location type
            Menu {
                Button("All Locations") { locationFilter = "" }
                Divider()
                Button {
                    locationFilter = "remote"
                } label: {
                    Label("Remote", systemImage: locationFilter == "remote" ? "checkmark" : "")
                }
                Button {
                    locationFilter = "onsite"
                } label: {
                    Label("Onsite", systemImage: locationFilter == "onsite" ? "checkmark" : "")
                }
                Button {
                    locationFilter = "hybrid"
                } label: {
                    Label("Hybrid", systemImage: locationFilter == "hybrid" ? "checkmark" : "")
                }
            } label: {
                Label("Location", systemImage: "location")
            }

            // Employment type
            Menu {
                Button("All Types") { employmentFilter = "" }
                Divider()
                ForEach(["full-time", "part-time", "contract", "internship", "temporary"], id: \.self) { type in
                    Button {
                        employmentFilter = type
                    } label: {
                        let formatted = type.split(separator: "-")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                            .joined(separator: "-")
                        Label(formatted, systemImage: employmentFilter == type ? "checkmark" : "")
                    }
                }
            } label: {
                Label("Type", systemImage: "clock")
            }

            if hasActiveFilters {
                Divider()
                Button("Clear Filters", role: .destructive) {
                    locationFilter = ""
                    employmentFilter = ""
                }
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Positions List

    private var positionsList: some View {
        List {
            if filteredPositions.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("No positions match your filters.")
                )
                .listRowSeparator(.hidden)
            } else {
                Section {
                    Text("\(filteredPositions.count) position\(filteredPositions.count == 1 ? "" : "s") available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }

                ForEach(filteredPositions) { position in
                    Button {
                        selectedPosition = position
                    } label: {
                        positionCard(position)
                    }
                    .foregroundStyle(.primary)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Position Card

    private func positionCard(_ position: Position) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title + Pay
            HStack(alignment: .top) {
                Text(position.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(position.formattedPay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            // Company
            if let company = position.companyName {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Tags
            HStack(spacing: 6) {
                if !position.formattedEmploymentType.isEmpty {
                    Text(position.formattedEmploymentType)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }

                if !position.formattedLocationType.isEmpty {
                    Text(position.formattedLocationType)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Text(position.locationString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Description excerpt
            if !position.descriptionExcerpt.isEmpty {
                Text(position.descriptionExcerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Posted date
            if !position.relativeDate.isEmpty {
                Text("Posted \(position.relativeDate)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Data

    private func loadPositions() async {
        do {
            positions = try await PositionsAPIService.getPositions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            if isLoading { showError = true }
        }
        isLoading = false
    }
}

// MARK: - Position Detail View

struct PositionDetailView: View {
    let position: Position

    @State private var fullPosition: Position?
    @State private var isLoading = true

    private var display: Position {
        fullPosition ?? position
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(display.title)
                        .font(.title2.bold())

                    if let company = display.companyName {
                        Text(company)
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                // Meta info
                VStack(spacing: 0) {
                    metaRow(label: "Employment Type", value: display.formattedEmploymentType)
                    metaRow(label: "Location Type", value: display.formattedLocationType)
                    metaRow(label: "Location", value: display.locationString)
                    metaRow(label: "Compensation", value: display.formattedPay, isAccent: true)
                    if let dept = display.department, !dept.isEmpty {
                        metaRow(label: "Department", value: dept)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Description
                if let desc = display.description, !desc.isEmpty {
                    detailSection("Description", text: desc)
                }

                // Requirements
                if let req = display.requirements, !req.isEmpty {
                    detailSection("Requirements", text: req)
                }

                // Benefits
                if let ben = display.benefits, !ben.isEmpty {
                    detailSection("Benefits", text: ben)
                }

                // Footer
                if !display.relativeDate.isEmpty {
                    Text("Posted \(display.relativeDate)")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                // Company website
                if let website = display.companyWebsite, !website.isEmpty,
                   let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") {
                    Link(destination: url) {
                        Label("Visit Company Website", systemImage: "globe")
                            .font(.subheadline)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Position Details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadDetail()
        }
    }

    private func metaRow(label: String, value: String, isAccent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isAccent ? Color.accentColor : .primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func detailSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func loadDetail() async {
        do {
            fullPosition = try await PositionsAPIService.getPosition(id: position.id)
        } catch {
            // Fall back to the position data we already have
        }
        isLoading = false
    }
}
