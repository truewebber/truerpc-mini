# UI alignment plan

Work list for the current SwiftUI screens. Decisions live in `.cursor/rules/`. This file only says what to change, in which order, and how to tell a slice is finished.

Do not add a catalog app or snapshot tests. Touch a file once: move types, restyle, and rewrite previews in the same slice. After every slice run `make format`, `make lint`, and render each `#Preview` in the files that slice changed (`RenderPreview`, `sourceFilePath` starts with `TrueRPCMini/`). A preview counts only when the call returns a PNG whose `displayName` matches the preview name below.

`xcodegen generate` after adding or moving Swift files.

## 0. Delete the unused stub

`Sources/Presentation/Views/ContentView.swift` is not referenced.

- [ ] Delete the file.
- **Check:** `rg "struct ContentView" Sources` prints nothing. The app target builds.

## 1. Move types that already have two callers

### `EnvironmentFormView`

Declared in `EnvironmentPickerView.swift`. Also presented from `RequestEditorView.swift`.

- [ ] Move the type unchanged to `Sources/Presentation/Views/Components/EnvironmentFormView.swift`.
- [ ] Add previews in that file: `Create`, `Edit`, `Invalid`, `Dark`. `Edit` passes an existing `ServerEnvironment`. `Invalid` leaves name empty so Save is disabled. `Dark` uses `.preferredColorScheme(.dark)`.
- **Check:** `rg "struct EnvironmentFormView" Sources` prints one path, under `Components/`. Both call sites still compile. Four `#Preview` macros, no `PreviewProvider`. Save stays `.keyboardShortcut(.defaultAction)`, Cancel stays `.keyboardShortcut(.cancelAction)`.

### `SecurityScopedFilePickerButton`

Declared in `ConnectionSettingsPopoverView.swift`. Also used by `EnvironmentFormView`.

- [ ] Move the type unchanged to `Sources/Presentation/Views/Components/SecurityScopedFilePickerButton.swift`.
- [ ] Previews: `Empty`, `Selected`, `Long Name`. `Selected` binds a short file URL. `Long Name` binds a deeply nested path. Trait: `.sizeThatFitsLayout`.
- **Check:** `rg "struct SecurityScopedFilePickerButton" Sources` prints one path, under `Components/`. The clear control is a `Label` with `.labelStyle(.iconOnly)` and a `.help` string, not a bare `Image`.

## 2. Add the three domain visuals

Each one takes plain values, lives in `Components/`, and is the only place that chooses the symbol and the color.

### `ConnectionLockBadge`

`ConnectionSecurityIndicatorView` owns a `ConnectionSecurityViewModel` and two popovers. That stays a screen view. Only the glyph moves out.

- [ ] Add `Components/ConnectionLockBadge.swift` with the three lock states: plaintext, secure, insecure (symbol, semantic color, help string).
- [ ] `ConnectionSecurityIndicatorView` draws the badge and keeps popover wiring.
- [ ] Badge previews: `Plaintext`, `Secure`, `Insecure`, `Dark`. Trait: `.sizeThatFitsLayout`.
- **Check:** the badge type does not mention `ConnectionSecurityViewModel`. `rg "font\\(\\.system\\(size:" Sources/Presentation/Views/ConnectionSecurityIndicatorView.swift` prints nothing.

### `MethodKindIcon`

`MethodRow` in `SidebarView.swift` paints unary green and streaming orange.

- [ ] Add `Components/MethodKindIcon.swift`. Unary and streaming keep different symbols. Color is reinforcement, not the only difference.
- [ ] `MethodRow` uses it and deletes `methodColor`.
- [ ] Previews: `Unary`, `Streaming`, `Dark`.
- **Check:** `rg "methodColor" Sources` prints nothing.

### `GrpcStatusBadge`

The status pill in `ResponseView.headerView` draws its own background and corner.

- [ ] Add `Components/GrpcStatusBadge.swift` with symbol plus status text. No background fill, no `cornerRadius`.
- [ ] `ResponseView` uses it for the status. The duration readout is a clock symbol plus text, same treatment, no filled capsule.
- [ ] Previews: `OK`, `Failed`, `Long Message`, `Dark`.
- **Check:** `rg "cornerRadius|opacity\\(0\\." Sources/Presentation/Views/ResponseView.swift` prints nothing.

## 3. Screens

For every screen in this section:

- Replace `PreviewProvider` with one `#Preview("Name")` per state. No `Group`.
- Data-area states that exist in the view are previewed separately.
- One preview is named `Dark` and sets `.preferredColorScheme(.dark)`.
- One preview is named `Long Content` where a name, path, error, or JSON body can grow.
- Screen previews use `.fixedLayout` at the size that pane has inside the 1100×700 window. Popovers and sheets use their real fixed width.
- Sample values used by two or more files go to `Sources/Presentation/Views/PreviewSupport/` inside `#if DEBUG`. A sample used once stays next to its preview.

### `SidebarView.swift`

- [ ] Empty and error branches become `ContentUnavailableView`. Empty offers `Import…`. Loading stays `ProgressView`.
- [ ] `ProtoFileRow`, `ServiceRow`, and `MethodRow` stay `private` in this file.
- [ ] Preview setup stops registering `UserDefaultsImportPathsRepository`. Use the in-memory preview doubles already in the file.
- [ ] Previews: `Empty`, `Loading`, `Error`, `Data`, `Long Content`, `Dark`.
- **Check:** `rg "UserDefaults" Sources/Presentation/Views/SidebarView.swift` prints nothing. `rg "font\\(\\.system\\(size:"` on this file prints nothing. Six `#Preview` macros.

### `EnvironmentPickerView.swift`

- [ ] Empty branch becomes `ContentUnavailableView` with an add action.
- [ ] `EnvironmentRow` stays `private`.
- [ ] Previews: `Empty`, `List`, `Long Content`, `Dark`.
- **Check:** the form type is gone from this file (it lives in `Components/` after slice 1). Four `#Preview` macros.

### `ImportPathsSettingsView.swift`

- [ ] Empty branch becomes `ContentUnavailableView` with an add action.
- [ ] Previews: `Empty`, `Paths`, `Long Content`, `Dark`.
- **Check:** four `#Preview` macros. `rg "font\\(\\.system\\(size:"` on this file prints nothing.

### `ResponseView.swift`

- [ ] `Empty` uses `ContentUnavailableView` ("No Response Yet", tell the user to run the request). No action button: Play is on the other pane.
- [ ] Pure failure (no response) uses `ContentUnavailableView` and shows the error text. Failure that still has a response keeps the response body plus the error text.
- [ ] Copy and Export stay text buttons. No custom success banner here.
- [ ] Previews: `Empty`, `Executing`, `Success`, `Error`, `Error With Response`, `Long Content`, `Dark`.
- **Check:** seven `#Preview` macros. `rg "PreviewProvider|foregroundColor\\(|cornerRadius" Sources/Presentation/Views/ResponseView.swift` prints nothing.

### `RequestEditorView.swift`

- [ ] Delete the green "Copied to clipboard" overlay. The Copy control itself switches label to "Copied" and back. No `asyncAfter` used only to dismiss a banner.
- [ ] The environment menu stops drawing its own background and corner. Use the system menu label.
- [ ] Play gets `.keyboardShortcut(.return, modifiers: .command)`.
- [ ] Icon-only controls (format, reset, metadata) use `Label` + `.labelStyle(.iconOnly)` + the existing `.help` text.
- [ ] Previews: `Idle`, `Executing`, `Format Error`, `Copied`, `Long Content`, `Dark`. Build the tab view model from the stubs already in this file. `Copied` sets the copied state directly.
- **Check:** `rg "Copied to clipboard|cornerRadius|asyncAfter" Sources/Presentation/Views/RequestEditorView.swift` prints nothing. The command-return shortcut is on the Play button. Six `#Preview` macros.

### `ConnectionSecurityIndicatorView.swift`

- [ ] Previews, one each, not a `Group`: `Plaintext`, `Secure`, `Insecure`, `Environment`, `Dark`.
- [ ] `Insecure` is the relaxed-verification lock state. It has no preview today.
- **Check:** five `#Preview` macros. The view still takes `ConnectionSecurityViewModel` (it is the screen control, not the badge).

### `ConnectionSettingsPopoverView.swift`

- [ ] Previews: `Plaintext`, `TLS`, `Long Content`, `Dark`. Split the current grouped provider.
- **Check:** four `#Preview` macros. The file picker type is gone from this file.

### `AutocompletePopoverView.swift`

- [ ] Kind glyphs keep a distinct symbol per kind. Switch `Color.orange` style calls to `.foregroundStyle(.orange)` (and the same for the other kind colors). The row text stays.
- [ ] Selection uses a system row highlight, not `Color.accentColor.opacity`.
- [ ] Keep the existing accessibility identifiers. `AutocompletePopoverViewTests` must stay green.
- [ ] Previews: `Suggestions`, `Selected`, `One Of`, `Empty`, `Dark`.
- **Check:** `make test-unit` still passes `AutocompletePopoverViewTests`. `rg "Color\\.(orange|green|blue|purple|teal|yellow|cyan)|accentColor\\.opacity" Sources/Presentation/Views/AutocompletePopoverView.swift` prints nothing.

### `GlobalEnvironmentSelectorView.swift`

- [ ] Previews: `Empty`, `Selected`, `Long Content`, `Dark`.
- **Check:** four `#Preview` macros. `rg "foregroundColor\\(" ` on this file prints nothing.

### `TabBarView.swift`

No preview today. `TabBarItemView` stays `private`.

- [ ] Previews: `Single`, `Many`, `Long Content`, `Dark`. Feed plain tab titles in. Do not construct `TrueRPCMiniApp`.
- **Check:** four `#Preview` macros.

### `AboutView.swift`

- [ ] Replace `.font(.system(size: 28, weight: .light))` with a text style.
- [ ] Previews: `Default`, `Dark`.
- **Check:** `rg "font\\(\\.system\\(size:" Sources/Presentation/Views/AboutView.swift` prints nothing. Two `#Preview` macros.

### `JSONTextEditor.swift`

`NSViewRepresentable`. Preview the wrapper, not an editor subclass.

- [ ] Previews: `Empty`, `Document`, `Long Content`. `Document` is a short JSON object. `Long Content` is one long line plus a nested object.
- **Check:** three `#Preview` macros. Rendering `Document` shows the sample text.

### `TrueRPCMiniApp.swift` placeholder

The "Select a method to start" block is the detail column, and constructing `TrueRPCMiniApp` starts Sparkle.

- [ ] Replace the hand-built stack with `ContentUnavailableView` (`Label("No Method Selected", systemImage: "doc.text")` plus a one-sentence description). No action button.
- [ ] Put that view in a small struct in this file so the preview does not call `TrueRPCMiniApp.init`.
- [ ] Previews: `Nothing Selected`, `Dark`.
- **Check:** `rg "font\\(\\.system\\(size:" Sources/App/TrueRPCMiniApp.swift` prints nothing. Neither preview constructs `TrueRPCMiniApp`.

## 4. Repo-wide checks

Run these from the repo root. Each one must print nothing:

```bash
rg "PreviewProvider" Sources
rg "foregroundColor\(" Sources
rg "\.cornerRadius\(" Sources
rg "font\(\.system\(size:" Sources
rg "Color\.(white|black)" Sources
rg "struct (EnvironmentFormView|SecurityScopedFilePickerButton)" Sources/Presentation/Views -g '!Components/**'
```

Then:

- [ ] `make format` and `make lint` exit 0.
- [ ] `make test-unit` passes.
- [ ] Every `#Preview` in `Sources/Presentation/Views` and the app placeholder renders to a PNG. Count of successful renders equals the count of `#Preview` macros (`rg -c "#Preview" ` over those files).
- [ ] `Dark` renders are actually dark: the canvas variant or `.preferredColorScheme(.dark)` is set, and the PNG background is not the light window color.
