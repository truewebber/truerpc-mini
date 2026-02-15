# TrueRPCMini

A minimal, native macOS gRPC client inspired by the now-deprecated BloomRPC.

> **Note**: A full-featured TrueRPC client is coming soon at [truerpc.app](https://truerpc.app). This mini version serves as a proof of concept and technology demonstration.

[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

## Goals

- **Simple and functional gRPC client**: Provide a lightweight alternative to BloomRPC for testing gRPC services on macOS
- **Demonstration of runtime proto parsing**: Showcase [SwiftProtoParser](https://github.com/truewebber/swift-protoparser) and [SwiftProtoReflect](https://github.com/truewebber/swift-protoreflect) capabilities
- **Native macOS experience**: Built with SwiftUI for a modern, native application

## Features

- Import `.proto` files at runtime (no code generation required)
- Browse services and methods from proto definitions
- Execute unary gRPC requests with JSON payloads
- View formatted responses

## Architecture

The project follows Clean Architecture principles with strict separation of concerns:

- **Domain Layer**: Business logic, entities, and use cases
- **Data Layer**: Repositories and data sources
- **Presentation Layer**: SwiftUI views and view models

Test-Driven Development (TDD) is enforced throughout the codebase.

## Requirements

- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

1. Install XcodeGen:
```bash
brew install xcodegen
```

2. Generate the Xcode project:
```bash
xcodegen generate
```

3. Open the project:
```bash
open TrueRPCMini.xcodeproj
```

## Development

The project uses XcodeGen for project generation. All project configuration is defined in `project.yml`.

### Project Structure

```
Sources/
├── App/               # Entry point and DI container
├── Domain/            # Business logic layer
│   ├── Entities/
│   ├── UseCases/
│   └── Interfaces/
├── Data/              # Data access layer
│   ├── Repositories/
│   └── DataSources/
└── Presentation/      # UI layer
    ├── Views/
    └── ViewModels/
```

### Running Tests

```bash
xcodebuild test -scheme TrueRPCMini -destination 'platform=macOS'
```

## Dependencies

- [SwiftProtoParser](https://github.com/truewebber/swift-protoparser) - Runtime `.proto` file parsing
- [SwiftProtoReflect](https://github.com/truewebber/swift-protoreflect) - Dynamic protobuf message creation and manipulation

## Acknowledgments

Inspired by [BloomRPC](https://github.com/bloomrpc/bloomrpc), which provided an excellent GUI for gRPC testing before being deprecated.
