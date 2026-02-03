import PhotosUI
import SwiftUI

struct ProfileView: View {
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Edit mode
    @State private var isEditing = false
    @State private var editFirstName = ""
    @State private var editLastName = ""
    @State private var editBio = ""
    @State private var editWorkBio = ""
    @State private var isSaving = false

    // Photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var showDeletePhotoConfirmation = false

    // Skills
    @State private var skillInput = ""
    @State private var skillSuggestions: [Skill] = []
    @State private var isAddingSkill = false
    @State private var skillSearchTask: Task<Void, Never>?

    // Jobs
    @State private var showJobForm = false
    @State private var editingJob: UserJob?
    @State private var jobToDelete: UserJob?
    @State private var showDeleteJobConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let profile {
                profileContent(profile)
            } else {
                ContentUnavailableView(
                    "Could Not Load Profile",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Pull to refresh and try again.")
                )
            }
        }
        .navigationTitle("Profile")
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .confirmationDialog(
            "Delete Photo",
            isPresented: $showDeletePhotoConfirmation
        ) {
            Button("Delete Photo", role: .destructive) {
                Task { await deletePhoto() }
            }
        } message: {
            Text("Are you sure you want to remove your profile photo?")
        }
        .confirmationDialog(
            "Delete Job",
            isPresented: $showDeleteJobConfirmation,
            presenting: jobToDelete
        ) { job in
            Button("Delete", role: .destructive) {
                Task { await deleteJob(job) }
            }
        } message: { job in
            Text("Are you sure you want to remove \"\(job.title)\" at \(job.company)?")
        }
        .sheet(isPresented: $showJobForm) {
            JobFormView(existingJob: editingJob) { savedJob in
                handleJobSaved(savedJob)
            }
        }
        .refreshable {
            await loadProfile()
        }
        .task {
            await loadProfile()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task { await uploadPhoto(newItem) }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader(profile)

                if isEditing {
                    editForm(profile)
                } else {
                    aboutSection(profile)
                    workBioSection(profile)
                    skillsSection(profile)
                    jobsSection(profile)
                    detailsSection(profile)

                    Button("Edit Profile") {
                        startEditing(profile)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
    }

    // MARK: - Header

    private func profileHeader(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Photo
                ZStack {
                    if let photoURL = profile.photoURL {
                        AsyncImage(url: photoURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Circle()
                            .fill(Color.accentColor)
                            .overlay {
                                Text(profile.firstName?.prefix(1).uppercased() ?? profile.handle.prefix(1).uppercased())
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.title2.bold())

                    Text("@\(profile.handle)")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)

                    if !profile.memberSince.isEmpty {
                        Text("Member since \(profile.memberSince)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(profile.friendCount) \(profile.friendCount == 1 ? "friend" : "friends")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Photo actions
            let uploading = isUploadingPhoto
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        uploading ? "Uploading..." : (profile.photoPath != nil ? "Change Photo" : "Add Photo"),
                        systemImage: "camera"
                    )
                    .font(.subheadline)
                }
                .disabled(uploading)

                if profile.photoPath != nil {
                    Button(role: .destructive) {
                        showDeletePhotoConfirmation = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - About

    private func aboutSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("About")

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("No bio yet. Tap Edit Profile to add one.")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }

    // MARK: - Work Bio

    private func workBioSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Work Biography")

            if let workBio = profile.workBio, !workBio.isEmpty {
                Text(workBio)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("No work biography yet. Tap Edit Profile to add one.")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }

    // MARK: - Skills

    private func skillsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Skills")

            if !profile.skills.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(profile.skills) { skill in
                        HStack(spacing: 4) {
                            Text(skill.name)
                                .font(.subheadline.weight(.medium))

                            Button {
                                Task { await removeSkill(skill) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    }
                }
            } else {
                Text("No skills added yet.")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            // Add skill
            HStack {
                TextField("Add a skill...", text: $skillInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .onChange(of: skillInput) { _, newValue in
                        debounceSkillSearch(newValue)
                    }
                    .onSubmit {
                        Task { await addSkill() }
                    }

                Button {
                    Task { await addSkill() }
                } label: {
                    Text("Add")
                        .fontWeight(.medium)
                }
                .disabled(skillInput.trimmingCharacters(in: .whitespaces).isEmpty || isAddingSkill)
            }

            if !skillSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(skillSuggestions) { suggestion in
                            Button {
                                skillInput = suggestion.name
                                Task { await addSkill(name: suggestion.name) }
                            } label: {
                                Text(suggestion.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Jobs

    private func jobsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Work Experience")
                Spacer()
                Button {
                    editingJob = nil
                    showJobForm = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                }
            }

            if !profile.jobs.isEmpty {
                ForEach(profile.jobs) { job in
                    jobCard(job)
                }
            } else {
                Text("No work experience added yet.")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }

    private func jobCard(_ job: UserJob) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.subheadline.bold())
                    Text(job.company)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        editingJob = job
                        showJobForm = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }

                    Button(role: .destructive) {
                        jobToDelete = job
                        showDeleteJobConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }

            HStack(spacing: 12) {
                Text(job.formattedDateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)

                if let location = job.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let description = job.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Details

    private func detailsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Details")

            detailRow(label: "Email", value: profile.email ?? "Not set")
            detailRow(label: "First Name", value: profile.firstName ?? "Not set")
            detailRow(label: "Last Name", value: profile.lastName ?? "Not set")

            if let city = profile.city, !city.isEmpty {
                detailRow(label: "Location", value: city)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Edit Form

    private func editForm(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("First Name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("First name", text: $editFirstName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Last Name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Last name", text: $editLastName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Bio")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(editBio.count)/500")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                TextEditor(text: $editBio)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .onChange(of: editBio) { _, newValue in
                        if newValue.count > 500 {
                            editBio = String(newValue.prefix(500))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Work Biography")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(editWorkBio.count)/1000")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                TextEditor(text: $editWorkBio)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .onChange(of: editWorkBio) { _, newValue in
                        if newValue.count > 1000 {
                            editWorkBio = String(newValue.prefix(1000))
                        }
                    }
            }

            HStack(spacing: 12) {
                Button {
                    Task { await saveProfile() }
                } label: {
                    Text(isSaving ? "Saving..." : "Save Changes")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func startEditing(_ profile: UserProfile) {
        editFirstName = profile.firstName ?? ""
        editLastName = profile.lastName ?? ""
        editBio = profile.bio ?? ""
        editWorkBio = profile.workBio ?? ""
        isEditing = true
    }

    // MARK: - API Calls

    private func loadProfile() async {
        do {
            profile = try await ProfileAPIService.getProfile()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            if profile == nil {
                showError = true
            }
        }
        isLoading = false
    }

    private func saveProfile() async {
        isSaving = true
        do {
            try await ProfileAPIService.updateProfile(
                firstName: editFirstName,
                lastName: editLastName,
                bio: editBio,
                workBio: editWorkBio
            )
            profile?.firstName = editFirstName
            profile?.lastName = editLastName
            profile?.bio = editBio
            profile?.workBio = editWorkBio
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer {
            isUploadingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let photoPath = try await ProfileAPIService.uploadPhoto(imageData: data, filename: "profile.jpg")
            profile?.photoPath = photoPath
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deletePhoto() async {
        do {
            try await ProfileAPIService.deletePhoto()
            profile?.photoPath = nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func debounceSkillSearch(_ query: String) {
        skillSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            skillSuggestions = []
            return
        }
        skillSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await ProfileAPIService.searchSkills(query: trimmed)
                if !Task.isCancelled {
                    skillSuggestions = results.filter { suggestion in
                        !(profile?.skills.contains(where: { $0.id == suggestion.id }) ?? false)
                    }
                }
            } catch {
                // Ignore search errors silently
            }
        }
    }

    private func addSkill(name: String? = nil) async {
        let skillName = (name ?? skillInput).trimmingCharacters(in: .whitespaces)
        guard !skillName.isEmpty else { return }

        if profile?.skills.contains(where: { $0.name.lowercased() == skillName.lowercased() }) == true {
            errorMessage = "Skill already added"
            showError = true
            return
        }

        isAddingSkill = true
        do {
            let skill = try await ProfileAPIService.addSkill(name: skillName)
            profile?.skills.append(skill)
            skillInput = ""
            skillSuggestions = []
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isAddingSkill = false
    }

    private func removeSkill(_ skill: Skill) async {
        guard let index = profile?.skills.firstIndex(where: { $0.id == skill.id }) else { return }
        let removed = profile?.skills.remove(at: index)

        do {
            try await ProfileAPIService.removeSkill(id: skill.id)
        } catch {
            if let removed {
                profile?.skills.insert(removed, at: min(index, profile?.skills.count ?? 0))
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleJobSaved(_ job: UserJob) {
        if let index = profile?.jobs.firstIndex(where: { $0.id == job.id }) {
            profile?.jobs[index] = job
        } else {
            profile?.jobs.insert(job, at: 0)
        }
        // Re-sort: current jobs first, then by start date desc
        profile?.jobs.sort { a, b in
            if a.isCurrentJob && !b.isCurrentJob { return true }
            if !a.isCurrentJob && b.isCurrentJob { return false }
            return (a.startDate ?? "") > (b.startDate ?? "")
        }
    }

    private func deleteJob(_ job: UserJob) async {
        guard let index = profile?.jobs.firstIndex(where: { $0.id == job.id }) else { return }
        let removed = profile?.jobs.remove(at: index)

        do {
            try await ProfileAPIService.deleteJob(id: job.id)
        } catch {
            if let removed {
                profile?.jobs.insert(removed, at: min(index, profile?.jobs.count ?? 0))
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Job Form

struct JobFormView: View {
    let existingJob: UserJob?
    let onSave: (UserJob) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var company = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCurrent = false
    @State private var description = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(existingJob: UserJob?, onSave: @escaping (UserJob) -> Void) {
        self.existingJob = existingJob
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Job Title", text: $title)
                    TextField("Company", text: $company)
                    TextField("Location (optional)", text: $location)
                }

                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                    Toggle("I currently work here", isOn: $isCurrent)

                    if !isCurrent {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("Description (optional)") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(existingJob != nil ? "Edit Job" : "Add Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              company.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onAppear { loadExistingJob() }
        }
    }

    private func loadExistingJob() {
        guard let job = existingJob else { return }
        title = job.title
        company = job.company
        location = job.location ?? ""
        isCurrent = job.isCurrentJob
        description = job.description ?? ""

        if let dateStr = job.startDate {
            startDate = parseDate(dateStr) ?? Date()
        }
        if let dateStr = job.endDate {
            endDate = parseDate(dateStr) ?? Date()
        }
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) { return date }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) { return date }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: dateStr)
    }

    private func save() async {
        isSaving = true
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startStr = dateFormatter.string(from: startDate)
        let endStr = isCurrent ? nil : dateFormatter.string(from: endDate)
        let loc = location.trimmingCharacters(in: .whitespaces)
        let desc = description.trimmingCharacters(in: .whitespaces)

        do {
            let job: UserJob
            if let existing = existingJob {
                job = try await ProfileAPIService.updateJob(
                    id: existing.id,
                    title: title.trimmingCharacters(in: .whitespaces),
                    company: company.trimmingCharacters(in: .whitespaces),
                    location: loc.isEmpty ? nil : loc,
                    startDate: startStr,
                    endDate: endStr,
                    isCurrent: isCurrent,
                    description: desc.isEmpty ? nil : desc
                )
            } else {
                job = try await ProfileAPIService.addJob(
                    title: title.trimmingCharacters(in: .whitespaces),
                    company: company.trimmingCharacters(in: .whitespaces),
                    location: loc.isEmpty ? nil : loc,
                    startDate: startStr,
                    endDate: endStr,
                    isCurrent: isCurrent,
                    description: desc.isEmpty ? nil : desc
                )
            }
            onSave(job)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}
