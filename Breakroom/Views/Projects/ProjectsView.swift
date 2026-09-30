import SwiftUI

/// Cross-company Projects page showing all projects the user has access to,
/// with pending invites and company filtering. Mirrors web's ProjectsPage.vue.
struct ProjectsView: View {
    @State private var projects: [Project] = []
    @State private var invites: [ProjectInvite] = []
    @State private var shortcuts: [String: Int] = [:]  // URL -> shortcut ID
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var error: String?

    // Company filter
    @State private var selectedCompanyId: Int?

    // UI state
    @State private var respondingTo: Int?  // project ID being responded to
    @State private var inviteError: String?
    @State private var togglingShortcutFor: Int?
    @State private var message: String?
    @State private var showMessage = false

    // Navigation
    @State private var selectedProject: Project?

    var body: some View {
        Group {
            if isLoading && !hasLoadedOnce {
                ProgressView("Loading projects...")
            } else if let error, !hasLoadedOnce {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadAll() }
                    }
                }
            } else {
                projectsContent
            }
        }
        .navigationTitle("Projects")
        .task {
            await loadAll()
        }
        .refreshable {
            await loadAll()
        }
        .alert("Notice", isPresented: $showMessage) {
            Button("OK") { }
        } message: {
            Text(message ?? "")
        }
        .navigationDestination(item: $selectedProject) { project in
            if project.isHelpDeskProject {
                HelpDeskView(companyId: project.companyId, companyName: project.companyName ?? "Company")
            } else {
                
                ProjectWorkspaceView(projectId: project.id)
            }
        }
    }

    // MARK: - Computed Properties

    private var companies: [(id: Int, name: String)] {
        let companyMap = Dictionary(grouping: projects, by: { $0.companyId })
        return companyMap.compactMap { (id, projectsInCompany) -> (id: Int, name: String)? in
            guard let name = projectsInCompany.first?.companyName else { return nil }
            return (id: id, name: name)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredProjects: [Project] {
        if let companyId = selectedCompanyId {
            return projects.filter { $0.companyId == companyId }
        }
        return projects
    }

    private var activeCount: Int {
        filteredProjects.filter { $0.isActiveBool }.count
    }

    // MARK: - Content

    private var projectsContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Invites card
                if !invites.isEmpty {
                    invitesCard
                }

                // Header with filter
                projectsHeader

                // Empty state
                if projects.isEmpty {
                    emptyState
                } else if filteredProjects.isEmpty {
                    Text("No projects in this company.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    // Project cards
                    ForEach(filteredProjects) { project in
                        projectCard(project)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Invites Card

    private var invitesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Invitations (\(invites.count))")
                .font(.headline)

            if let error = inviteError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(invites) { invite in
                inviteRow(invite)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func inviteRow(_ invite: ProjectInvite) -> some View {
        let busy = respondingTo == invite.projectId

        return VStack(alignment: .leading, spacing: 4) {
            if let companyName = invite.companyName {
                Text(companyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(invite.projectTitle)
                .font(.body.weight(.semibold))

            Text("\(invite.inviterName ?? "Someone") invited you as a \(invite.role)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Accept") {
                    Task { await respondToInvite(invite, accept: true) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(busy)

                Button("Decline") {
                    Task { await respondToInvite(invite, accept: false) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(busy)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Projects Header

    private var projectsHeader: some View {
        HStack {
            Text("Projects (\(activeCount))")
                .font(.title2.bold())

            Spacer()

            if companies.count > 1 {
                Menu {
                    Button("All companies") {
                        selectedCompanyId = nil
                    }
                    Divider()
                    ForEach(companies, id: \.id) { company in
                        Button(company.name) {
                            selectedCompanyId = company.id
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCompanyId.flatMap { id in companies.first { $0.id == id }?.name } ?? "All companies")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No projects yet. Projects belong to companies — join or create one in the Company Portal.")
                .foregroundStyle(.secondary)

            NavigationLink("Open Company Portal") {
                CompanyPortalView()
            }
            .font(.body.weight(.medium))
        }
        .padding(.vertical)
    }

    // MARK: - Project Card

    private func projectCard(_ project: Project) -> some View {
        let shortcutUrl = project.homepageUrl
        let hasShortcut = shortcuts[shortcutUrl] != nil
        let isToggling = togglingShortcutFor == project.id

        return VStack(alignment: .leading, spacing: 8) {
            // Company name (tappable)
            if let companyName = project.companyName {
                Text(companyName)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }

            // Title row with shortcut toggle
            HStack {
                Text(project.title)
                    .font(.headline)

                Spacer()

                if project.isActiveBool {
                    Button {
                        Task { await toggleShortcut(project) }
                    } label: {
                        if isToggling {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: hasShortcut ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(hasShortcut ? Color.accentColor : Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isToggling)
                }
            }

            // Badges
            HStack(spacing: 6) {
                if project.isDefaultBool {
                    badge("Default", color: .purple.opacity(0.2))
                }
                badge(project.isPublicBool ? "Public" : "Private", color: project.isPublicBool ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                badge(project.isActiveBool ? "Active" : "Inactive", color: project.isActiveBool ? .green.opacity(0.2) : .red.opacity(0.2))
            }

            // Description
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Footer
            HStack {
                Text(project.ticketCountText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                if project.isActiveBool {
                    Button {
                        selectedProject = project
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("View Tickets")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .opacity(project.isActiveBool ? 1.0 : 0.6)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Data Loading

    private func loadAll() async {
        if !hasLoadedOnce {
            isLoading = true
        }
        error = nil

        do {
            async let projectsTask = ProjectAPIService.getMyProjects()
            async let invitesTask = ProjectAPIService.getMyInvites()
            async let shortcutsTask = ShortcutsAPIService.getShortcuts()

            let (loadedProjects, loadedInvites, loadedShortcuts) = try await (projectsTask, invitesTask, shortcutsTask)

            projects = loadedProjects
            invites = loadedInvites
            shortcuts = Dictionary(uniqueKeysWithValues: loadedShortcuts.map { ($0.url, $0.id) })

            // Clear company filter if no longer valid
            if let companyId = selectedCompanyId, !projects.contains(where: { $0.companyId == companyId }) {
                selectedCompanyId = nil
            }

            hasLoadedOnce = true
        } catch {
            if !hasLoadedOnce {
                self.error = "Failed to load projects"
            }
        }

        isLoading = false
    }

    private func respondToInvite(_ invite: ProjectInvite, accept: Bool) async {
        respondingTo = invite.projectId
        inviteError = nil

        do {
            _ = try await ProjectAPIService.respondToInvite(projectId: invite.projectId, accept: accept)
            invites.removeAll { $0.projectId == invite.projectId }
            if accept {
                // Refresh projects to include the new one
                let loadedProjects = try await ProjectAPIService.getMyProjects()
                projects = loadedProjects
            }
        } catch let error as APIError {
            inviteError = error.localizedDescription
        } catch {
            inviteError = "Failed to respond to invite"
        }

        respondingTo = nil
    }

    private func toggleShortcut(_ project: Project) async {
        let url = project.homepageUrl
        togglingShortcutFor = project.id

        do {
            if let existingId = shortcuts[url] {
                // Remove shortcut
                try await ShortcutsAPIService.deleteShortcut(id: existingId)
                shortcuts.removeValue(forKey: url)
            } else {
                // Add shortcut
                let shortcut = try await ShortcutsAPIService.addShortcut(name: project.title, url: url)
                shortcuts[url] = shortcut.id
            }
        } catch let error as APIError {
            message = error.localizedDescription
            showMessage = true
        } catch {
            message = "Failed to update shortcut"
            showMessage = true
        }

        togglingShortcutFor = nil
    }
}

// MARK: - Project Extension

private extension Project {
    /// The Help Desk page is hardcoded to Cherry Blossom Development (company 1)
    static let helpDeskCompanyId = 1

    var isHelpDeskProject: Bool {
        isDefaultBool && companyId == Project.helpDeskCompanyId
    }

    /// Shortcut URL for a project, same as web's getProjectHomepageLink()
    var homepageUrl: String {
        isHelpDeskProject ? "/help-desk" : "/project/\(id)"
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
}
