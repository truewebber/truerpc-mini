# Google Protocol Buffers Well-Known Types

## Overview
This directory contains Google's well-known types (WKT) that are commonly used in protobuf definitions.

## Included Types

### Core Types
- **empty.proto** - `google.protobuf.Empty` - Empty message (no fields)
- **timestamp.proto** - `google.protobuf.Timestamp` - Point in time
- **duration.proto** - `google.protobuf.Duration` - Time span
- **wrappers.proto** - Nullable wrappers for primitive types

### Additional Types
- **any.proto** - `google.protobuf.Any` - Generic container
- **struct.proto** - `google.protobuf.Struct`, `Value`, `ListValue` - JSON-like structures
- **field_mask.proto** - `google.protobuf.FieldMask` - Field selection
- **api.proto** - API service definitions
- **type.proto** - Type system metadata
- **source_context.proto** - Source location info
- **descriptor.proto** - Proto descriptor definitions

## Automatic Loading

TrueRPCMini automatically loads well-known types on startup:

1. **Bundled with app** - Located in `Resources/google/protobuf/`
2. **Auto-loaded on startup** - No manual import needed
3. **Available for all requests** - Can reference in your proto files

## Import Paths

The app automatically adds the Resources directory to import paths, so your proto files can use:

```protobuf
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service MyService {
  rpc GetStatus(google.protobuf.Empty) returns (StatusResponse);
}
```

## Source

These files are copied from the official protoc distribution (version 33.0):
- Source: `~/Downloads/protoc-33/include/google/protobuf/`
- License: BSD-3-Clause (Google Inc.)

## Implementation Details

### Loading Mechanism
In `SidebarViewModel.loadSavedProtos()`:

```swift
// 1. Load well-known types first (silent, not shown in sidebar)
await loadWellKnownTypes()

// 2. Load user proto files with Resources in import paths
let importPaths = getImportPathsWithWellKnownTypes()
```

### Search Priority
When resolving message types:
1. User-imported proto files
2. Well-known types (google.protobuf.*)
3. Error if not found

## Testing

To verify well-known types work:

```bash
# Check Resources are bundled
open TrueRPCMini.app/Contents/Resources/

# Expected: google/protobuf/*.proto files present
```

## Maintenance

To update well-known types:
1. Download latest protoc from https://github.com/protocolbuffers/protobuf/releases
2. Extract `include/google/protobuf/*.proto`
3. Copy to `Resources/google/protobuf/`
4. Run `xcodegen generate`
