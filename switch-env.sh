#!/bin/bash
# switch-env.sh
# Switches the iOS app environment configuration and restarts the backend if needed.
#
# Usage:
#   ./switch-env.sh local-prod   # Local backend + production database (most common)
#   ./switch-env.sh local-dev    # Local backend + dev database
#   ./switch-env.sh test         # Local backend + isolated test database
#   ./switch-env.sh dev          # EC2 dev server
#   ./switch-env.sh production   # EC2 production server
#
# For local environments, this also restarts the backend with the correct database.
# After switching, rebuild the app in Xcode or via:
#   xcodebuild -scheme Breakroom -configuration Debug build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="$SCRIPT_DIR/environments"
CONFIG_FILE="$SCRIPT_DIR/Breakroom/Config.swift"
BACKEND_DIR="$SCRIPT_DIR/../Breakroom"

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
            if [[ "$env_name" != "active" ]]; then
                case "$env_name" in
                    local-prod)
                        echo "  $env_name  (local backend + production DB) [most common]"
                        ;;
                    local-dev)
                        echo "  $env_name   (local backend + dev DB)"
                        ;;
                    test)
                        echo "  $env_name        (local backend + isolated test DB)"
                        ;;
                    dev)
                        echo "  $env_name         (EC2 dev server)"
                        ;;
                    production)
                        echo "  $env_name  (EC2 production server)"
                        ;;
                    *)
                        echo "  $env_name"
                        ;;
                esac
            fi
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
echo -e "${GREEN}iOS app switched to: $ENVIRONMENT${NC}"
echo -e "${CYAN}BASE_URL: $BASE_URL${NC}"

# Determine if this is a local environment that needs backend restart
# Map environment names to backend compose/env files
case "$ENVIRONMENT" in
    local-dev|local-prod)
        NEEDS_BACKEND=true
        COMPOSE_FILE="docker-compose.local.yml"
        ENV_FILE=".env.$ENVIRONMENT"
        ;;
    test)
        NEEDS_BACKEND=true
        COMPOSE_FILE="docker-compose.test.yml"
        ENV_FILE=".env.test"
        ;;
    *)
        NEEDS_BACKEND=false
        ;;
esac

if [[ "$NEEDS_BACKEND" == "true" ]]; then
    if [[ -d "$BACKEND_DIR" ]]; then
        echo ""
        echo -e "${YELLOW}Restarting backend for $ENVIRONMENT environment...${NC}"

        cd "$BACKEND_DIR"

        # Stop any running local or test containers
        echo -e "${CYAN}Stopping existing containers...${NC}"
        docker compose -f docker-compose.local.yml down 2>/dev/null || true
        docker compose -f docker-compose.test.yml down 2>/dev/null || true

        if [[ -f "$COMPOSE_FILE" && -f "$ENV_FILE" ]]; then
            # Show which database we're connecting to
            DB_NAME=$(grep "^DB_NAME=" "$ENV_FILE" | cut -d'=' -f2-)
            echo -e "${CYAN}Starting backend with $COMPOSE_FILE (DB: $DB_NAME)...${NC}"
            docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
            echo -e "${GREEN}Backend started successfully${NC}"
        else
            echo -e "${RED}Warning: Backend config files not found ($COMPOSE_FILE or $ENV_FILE)${NC}"
        fi

        cd "$SCRIPT_DIR"
    else
        echo -e "${YELLOW}Warning: Backend directory not found at $BACKEND_DIR${NC}"
        echo -e "${YELLOW}You may need to restart the backend manually.${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Now rebuild the iOS app to apply:${NC}"
echo "  xcodebuild -scheme Breakroom -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build"
echo "  or rebuild in Xcode (Cmd+B)"
echo ""
