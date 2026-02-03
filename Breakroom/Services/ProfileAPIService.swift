import Foundation

enum ProfileAPIService {
    static func getProfile() async throws -> UserProfile {
        let response: ProfileResponse = try await APIClient.shared.request(
            "/api/profile"
        )
        return response.user
    }

    static func updateProfile(firstName: String, lastName: String, bio: String, workBio: String) async throws {
        let body = UpdateProfileRequest(firstName: firstName, lastName: lastName, bio: bio, workBio: workBio)
        try await APIClient.shared.requestVoid(
            "/api/profile",
            method: "PUT",
            body: body
        )
    }

    // MARK: - Photo

    static func uploadPhoto(imageData: Data, filename: String) async throws -> String {
        let response: PhotoUploadResponse = try await APIClient.shared.uploadMultipart(
            "/api/profile/photo",
            fileData: imageData,
            fieldName: "photo",
            filename: filename,
            mimeType: "image/jpeg"
        )
        return response.photoPath ?? ""
    }

    static func deletePhoto() async throws {
        try await APIClient.shared.requestVoid(
            "/api/profile/photo",
            method: "DELETE"
        )
    }

    // MARK: - Skills

    static func searchSkills(query: String) async throws -> [Skill] {
        let response: SkillsSearchResponse = try await APIClient.shared.request(
            "/api/profile/skills/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        )
        return response.skills
    }

    static func addSkill(name: String) async throws -> Skill {
        let body = AddSkillRequest(name: name)
        let response: SkillAddResponse = try await APIClient.shared.request(
            "/api/profile/skills",
            method: "POST",
            body: body
        )
        return response.skill
    }

    static func removeSkill(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/profile/skills/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Jobs

    static func addJob(title: String, company: String, location: String?, startDate: String, endDate: String?, isCurrent: Bool, description: String?) async throws -> UserJob {
        let body = CreateJobRequest(title: title, company: company, location: location, startDate: startDate, endDate: endDate, isCurrent: isCurrent, description: description)
        let response: JobResponse = try await APIClient.shared.request(
            "/api/profile/jobs",
            method: "POST",
            body: body
        )
        return response.job
    }

    static func updateJob(id: Int, title: String, company: String, location: String?, startDate: String, endDate: String?, isCurrent: Bool, description: String?) async throws -> UserJob {
        let body = UpdateJobRequest(title: title, company: company, location: location, startDate: startDate, endDate: endDate, isCurrent: isCurrent, description: description)
        let response: JobResponse = try await APIClient.shared.request(
            "/api/profile/jobs/\(id)",
            method: "PUT",
            body: body
        )
        return response.job
    }

    static func deleteJob(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/profile/jobs/\(id)",
            method: "DELETE"
        )
    }
}
