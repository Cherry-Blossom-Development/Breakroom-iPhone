import Foundation

/// App configuration - modified by switch-env.sh script
/// Do not edit manually; use: ./switch-env.sh <environment>
enum Config {
    /// Current environment name
    static let environment = "dev"

    /// API base URL for the current environment
    static let baseURL = "https://dev.prosaurus.com"
}
