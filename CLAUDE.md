# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
- Build the package: `swift build`
- Run tests: `swift test`
- Open in Xcode: `xed .`

### Running Tests in Xcode
1. Open project in Xcode with `xed .`
2. Use ⌘6 to open Test Navigator
3. Press ⌘U to run all tests or click individual test play buttons

## Project Architecture

This is a Swift Package Manager library for monitoring, analyzing, and filtering network traffic across iOS, macOS, watchOS, and tvOS platforms. The architecture follows a modular design with clear separation of concerns.

### Core Structure
- **Sources/NetworkMonitor/**: Main library source code
  - `NetworkMonitor.swift`: Singleton main class providing start/stop monitoring functionality
  - **Models/**: Data models for HTTP requests, responses, and sessions
  - **Core/**: Core monitoring engine components (planned)
  - **Filters/**: Filtering engine and criteria (planned)
  - **UI/**: SwiftUI components for displaying network data (planned)

### Key Models

#### HTTPRequest (`Sources/NetworkMonitor/Models/HTTPRequest.swift`)
- Represents HTTP requests with URL, method, headers, body, and timestamp
- Supports all standard HTTP methods (GET, POST, PUT, DELETE, etc.)
- Can convert to/from URLRequest
- Provides utilities for JSON decoding and query parameter extraction
- Includes unique hash generation for identification

#### HTTPResponse (`Sources/NetworkMonitor/Models/HTTPResponse.swift`)
- Represents HTTP responses with status code, headers, body, and timing info
- Categorizes status codes (informational, success, redirection, client error, server error)
- Handles different encodings and MIME types
- Provides JSON decoding capabilities
- Includes error handling and caching information

#### HTTPSession (`Sources/NetworkMonitor/Models/HTTPSession.swift`)
- Combines request and response into a session with state management
- Tracks session lifecycle: initialized → sending → waiting → receiving → completed/failed/cancelled
- Supports rich metadata with typed values (string, int, double, bool, date)
- Handles retry counting and related session relationships
- Includes parent/child session relationships for complex flows

### Platform Support
- Minimum versions: iOS 14+, macOS 11+, watchOS 7+, tvOS 14+
- Swift 5.9+ required
- No external dependencies

### Testing Structure
Tests are located in `Tests/NetworkMonitorTests/` with individual test files for each model:
- `NetworkMonitorTests.swift`: Main monitor functionality tests
- `HTTPRequestTests.swift`: Request model tests
- `HTTPResponseTests.swift`: Response model tests  
- `HTTPSessionTests.swift`: Session model tests

## Code Style Guidelines

The project follows the style guide in `STYLE_GUIDE.md`:
- Use UpperCamelCase for types, lowerCamelCase for variables/functions
- 4 spaces for indentation (no tabs)
- 120 character line limit
- DocC-style documentation comments for public APIs
- Explicit access control with preference for restrictive levels
- Comprehensive error handling with try-catch blocks

## Development Notes

- This is currently a foundational library with core models implemented
- Main monitoring functionality (`NetworkMonitor.start()`) is stubbed for future implementation
- The architecture is designed to support Charles-like network monitoring capabilities
- SSL decryption and traffic interception features are planned but not yet implemented
- Focus on defensive security use cases only