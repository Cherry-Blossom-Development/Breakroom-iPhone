import SwiftUI

/// A loading/redirect view that determines which Kanban board to show.
/// Logic mirrors the web KanbanPage.vue:
/// 1. Check if user has companies
/// 2. If yes: find first company's active project and navigate to it
/// 3. If no: create "Personal Workspace" company and navigate to its default project
struct KanbanRedirectView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Navigation destinations
    @State private var targetProject: KanbanTarget?
    @State private var noProjectsCompanyId: Int?

    enum KanbanTarget: Hashable {
        case project(id: Int, title: String)
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Finding your projects...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let target = targetProject {
                // Navigate to the Kanban board
                kanbanDestination(target)
            } else if let companyId = noProjectsCompanyId {
                // No active projects - show message with link to company
                noProjectsView(companyId: companyId)
            } else if errorMessage != nil {
                // Error state
                errorView
            }
        }
        .navigationTitle("Kanban")
        .task {
            await determineDestination()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    @ViewBuilder
    private func kanbanDestination(_ target: KanbanTarget) -> some View {
        switch target {
        case .project(let id, let title):
            KanbanBoardView(projectId: id, projectTitle: title)
        }
    }

    private func noProjectsView(companyId: Int) -> some View {
        ContentUnavailableView {
            Label("No Active Projects", systemImage: "rectangle.split.3x1")
        } description: {
            Text("Your company doesn't have any active projects yet. Create a project from the Company tab to get started with Kanban.")
        } actions: {
            Button("Go to Company") {
                // User can navigate manually via tab bar
            }
            .buttonStyle(.bordered)
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(errorMessage ?? "Unable to load your projects.")
        } actions: {
            Button("Try Again") {
                Task { await determineDestination() }
            }
            .buttonStyle(.bordered)
        }
    }

    private func determineDestination() async {
        isLoading = true
        errorMessage = nil

        do {
            // Step 1: Get user's companies
            let companies = try await CompanyAPIService.getMyCompanies()

            if !companies.isEmpty {
                // Step 2: User has companies - get first company's projects
                let firstCompany = companies[0]
                let projects = try await CompanyAPIService.getCompanyProjects(companyId: firstCompany.id)

                // Find active projects
                let activeProjects = projects.filter { $0.isActiveBool }

                if !activeProjects.isEmpty {
                    // Prefer non-default project, otherwise use first active
                    let nonDefault = activeProjects.first { !$0.isDefaultBool }
                    let projectToOpen = nonDefault ?? activeProjects[0]

                    targetProject = .project(id: projectToOpen.id, title: projectToOpen.title)
                } else {
                    // No active projects - show message
                    noProjectsCompanyId = firstCompany.id
                }
            } else {
                // Step 3: No companies - create "Personal Workspace"
                let newCompany = try await CompanyAPIService.createCompany(
                    name: "Personal Workspace",
                    description: "My personal project management workspace",
                    address: nil,
                    city: nil,
                    state: nil,
                    country: nil,
                    postalCode: nil,
                    phone: nil,
                    email: nil,
                    website: nil,
                    employeeTitle: "Owner"
                )

                // Get the auto-created default project
                let projects = try await CompanyAPIService.getCompanyProjects(companyId: newCompany.id)

                if let firstProject = projects.first {
                    targetProject = .project(id: firstProject.id, title: firstProject.title)
                } else {
                    // Shouldn't happen, but handle it
                    noProjectsCompanyId = newCompany.id
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}
