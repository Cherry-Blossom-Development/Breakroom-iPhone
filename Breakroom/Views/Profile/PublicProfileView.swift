import SwiftUI

struct PublicProfileView: View {
    let handle: String
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showBlockConfirmation = false
    @State private var isBlocking = false
    @State private var didBlock = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading profile...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Unable to Load Profile",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(error)
                )
            } else if let profile {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile header
                        profileHeader(profile)

                        // Bio section
                        if let bio = profile.bio, !bio.isEmpty {
                            bioSection(title: "About", content: bio)
                        }

                        // Work bio section
                        if let workBio = profile.workBio, !workBio.isEmpty {
                            bioSection(title: "Work", content: workBio)
                        }

                        // Skills section
                        if !profile.skills.isEmpty {
                            skillsSection(profile.skills)
                        }

                        // Jobs section
                        if !profile.jobs.isEmpty {
                            jobsSection(profile.jobs)
                        }

                        // Block user button
                        blockUserButton(profile)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("@\(handle)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
        }
        .confirmationDialog(
            "Block @\(handle)?",
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { await blockUser() }
            }
        } message: {
            Text("They won't be able to see your content or contact you. You can unblock them from your Friends page.")
        }
    }

    private func blockUserButton(_ profile: UserProfile) -> some View {
        Button(role: .destructive) {
            showBlockConfirmation = true
        } label: {
            HStack {
                if isBlocking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: didBlock ? "hand.raised.slash.fill" : "hand.raised.slash")
                }
                Text(didBlock ? "Blocked" : "Block User")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(didBlock ? Color.gray : Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isBlocking || didBlock)
    }

    private func blockUser() async {
        guard let profile else { return }
        isBlocking = true
        do {
            try await FriendsAPIService.blockUser(userId: profile.id)
            didBlock = true
        } catch {
            errorMessage = "Failed to block user"
        }
        isBlocking = false
    }

    private func profileHeader(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            // Profile photo
            if let photoURL = profile.photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.secondary)
            }

            // Name and handle
            VStack(spacing: 4) {
                Text(profile.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("@\(profile.handle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Location and member info
            HStack(spacing: 16) {
                if let city = profile.city, !city.isEmpty {
                    Label(city, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !profile.memberSince.isEmpty {
                    Label("Joined \(profile.memberSince)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bioSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func skillsSection(_ skills: [Skill]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(skills) { skill in
                    Text(skill.name)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func jobsSection(_ jobs: [UserJob]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experience")
                .font(.headline)

            ForEach(jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(job.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(job.formattedDateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let description = job.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if job.id != jobs.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            profile = try await ProfileAPIService.getPublicProfile(handle: handle)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// FlowLayout is defined in CreateRoomView.swift
