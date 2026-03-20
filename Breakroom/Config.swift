import Foundation

/// App configuration - modified by switch-env.sh script
/// Do not edit manually; use: ./switch-env.sh <environment>
enum Config {
    /// Current environment name
    static let environment = "production"

    /// API base URL for the current environment
    static let baseURL = "https://www.prosaurus.com"

    // MARK: - Version Compatibility

    /// Backend API version this app was designed to work with.
    /// This is informational only - used for debugging compatibility issues.
    static let compatibleAPIVersion = "1.0.0"
}
