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
  - `NetworkMonitor.swift`: Singleton main class with release build auto-disable safety mechanisms
  - **Models/**: Data models for HTTP requests, responses, and sessions
  - **Core/**: Core monitoring engine components
    - **Storage/**: Session storage implementations (file-based and in-memory)
    - **Search/**: Session search service with full-text and regex search capabilities
  - **Filters/**: Advanced filtering engine with complex criteria and regex support
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
Tests are located in `Tests/NetworkMonitorTests/` with comprehensive coverage:
- `NetworkMonitorTests.swift`: Main monitor functionality tests (3 tests)
- `HTTPRequestTests.swift`: Request model tests (8 tests)
- `HTTPResponseTests.swift`: Response model tests (11 tests)
- `HTTPSessionTests.swift`: Session model tests (15 tests)
- `FilterCriteriaTests.swift`: Filtering criteria tests (23 tests)
- `FilterEngineTests.swift`: Filtering engine tests (20 tests)
- `SessionStorageTests.swift`: File storage tests (13 tests)
- `InMemorySessionStorageTests.swift`: In-memory storage tests (16 tests)
- `SessionSearchServiceTests.swift`: Session search tests (23 tests)
- `ReleaseBuildTests.swift`: Release build safety tests (10 tests)

**Total: 142 tests with 100% pass rate**

## Code Style Guidelines

The project follows the style guide in `STYLE_GUIDE.md`:
- Use UpperCamelCase for types, lowerCamelCase for variables/functions
- 4 spaces for indentation (no tabs)
- 120 character line limit
- DocC-style documentation comments for public APIs
- Explicit access control with preference for restrictive levels
- Comprehensive error handling with try-catch blocks

## Implemented Features

### Core Functionality ✅
- **HTTP Models**: Complete request/response/session models with metadata support
- **Advanced Filtering**: Complex conditions, regex patterns, logical operators (AND/OR)
- **Session Storage**: Both file-based and in-memory storage implementations
- **Session Search**: Full-text and regex search with relevance scoring and highlighting
- **Release Safety**: Automatic monitoring disable in release builds with safety mechanisms
- **Error Handling**: Comprehensive error types and localized descriptions

### Storage Systems
#### FileSessionStorage
- JSON and Binary Plist format support
- Automatic cleanup and retention policies  
- Export/import functionality
- Thread-safe operations with background queues

#### InMemorySessionStorage
- High-performance in-memory storage
- Memory usage monitoring and limits
- Recently accessed session tracking
- Easy file storage integration

### Filtering Engine
- **FilterCriteria**: Fluent API for building complex conditions
- **FilterEngine**: Advanced filtering with categorization and pagination
- **Predefined Filters**: Common patterns like `successOnly()`, `errorsOnly()`, `slowRequests()`
- **Regular Expression Support**: URL pattern matching

### Search System
#### SessionSearchService
- Full-text search across all session fields (URL, headers, body, metadata)
- Regular expression search with configurable options
- Advanced relevance scoring algorithm
- Search result highlighting with field-specific matches
- Date range search with preset options
- Multiple sort options (relevance, timestamp, duration, status code)
- Field-specific search configurations
- Performance optimization for large datasets

### Security Features
- **Build Configuration Detection**: Automatic debug/release detection
- **Compile-time Warnings**: Alerts for release builds
- **Runtime Protection**: Safety checks preventing accidental monitoring
- **Data Protection**: Best practices for sensitive information handling

## Development Notes

- Architecture designed to support Charles-like network monitoring capabilities
- SSL decryption and traffic interception features are planned for future implementation
- Focus on defensive security use cases only
- All network interception functionality to be implemented in future milestones