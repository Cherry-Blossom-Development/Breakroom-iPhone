#!/bin/bash
# switch-env.sh
# Switches the iOS app environment configuration.
#
# Usage:
#   ./switch-env.sh local
#   ./switch-env.sh production
#
# After switching, rebuild the app in Xcode or via:
#   xcodebuild -scheme Breakroom -configuration Debug build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="$SCRIPT_DIR/environments"
CONFIG_FILE="$SCRIPT_DIR/Breakroom/Config.swift"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_usage() {
    echo ""
    echo "Usage: $0 <environment>"
    echo ""
    echo -e "${YELLOW}Available environments:${NC}"
    for env_file in "$ENV_DIR"/*.env; do
        if [[ -f "$env_file" ]]; then
            env_name=$(basename "$env_file" .env)
            echo "  $env_name"
        fi
    done
    echo ""
}

if [[ -z "$1" ]]; then
    echo -e "${RED}Error: No environment specified.${NC}"
    show_usage
    exit 1
fi

ENVIRONMENT="$1"
SOURCE_FILE="$ENV_DIR/$ENVIRONMENT.env"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo -e "${RED}Error: No config found for environment '$ENVIRONMENT'.${NC}"
    show_usage
    exit 1
fi

# Read BASE_URL from the environment file
BASE_URL=$(grep "^BASE_URL=" "$SOURCE_FILE" | cut -d'=' -f2-)

if [[ -z "$BASE_URL" ]]; then
    echo -e "${RED}Error: BASE_URL not found in $SOURCE_FILE${NC}"
    exit 1
fi

# Update Config.swift
cat > "$CONFIG_FILE" << EOF
import Foundation

/// App configuration - modified by switch-env.sh script
/// Do not edit manually; use: ./switch-env.sh <environment>
enum Config {
    /// Current environment name
    static let environment = "$ENVIRONMENT"

    /// API base URL for the current environment
    static let baseURL = "$BASE_URL"
}
EOF

# Copy to active.env for reference
cp "$SOURCE_FILE" "$ENV_DIR/active.env"

echo ""
echo -e "${GREEN}Switched to: $ENVIRONMENT${NC}"
echo -e "${CYAN}BASE_URL:    $BASE_URL${NC}"
echo ""
echo -e "${YELLOW}Now rebuild to apply:${NC}"
echo "  xcodebuild -scheme Breakroom -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build"
echo "  or rebuild in Xcode (Cmd+B)"
echo ""
