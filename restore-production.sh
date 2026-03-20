#!/bin/bash
#
# restore-production.sh
# Restores the iOS app to the production environment after testing.
#
# This script:
#   1. Switches the app back to the production API
#   2. Rebuilds the app
#   3. Optionally stops the Breakroom test Docker containers
#
# Usage:
#   ./restore-production.sh
#   ./restore-production.sh --stop-containers    # Also stop test Docker containers
#
# Run this after finishing a test session.

set -e

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BREAKROOM_DIR="$(cd "$SCRIPT_DIR/../Breakroom" 2>/dev/null && pwd)" || BREAKROOM_DIR=""

# --- Parse arguments ---
STOP_CONTAINERS=false
for arg in "$@"; do
    case $arg in
        --stop-containers) STOP_CONTAINERS=true ;;
    esac
done

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

write_step() { echo -e "\n${CYAN}--- $1 ---${NC}"; }
write_ok()   { echo -e "  ${GREEN}[ OK ]${NC}  $1"; }
write_info() { echo -e "  ${YELLOW}[ .. ]${NC}  $1"; }
write_fail() { echo -e "  ${RED}[FAIL]${NC}  $1"; exit 1; }

# ------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   Restore Production Environment         ${NC}"
echo -e "${CYAN}==========================================${NC}"

# --- 1. Switch to production ---
write_step "1/3  Environment"

CURRENT_ENV=$(grep 'static let environment' "$SCRIPT_DIR/Breakroom/Config.swift" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
PRODUCTION_URL=$(grep "^BASE_URL=" "$SCRIPT_DIR/environments/production.env" | cut -d'=' -f2-)

if [ "$CURRENT_ENV" = "production" ]; then
    write_ok "Already pointing at production ($PRODUCTION_URL)"
    write_info "Rebuilding anyway to ensure a clean production build..."
else
    write_info "Switching: '$CURRENT_ENV' -> 'production'"
    "$SCRIPT_DIR/switch-env.sh" production > /dev/null
    write_ok "Switched to production"
fi

# --- 2. Build ---
write_step "2/3  Build"

write_info "Building production app..."

# Find a simulator
SIMULATOR_UDID=$(xcrun simctl list devices available | grep -E "iPhone (17|16|Air)" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
if [ -z "$SIMULATOR_UDID" ]; then
    SIMULATOR_UDID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
fi

xcodebuild -project "$SCRIPT_DIR/Breakroom.xcodeproj" \
    -scheme Breakroom \
    -configuration Debug \
    -destination "id=$SIMULATOR_UDID" \
    -quiet \
    build 2>&1

if [ $? -eq 0 ]; then
    write_ok "Build succeeded"
else
    write_fail "Build failed"
fi

# --- 3. Docker containers (optional) ---
write_step "3/3  Docker test containers"

if [ "$STOP_CONTAINERS" = true ]; then
    if [ -n "$BREAKROOM_DIR" ] && [ -f "$BREAKROOM_DIR/docker-compose.test.yml" ]; then
        write_info "Stopping Breakroom test containers..."
        pushd "$BREAKROOM_DIR" > /dev/null
        docker compose -f docker-compose.test.yml down 2>/dev/null
        DC_EXIT=$?
        popd > /dev/null
        if [ $DC_EXIT -eq 0 ]; then
            write_ok "Test containers stopped"
        else
            write_info "docker compose down returned $DC_EXIT - containers may already be stopped"
        fi
    else
        write_info "Breakroom repo not found - skipping container cleanup"
    fi
else
    if nc -z 127.0.0.1 3001 2>/dev/null; then
        write_info "Test containers still running (pass --stop-containers to stop them)"
    else
        write_ok "Test containers are not running"
    fi
fi

# --- Done ---
echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}  Restored to production${NC}"
echo -e "${CYAN}  API: $PRODUCTION_URL${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
