# Development Plan & Technical Backlog

**Reference Application:** BloomRPC  
**Architecture:** Clean Architecture + MVVM + TDD (100% coverage goal)  
**Stack:** Swift + SwiftUI + macOS 14.0+

Status: **Completed** (Epic 2 + 2.5 Data Layer) ✅

## Process
Follow strict TDD & Clean Architecture rules (`.cursor/rules/`).
Check off items as completed.

**Test Coverage:** 35 tests passing

---

## FEATURE OVERVIEW (BloomRPC Parity)

### Phase 1: Core Functionality (MVP)
- ✅ Epic 1: Project Foundation
- ✅ Epic 2: Proto File Import & Sidebar
- 🔄 Epic 3: Request Editor (JSON)
- 🔄 Epic 4: Request Execution (Unary)
- 🔄 Epic 5: Response Display

### Phase 2: Advanced Request Features
- ⏳ Epic 6: Metadata Editor (gRPC Headers)
- ⏳ Epic 7: Environment Management
- ⏳ Epic 8: Tab Management & Persistence

### Phase 3: Streaming & Advanced
- ⏳ Epic 9: Server Streaming
- ⏳ Epic 10: Client Streaming
- ⏳ Epic 11: Bi-Directional Streaming
- ⏳ Epic 12: TLS/SSL Support

### Phase 4: UX & Productivity
- ⏳ Epic 13: Request/Response Persistence
- ⏳ Epic 14: Proto Viewer & Filtering
- ⏳ Epic 15: Response Export & Search
- ⏳ Epic 16: Keyboard Shortcuts

### Phase 5: Enterprise Features
- ⏳ Epic 17: Server Reflection
- ⏳ Epic 18: Import Paths Management
- ⏳ Epic 19: gRPC-Web Support
- ⏳ Epic 20: Request Cancellation

---

## Epic 1: Project Foundation (Infrastructure) ✅
Setup the core dependency injection and app entry point structure.

- [x] **DI Container Setup**
    - Create `AppDI` (Dependency Injection Container).
    - Setup Composition Root in `TrueRPCMiniApp`.
    - **Tests:** 8 passing

**Completed:** Feb 15, 2026

---

## Epic 2: Proto File Import & Sidebar ✅
**BloomRPC Feature:** Proto file import from filesystem with hierarchical service/method tree.

**Use Case:**
1. User clicks "Import" button
2. Selects `.proto` file via file picker
3. Proto is parsed and displayed in sidebar
4. Services and methods shown in expandable tree
5. Proto file list persisted (paths only, not content)

### 2.1 Domain Layer ✅
- [x] **Entity: `ProtoFile`** - Pure domain entity with `name`, `path`, `services`
- [x] **Entity: `Service` & `Method`** - Lightweight representations for UI tree
- [x] **Interface: `ProtoRepositoryProtocol`** - Repository abstraction
- [x] **Interface: `ImportProtoFileUseCaseProtocol`** - Use Case abstraction (DIP)
- [x] **Use Case: `ImportProtoFileUseCase`** - Business logic for import
    - **Tests:** 4 passing

### 2.2 Data Layer ✅
- [x] **Repository: `FileSystemProtoRepository`**
    - Uses `SwiftProtoParser.parseProtoToDescriptors()`
    - Maps `Google_Protobuf_FileDescriptorProto` to Domain Entities
    - **Tests:** 6 passing

### 2.3 Presentation Layer ✅
- [x] **ViewModel: `SidebarViewModel`** - State management for sidebar
    - **Tests:** 6 passing
- [x] **View: `SidebarView`** - SwiftUI hierarchical tree with DisclosureGroups
- [x] **DI Integration** - All dependencies wired in `AppDI`

**Total Tests:** 16 (4 UseCase + 6 Repository + 6 ViewModel)  
**Completed:** Feb 15, 2026

---

## Epic 2.5: Import Paths Management - Data Layer ✅
**BloomRPC Feature:** Support for proto files with import dependencies.

**Use Case:**
1. Proto files often import other proto files: `import "common/types.proto"`
2. Import paths configure directories where dependencies are searched  
3. Paths are persisted in UserDefaults for reuse across sessions

**Status:** Data Layer completed. UI layer (Presentation) deferred to later phase.

### 2.5.1 Domain Layer ✅
- [x] **Interface: `ImportPathsRepositoryProtocol`**
    - `func getImportPaths() -> [String]`
    - `func saveImportPaths(_ paths: [String])`
- [x] **Update: `ProtoRepositoryProtocol`**
    - Added `loadProto(url: URL, importPaths: [String])` overload
    - Backward compatible with original `loadProto(url:)` method

### 2.5.2 Data Layer ✅
- [x] **Repository: `UserDefaultsImportPathsRepository`**
    - Persists import paths array to UserDefaults
    - Key: `com.truewebber.TrueRPCMini.importPaths`
    - **Tests:** 8 passing (persistence, edge cases, special characters)
- [x] **Update: `FileSystemProtoRepository`**
    - New method using `parseProtoFileWithImportsToDescriptors()`
    - Resolves import statements via provided paths
    - **Tests:** 3 new tests for import resolution scenarios

### 2.5.3 Integration Layer 🔄
- [x] **Update: `ImportProtoFileUseCase`** - Accept importPaths parameter
- [x] **Update: `SidebarViewModel`** - Inject ImportPathsRepository and use import paths
- [x] **Update: `AppDI`** - Wire ImportPathsRepository dependency

### 2.5.4 Presentation Layer - UI (Deferred to Future Epic)
- [ ] **ViewModel: `ImportPathsViewModel`** - Manage paths list, add/remove actions
- [ ] **View: `ImportPathsSettingsView`** - Settings modal with path table, folder picker
- [ ] **Integration: Button in SidebarView** - "Import Paths" button to open settings

**Total Tests in Epic 2.5:** 10 (8 ImportPaths + 3 FileSystem with imports)  
**Completed:** Feb 15, 2026 (Data + Integration Layer)

**Current State:** Import paths functionality is wired up and working. By default, empty array is used (works for proto files without imports). Users can programmatically configure paths via repository. UI for managing paths deferred to later epic - not required for MVP.

---

## Epic 2.6: Proto Files Persistence 🔄
**BloomRPC Feature:** Save proto file paths, restore on app restart.

**Use Case:**
1. User imports proto files → paths saved to UserDefaults
2. User closes app
3. User reopens app → proto files automatically reloaded from saved paths
4. If file missing, show error but continue loading others

**BloomRPC Implementation:**
- Saves: Array of proto file paths in `editor` store (`"protos"` key)
- Loads: On app startup in `hydrateEditor()` → calls `loadProtos(savedProtos, importPaths)`
- Error handling: If proto missing, silently skip

### 2.6.1 Domain Layer
- [x] **Interface: `ProtoPathsPersistenceProtocol`**
    - `func saveProtoPaths(_ paths: [URL])`
    - `func getProtoPaths() -> [URL]`
- [x] **Use Case: `LoadSavedProtosUseCase`**
    - Input: Array of URLs from persistence
    - Output: Array of `ProtoFile` (skips failed loads)
    - Calls `ImportProtoFileUseCase` for each URL
    - **Tests:** 5 tests covering all scenarios

### 2.6.2 Data Layer
- [x] **Repository: `UserDefaultsProtoPathsRepository`**
    - Persists proto paths to UserDefaults
    - Key: `com.truewebber.TrueRPCMini.protoPaths`
    - **Tests:** 7 tests - Save, load, persistence across instances, edge cases

### 2.6.3 Presentation Layer
- [x] **Update: `SidebarViewModel`**
    - Inject `ProtoPathsPersistenceProtocol`
    - Save paths after successful import
    - Add `loadSavedProtos()` method for startup
- [x] **Update: `TrueRPCMiniApp`**
    - Call `sidebarViewModel.loadSavedProtos()` on startup

**Total Tests in Epic 2.6:** 12 (5 LoadSavedProtos + 7 ProtoPathsPersistence)  
**Completed:** Feb 15, 2026  
**Fixed:** Feb 15, 2026 - Lifecycle and persistence issues

**Progress:** ✅ **COMPLETE**

**Current State:** Proto files are now persisted across app restarts. On startup, the app loads previously imported proto files from UserDefaults. Failed loads (e.g., deleted files) are silently skipped to provide graceful degradation.

**Implementation Notes:**
- `SidebarViewModel` uses `@StateObject` to maintain single instance across view lifecycle
- `UserDefaults.synchronize()` ensures immediate persistence
- Debug logging added for troubleshooting
- Tested: Import → Close → Reopen → Files restored ✅

---

## Epic 3: Request Editor - Basic JSON Editor 🔄
**BloomRPC Feature:** JSON editor with syntax highlighting for editing request payload.

**Use Case:**
1. User selects method from sidebar (single click)
2. New tab opens with request editor
3. Request JSON auto-populated with mock data
4. User edits JSON in text editor
5. Server URL input at top

### 3.1 Domain Layer
- [ ] **Entity: `EditorTab`**
    - Contains: `id`, `methodName`, `serviceName`, `protoFile`
- [ ] **Entity: `RequestDraft`**
    - Contains: `jsonBody: String`, `url: String`, `method: Method`
- [ ] **Use Case: `CreateEditorTabUseCase`**
    - Input: `Method`, `Service`, `ProtoFile`
    - Output: `EditorTab` with default state
- [ ] **Use Case: `GenerateMockDataUseCase`**
    - Input: `Method` (inputType)
    - Output: JSON String with mock data

### 3.2 Data Layer
- [ ] **Service: `MockDataGenerator`**
    - Uses `SwiftProtoReflect` to generate default JSON
    - Walks message schema, creates sample values

### 3.3 Presentation Layer
- [ ] **ViewModel: `EditorTabViewModel`**
    - State: `requestJson: String`, `url: String`, `isLoading: Bool`
    - Actions: `updateJson()`, `updateUrl()`
- [ ] **View: `RequestEditorView`**
    - TextEditor for JSON (with monospace font)
    - TextField for server URL
    - Simple layout (no syntax highlighting in MVP)
- [ ] **Update: `TrueRPCMiniApp`**
    - Add NavigationSplitView with Sidebar + Editor

### 3.4 Persistence (part of Epic 13)
- [ ] **Save:** Global URL (last used server address) → UserDefaults
- [ ] **Load:** On app startup, populate URL field with saved value
- [ ] **BloomRPC:** Saves via `storeUrl()` on every URL change, loads via `getUrl()` in Editor init

**Progress:** Not started

---

## Epic 4: Request Execution - Unary RPC 🔄
**BloomRPC Feature:** Execute unary gRPC requests with play button.

**Use Case:**
1. User edits request JSON and URL
2. Clicks "Play" button (or Cmd+Enter)
3. gRPC client created with dynamic message
4. Request sent to server
5. Response displayed in right panel
6. Response time tracked and shown

### 4.1 Domain Layer
- [ ] **Entity: `RequestExecution`**
    - Contains: `RequestDraft`, timestamp, status
- [ ] **Entity: `GrpcResponse`**
    - Contains: `jsonBody: String`, `responseTime: TimeInterval`, `statusCode: Int?`
- [ ] **Interface: `GrpcClientProtocol`**
    - `func executeUnary(request: RequestDraft, method: Method) async throws -> GrpcResponse`
- [ ] **Use Case: `ExecuteUnaryRequestUseCase`**
    - Validates JSON
    - Calls gRPC client
    - Returns response or error

### 4.2 Data Layer
- [ ] **Client: `DynamicGrpcClient`**
    - Uses `SwiftProtoReflect` to create `DynamicMessage` from JSON
    - Uses NIO/gRPC-Swift or custom implementation to send gRPC frame
    - Parses response back to JSON
    - **Note:** Most complex technical component

### 4.3 Presentation Layer
- [ ] **Update: `EditorTabViewModel`**
    - Add `response: GrpcResponse?`, `error: String?`
    - Add `executeRequest()` action
    - State management for loading
- [ ] **View: `ResponseView`**
    - TextEditor (read-only) for response JSON
    - Badge showing response time
    - Error display

**Progress:** Not started

**Technical Risk:** High - Dynamic gRPC client implementation is complex. May need research spike.

---

## Epic 5: Response Display & Export 🔄
**BloomRPC Feature:** View response with formatting, copy, export to file.

**Use Case:**
1. Response appears in right panel after execution
2. JSON formatted and syntax-highlighted (future)
3. Response time badge visible
4. User can copy response
5. User can export to JSON file

### 5.1 Domain Layer
- [ ] **Use Case: `ExportResponseUseCase`**
    - Input: `GrpcResponse`
    - Saves to file with timestamp

### 5.2 Presentation Layer
- [ ] **Update: `ResponseView`**
    - Add "Export" button
    - Add "Copy" button
    - Show empty state when no response
- [ ] **View Model:** Reuse `EditorTabViewModel`

**Progress:** Not started

---

## Epic 6: Metadata Editor (gRPC Headers) ⏳
**BloomRPC Feature:** Edit gRPC metadata (headers) as JSON in collapsible panel.

**Use Case:**
1. User clicks "Metadata" button/toggle
2. Resizable panel appears below request editor
3. User edits metadata as JSON: `{"key": "value"}`
4. Metadata sent with gRPC request
5. Binary metadata support (`key-bin` with encoding prefixes)

### 6.1 Domain Layer
- [ ] **Entity: `GrpcMetadata`**
    - Dictionary of key-value pairs
    - Binary flag for `*-bin` keys
- [ ] **Update: `RequestDraft`**
    - Add `metadata: GrpcMetadata?`

### 6.2 Presentation Layer
- [ ] **Update: `EditorTabViewModel`**
    - Add `metadataJson: String`, `isMetadataVisible: Bool`
- [ ] **Update: `RequestEditorView`**
    - Add collapsible metadata panel (VSplitView)
    - TextEditor for metadata JSON

### 6.3 Persistence (part of Epic 13)
- [ ] **Save:** Global metadata (last used headers) → UserDefaults
- [ ] **Load:** On app startup, populate metadata field
- [ ] **BloomRPC:** Saves via `storeMetadata()` on change, loads via `getMetadata()`

**Progress:** Not started

---

## Epic 7: Environment Management ⏳
**BloomRPC Feature:** Save/load endpoint configurations (URL, metadata, TLS settings).

**Use Case:**
1. User configures URL + metadata + TLS for "Production" environment
2. Saves with name
3. Can switch between "Dev", "Staging", "Production" via dropdown
4. Auto-populates all fields when switching

### 7.1 Domain Layer
- [ ] **Entity: `Environment`**
    - Contains: `name`, `url`, `metadata`, `tlsEnabled`, `tlsConfig`
- [ ] **Interface: `EnvironmentRepositoryProtocol`**
    - CRUD operations for environments
- [ ] **Use Case: `SaveEnvironmentUseCase`**
- [ ] **Use Case: `LoadEnvironmentsUseCase`**

### 7.2 Data Layer
- [ ] **Repository: `UserDefaultsEnvironmentRepository`**
    - Persists environments to UserDefaults (or AppStorage)

### 7.3 Presentation Layer
- [ ] **ViewModel: `EnvironmentPickerViewModel`**
    - State: `environments: [Environment]`, `selectedEnvironment: Environment?`
- [ ] **View: `EnvironmentPickerView`**
    - Dropdown/Picker in address bar
    - Modal for creating/editing environments

### 7.4 Persistence (Built-in)
- [ ] **Save:** Array of environments → UserDefaults key `"environments"`
- [ ] **Load:** On app startup in EnvironmentPickerViewModel
- [ ] **Operations:** Create, update, delete environment triggers immediate save
- [ ] **BloomRPC:** Saves via `saveEnvironment()`, loads via `getEnvironments()`

**Progress:** Not started

---

## Epic 8: Tab Management & Persistence ⏳
**BloomRPC Feature:** Multiple tabs for different methods, persisted across app restarts.

**Use Case:**
1. User double-clicks method in sidebar → new tab always created
2. Single click → switches to existing tab or creates if none
3. Tabs can be closed (X button)
4. Tabs can be reordered (drag & drop)
5. On app restart, tabs restored with their request data

### 8.1 Domain Layer
- [ ] **Entity: `EditorTabState`**
    - Full snapshot of tab: JSON, URL, metadata, method reference
- [ ] **Interface: `TabPersistenceProtocol`**
    - Save/load tab states
- [ ] **Use Case: `SaveTabStateUseCase`**
- [ ] **Use Case: `RestoreTabsUseCase`**

### 8.2 Data Layer
- [ ] **Repository: `UserDefaultsTabRepository`**
    - Persists tab array to UserDefaults

### 8.3 Presentation Layer
- [ ] **ViewModel: `TabManagerViewModel`**
    - State: `tabs: [EditorTabViewModel]`, `activeTabId: UUID`
    - Actions: `createTab()`, `closeTab()`, `switchTab()`, `reorderTabs()`
- [ ] **View: `TabBarView`**
    - Custom SwiftUI tab bar with draggable tabs
    - Close buttons

### 8.4 Persistence (Built-in)
- [ ] **Save:** Tab structure (metadata) → UserDefaults key `"tabs"`
    - Saves: `tabKey`, `methodName`, `serviceName`, `protoPath` for each tab
    - Active tab key
    - Triggers on: tab create/close/reorder
- [ ] **Load:** On app startup, recreate tabs from metadata
- [ ] **Per-tab request data:** Handled in Epic 13 (separate key per tabKey)
- [ ] **BloomRPC:** Saves via `storeTabs()`, loads via `getTabs()` → `loadTabs()`

**Progress:** Not started

---

## Epic 9: Server Streaming ⏳
**BloomRPC Feature:** Handle server-side streaming with multiple response tabs.

**Use Case:**
1. User selects server-streaming method
2. Sends request
3. Multiple responses arrive over time
4. Each response shown in separate "Stream 1", "Stream 2" tabs
5. Per-response timing

### 9.1 Domain Layer
- [ ] **Entity: `StreamResponse`**
    - Contains: `index: Int`, `jsonBody: String`, `responseTime: TimeInterval`
- [ ] **Update: `GrpcClientProtocol`**
    - Add `func executeServerStreaming() -> AsyncStream<GrpcResponse>`

### 9.2 Data Layer
- [ ] **Update: `DynamicGrpcClient`**
    - Implement server streaming using Swift Concurrency (AsyncStream)

### 9.3 Presentation Layer
- [ ] **Update: `ResponseView`**
    - Add tabbed interface for multiple responses
    - Real-time updates as responses arrive

**Progress:** Not started

---

## Epic 10: Client Streaming ⏳
**BloomRPC Feature:** Send multiple messages in a stream with interactive controls.

**Use Case:**
1. User selects client-streaming method
2. "Interactive" mode: "Push Data" and "Commit Stream" buttons appear
3. User clicks "Push Data" to send each message
4. Clicks "Commit Stream" to close stream and get response
5. "Manual" mode: Send array of messages automatically

### 10.1 Domain Layer
- [ ] **Entity: `StreamRequest`**
    - Array of JSON messages
- [ ] **Update: `GrpcClientProtocol`**
    - Add `func executeClientStreaming(messages: [String]) async throws -> GrpcResponse`

### 10.2 Data Layer
- [ ] **Update: `DynamicGrpcClient`**
    - Implement client streaming with message batching

### 10.3 Presentation Layer
- [ ] **Update: `RequestEditorView`**
    - Add "Interactive"/"Manual" toggle
    - Add "Push Data" and "Commit" buttons for interactive mode
    - Array input for manual mode

**Progress:** Not started

---

## Epic 11: Bi-Directional Streaming ⏳
**BloomRPC Feature:** Full duplex streaming - both client and server streaming simultaneously.

**Use Case:**
1. Combines Epic 9 + Epic 10 logic
2. User can push messages while receiving responses
3. Interactive controls + multiple response tabs

### 11.1 Domain Layer
- [ ] **Update: `GrpcClientProtocol`**
    - Add `func executeBidirectional() -> (input: AsyncStream.Continuation, output: AsyncStream)`

### 11.2 Data Layer
- [ ] **Update: `DynamicGrpcClient`**
    - Full bidirectional implementation

### 11.3 Presentation Layer
- [ ] Combine Epic 9 + Epic 10 UI elements

**Progress:** Not started

---

## Epic 12: TLS/SSL Support ⏳
**BloomRPC Feature:** Connect to secure gRPC endpoints with certificate management.

**Use Case:**
1. User clicks "TLS" button → modal opens
2. Options: Use server certificate, or custom certificates
3. Can upload: Root cert, private key, cert chain
4. SSL target host override
5. Certificates persisted and reusable

### 12.1 Domain Layer
- [ ] **Entity: `TLSConfiguration`**
    - Contains: `enabled: Bool`, `useServerCert: Bool`, `customCerts: CertificateData?`
- [ ] **Entity: `CertificateData`**
    - Root cert, private key, cert chain paths
- [ ] **Interface: `TLSRepositoryProtocol`**
- [ ] **Use Case: `SaveTLSConfigUseCase`**

### 12.2 Data Layer
- [ ] **Repository: `UserDefaultsTLSRepository`**
- [ ] **Update: `DynamicGrpcClient`**
    - TLS configuration support

### 12.3 Presentation Layer
- [ ] **ViewModel: `TLSConfigViewModel`**
- [ ] **View: `TLSConfigView`**
    - Modal sheet with certificate upload
    - Toggle switches

### 12.4 Persistence (Built-in)
- [ ] **Save:** Array of TLS configurations → UserDefaults key `"tlsCertificates"`
- [ ] **Load:** On TLSConfigView mount
- [ ] **Operations:** Add/delete certificate triggers immediate save
- [ ] **BloomRPC:** Saves via `storeTLSList()`, loads via `getTLSList()`

**Progress:** Not started

---

## Epic 13: Request/Response Persistence ⏳
**BloomRPC Feature:** Auto-save request data per tab, restore on app restart.

**Use Case:**
1. User edits request → auto-saved
2. Closes app
3. Reopens app → all tabs restored with their request/response data

**BloomRPC Implementation:**
- **Storage:** `editor` store, key `"requests"` - array of request objects
- **Save trigger:** Every change in request editor (JSON, URL, metadata, etc.)
- **Load:** On tab creation/restoration, calls `getRequestInfo(tabKey)`
- **Per-tab data:** Each tab has unique key, request data stored with that key

### 13.1 Domain Layer
- [ ] **Entity: `PersistedRequest`**
    - Contains: `tabId`, `url`, `jsonBody`, `metadata`, `tlsConfig`, `environmentName`, `timestamp`
- [ ] **Interface: `RequestPersistenceProtocol`**
    - `func saveRequest(tabId: UUID, request: PersistedRequest)`
    - `func getRequest(tabId: UUID) -> PersistedRequest?`
    - `func getAllRequests() -> [PersistedRequest]`
- [ ] **Use Case: `AutoSaveRequestUseCase`**
    - Debounced auto-save (e.g., 500ms delay)

### 13.2 Data Layer
- [ ] **Repository: `UserDefaultsRequestRepository`**
    - Persists requests to UserDefaults
    - Key: `com.truewebber.TrueRPCMini.requests`
    - Stores as dictionary: `[tabId: requestData]`
    - **Tests:** Save, load, update, persistence

### 13.3 Presentation Layer
- [ ] **Update: `EditorTabViewModel`**
    - Inject `RequestPersistenceProtocol`
    - Observe @Published properties
    - Call save with debounce on any change
- [ ] **Update: `TabManagerViewModel`** (Epic 8)
    - Load saved request data when recreating tabs

### 13.4 Additional Global Settings
- [ ] **Save global URL:** Last used server URL → key `"globalUrl"`
- [ ] **Save global metadata:** Last used metadata → key `"globalMetadata"`
- [ ] **Load on startup:** Populate default values in new tabs

**Progress:** Not started

**BloomRPC Keys:**
- `"requests"` - Array of request objects (one per tab)
- `"url"` - Global URL
- `"metadata"` - Global metadata

---

## Epic 14: Proto Viewer & Filtering ⏳
**BloomRPC Feature:** View raw proto text, filter methods by name.

**Use Case:**
1. User clicks "View Proto" button → drawer opens with proto text
2. User clicks "Filter" → search input appears
3. Types method name → sidebar filters to matching methods

### 14.1 Presentation Layer
- [ ] **Update: `SidebarViewModel`**
    - Add `filterText: String`, filtered list logic
- [ ] **Update: `SidebarView`**
    - Add search field
    - Add "View Proto" button
- [ ] **View: `ProtoViewerView`**
    - Sheet/drawer with read-only proto text

**Progress:** Not started

---

## Epic 15: Response Export & Search ⏳
**BloomRPC Feature:** Export response to JSON file, search within response.

**Use Case:**
1. User clicks "Export" → file save dialog
2. Response saved to JSON file with timestamp
3. User presses Cmd+F → search field appears in response viewer

### 15.1 Presentation Layer
- [ ] **Update: `ResponseView`**
    - Add export button
    - Add search functionality (`.searchable()`)

**Progress:** Not started

---

## Epic 16: Keyboard Shortcuts ⏳
**BloomRPC Feature:** Keyboard-driven workflow.

**Shortcuts:**
- `Cmd+Enter`: Execute request
- `Cmd+W`: Close current tab
- `Cmd+F`: Toggle response search
- `Esc`: Focus editor

### 16.1 Presentation Layer
- [ ] Implement SwiftUI `.keyboardShortcut()` modifiers throughout app

**Progress:** Not started

---

## Epic 17: Server Reflection ⏳
**BloomRPC Feature:** Discover services without proto files via gRPC reflection.

**Use Case:**
1. User clicks "Import from Server Reflection"
2. Enters server URL in modal
3. App connects and fetches service definitions
4. Services appear in sidebar like regular proto imports

### 17.1 Domain Layer
- [ ] **Use Case: `ImportFromReflectionUseCase`**
    - Input: Server URL
    - Output: Array of `ProtoFile` from reflection

### 17.2 Data Layer
- [ ] **Service: `GrpcReflectionClient`**
    - Implements gRPC Server Reflection protocol
    - Fetches `FileDescriptorProto` from server
    - **Research:** Swift gRPC reflection library (may need custom implementation)

### 17.3 Presentation Layer
- [ ] **View: `ServerReflectionModal`**
    - URL input
    - Connect button
    - Loading state

**Progress:** Not started

**Technical Risk:** Medium - May need to implement reflection client from scratch if no Swift library exists.

---

## Epic 18: Import Paths Management ⏳
**BloomRPC Feature:** Configure directories for resolving proto imports/dependencies.

**Use Case:**
1. User clicks "Import Paths" button → modal opens
2. Table showing list of configured import paths
3. Can add/remove paths with folder picker
4. Paths persisted
5. When importing proto with `import "common/types.proto"`, paths are searched

### 18.1 Domain Layer
- [ ] **Entity: `ImportPathsConfig`**
- [ ] **Interface: `ImportPathsRepositoryProtocol`**
- [ ] **Update: `ProtoRepositoryProtocol`**
    - Add `loadProto(url: URL, importPaths: [String])` overload
    - Use `parseProtoFileWithImportsToDescriptors()` from SwiftProtoParser

### 18.2 Data Layer
- [ ] **Repository: `UserDefaultsImportPathsRepository`**
- [ ] **Update: `FileSystemProtoRepository`**
    - Support import paths parameter
    - Bundle Google well-known types (optional)

### 18.3 Presentation Layer
- [ ] **ViewModel: `ImportPathsViewModel`**
- [ ] **View: `ImportPathsSettingsView`**
    - Table with Add/Remove buttons
    - Folder picker integration
- [ ] **Update: `SidebarViewModel`**
    - Inject `ImportPathsRepositoryProtocol`
    - Pass import paths to Use Case

**Progress:** Not started

---

## Epic 19: gRPC-Web Support ⏳
**BloomRPC Feature:** Execute requests via gRPC-Web protocol (HTTP/1.1).

**Use Case:**
1. User toggles "WEB/GRPC" switch
2. Requests sent via gRPC-Web instead of native gRPC
3. **Limitation:** Client streaming not supported

### 19.1 Data Layer
- [ ] **Client: `GrpcWebClient`**
    - HTTP/1.1 based implementation
    - Base64 encoding for binary data

**Progress:** Not started

**Technical Risk:** Low-Medium - Need to research Swift gRPC-Web libraries or implement HTTP client.

---

## Epic 20: Request Cancellation ⏳
**BloomRPC Feature:** Cancel long-running requests.

**Use Case:**
1. User clicks Play → request starts
2. Play button becomes Pause button (red)
3. User clicks Pause → request cancelled
4. Connection closed gracefully

### 20.1 Domain Layer
- [ ] **Update: `GrpcClientProtocol`**
    - Add `func cancel()` method

### 20.2 Data Layer
- [ ] **Update: `DynamicGrpcClient`**
    - Implement cancellation via Task cancellation

### 20.3 Presentation Layer
- [ ] **Update: `EditorTabViewModel`**
    - Add `cancelRequest()` action
- [ ] **Update: UI**
    - Play button morphs to Pause during execution

**Progress:** Not started

---

## IMPLEMENTATION PRIORITY

### 🚀 Phase 1: MVP (Highest Priority)
1. ✅ Epic 1: Foundation
2. ✅ Epic 2: Proto Import & Sidebar
3. Epic 3: Request Editor
4. Epic 4: Unary Request Execution
5. Epic 5: Response Display

**Goal:** Working unary gRPC client that can load protos, build requests, and display responses.

### 🎯 Phase 2: Core Features
6. Epic 6: Metadata Editor
7. Epic 8: Tab Management
8. Epic 13: Persistence

**Goal:** Full working experience for unary requests with persistence.

### ⚡ Phase 3: Streaming
9. Epic 9: Server Streaming
10. Epic 10: Client Streaming
11. Epic 11: Bidirectional Streaming

**Goal:** Support all gRPC streaming types.

### 🔒 Phase 4: Enterprise
12. Epic 12: TLS/SSL
13. Epic 7: Environments
14. Epic 18: Import Paths
15. Epic 17: Server Reflection

**Goal:** Production-ready features for enterprise use.

### ✨ Phase 5: Polish
16. Epic 14: Proto Viewer & Filtering
17. Epic 15: Response Export & Search
18. Epic 16: Keyboard Shortcuts
19. Epic 19: gRPC-Web
20. Epic 20: Cancellation

**Goal:** UX enhancements and power-user features.

---

## TECHNICAL NOTES

### High-Risk Components
1. **Dynamic gRPC Client** (Epic 4) - Core complexity
2. **Server Reflection** (Epic 17) - May need custom implementation
3. **Streaming** (Epics 9-11) - Complex state management with Swift Concurrency

### Architecture Principles
- **Clean Architecture**: Strict layer separation (Domain → Data, Presentation)
- **Dependency Inversion**: All cross-layer dependencies via protocols
- **TDD**: Write tests first, 100% coverage goal
- **Swift-Way**: Use Swift Concurrency (async/await, actors), SwiftUI declarative patterns
- **No External UI Libraries**: Pure SwiftUI for all UI components

### Persistence Strategy
Following BloomRPC:
- **Proto Files**: Store paths only, reload on startup
- **Tabs**: Store metadata (service, method, proto path), recreate on startup
- **Requests**: Full state per tab
- **Environments**: Persistent configurations
- **TLS Certs**: Persistent certificate data
- **Import Paths**: Persistent directory list

### Storage Mechanism
- **Primary**: `UserDefaults` / `@AppStorage` for simple key-value
- **Future**: Consider Core Data or SQLite for complex relational data (if needed)
- **No Electron-Store equivalent**: Use native Swift persistence

---

## CURRENT STATUS

**Completed:** Epic 1, Epic 2  
**Next:** Epic 3 (Request Editor - Basic JSON)  
**Tests Passing:** 25  
**Lines of Code:** ~1,500 (estimated)

**Latest Commit:** "Presentation Layer" (Feb 15, 2026)
