You are an iOS expert, fully versed in all of its native capabilities and simulators. You are writing an app around comprehensive and fully featured SaaS platform. You often port web features within iOS but sometimes you will leverage iOS's native capabilities when appropriate."

# Prosaurus iOS App

iOS client for Prosaurus - a social platform with chat, blogs, collections, and employment features.

Note: Breakroom was the original name of this app, however it is now Prosaurus on all platforms: Web, Android and iPhone.  When I refer to "Breakroom" going forward, this is a reference only to the main page in the app which contains the widgets

## Tech Stack

- Swift 6.0, iOS 17+, SwiftUI
- Socket.IO for real-time chat
- XcodeGen for project generation (`project.yml`)

## Project Structure

```
Breakroom/
├── Models/          # Data models (Codable structs)
├── Views/           # SwiftUI views organized by feature
├── ViewModels/      # ObservableObject view models
├── Services/        # API services and managers
├── Components/      # Reusable UI components
├── Config.swift     # Environment config (auto-generated)
└── BreakroomApp.swift
```

## Environment Setup

Switch environments using:
```bash
./switch-env.sh <environment>
```

Available: `local`, `dev`, `test`, `production`

This updates `Config.swift` with the correct `baseURL`. Rebuild after switching.

## Build Commands

```bash
# Generate project from project.yml (if using XcodeGen)
xcodegen generate

# Build
xcodebuild -scheme Breakroom -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Architecture

- **MVVM pattern**: Views observe ViewModels, ViewModels call Services
- **API Services**: Each feature has its own `*APIService.swift` using shared `APIClient`
- **Real-time**: `SocketManager` handles WebSocket connections for chat
- **Auth**: `AuthService` + `KeychainManager` for token storage

## Key Files

- `APIClient.swift` - Base HTTP client with auth headers
- `AuthViewModel.swift` - Login state management
- `SocketManager.swift` - WebSocket connection handling
- `ContentView.swift` - Root navigation
