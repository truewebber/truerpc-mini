# Epic: JSON Formatter & Smart Indentation in Request Editor

## Product Need

Developers using TrueRPC-mini spend unnecessary time manually formatting gRPC request JSON bodies
before sending requests. The request editor currently provides no formatting assistance: auto-generated
mock data is delivered as compact JSON, and there is no way to pretty-print content with a single
action. Additionally, the editor offers no indentation guidance while typing, making it tedious to
compose nested JSON structures by hand. This epic introduces a Format button, automatic pretty-printing
on mock data load, and smart auto-indentation while typing — bringing the editor closer to the
experience of a professional IDE.

## Pain Points

- Auto-generated mock data is compact (one line), requiring manual reformatting before the structure
  is readable.
- No keyboard- or button-based way to pretty-print JSON already in the editor.
- Pressing Enter inside a nested object or array produces no indentation — the cursor always jumps
  to column 0, forcing the user to add spaces manually.
- Fields at the same nesting level lose visual alignment quickly when typed by hand.
- Autocomplete-inserted fields do not respect the surrounding indentation context.

## Use Cases

1. **Developer loads mock data** → clicks auto-generate button → the editor shows pretty-printed
   JSON immediately, no extra step required.
2. **Developer pastes compact JSON** from another tool → clicks Format button → JSON is expanded
   with consistent 2-space indentation.
3. **Developer types a nested object** → opens `{`, presses Enter → cursor lands at the correct
   indented position; closing `}` is not inserted automatically.
4. **Developer places cursor between `{` and `}`** and presses Enter → the closing brace is pushed
   to a new line and the cursor lands on the empty middle line with +1 indentation.
5. **Developer selects a field from autocomplete** → inserted field and its value respect the
   current indentation level.
6. **Developer has invalid JSON in the editor** → clicks Format → JSON is not modified, an inline
   error indicator appears.

## UI/UX Spec

- **Format button:** icon `curlybraces` (SF Symbols), placed in the "Request Body" header to the
  right of the existing `↺` (auto-generate) button. Identical button added to the "Metadata" header.
- The button is disabled (grayed out) while a gRPC request is executing (`isLoading == true`).
- On format error: a short inline badge (e.g. "Invalid JSON") appears near the button; no modal
  or sheet.
- Auto-indentation is invisible UX — it just works as the user types; no settings or toggles.

## Scope & Constraints

**In scope:**
- Format button for Request Body and Metadata editors.
- Auto-formatting (pretty-print) when mock data is loaded via auto-generate / reset-to-preset.
- Smart Enter key handling: auto-indentation based on the preceding character.
- Cursor-position-aware indentation: no auto-indent when cursor is inside a string literal.
- Auto-indentation of content inserted by `SmartInsertService` (autocomplete).

**Out of scope (this iteration):**
- Keyboard shortcuts for formatting.
- Auto-closing of `}` / `]` when the user opens a brace (no bracket auto-pair).
- Automatic comma insertion or removal.
- Formatting or indenting the response body (read-only).
- Syntax highlighting.

**Technical constraints:**
- `JSONTextEditor` wraps `NSTextView` (AppKit). All indentation logic must be implemented in
  the `NSTextViewDelegate` / `NSTextStorageDelegate` path.
- Detecting "cursor inside string literal" requires walking the raw text up to the cursor position
  (`JsonPathResolver` already does similar work and can be extended).
- `JSONSerialization` with `.prettyPrinted` handles escaped string values (e.g. `{"a":"{\"b\":[]}"}`)
  correctly out of the box; no custom string-level JSON parser is needed for the Format action.
- **`insertNewline` interception:** the current `doCommandBy` handler intercepts Enter only when
  `vm.isVisible` (autocomplete popover is open). Auto-indentation must intercept `insertNewline`
  regardless of autocomplete state; the guard must be restructured so Enter handling is split into
  two independent paths: autocomplete navigation (existing) and auto-indentation (new).
- **`SmartInsertService` closing braces:** the service already appends `\n}` / `\n]` strings for
  unclosed braces (see `applySmartInsert`). These are currently inserted without indentation.
  As part of this epic the service must receive the indentation context so the generated suffixes
  carry the correct leading whitespace.

## Acceptance Criteria

### AC-1: Format Button — valid JSON

- [ ] A button with the `curlybraces` SF Symbol is visible in the "Request Body" header to the
      right of the `↺` button.
- [ ] Clicking the button on a valid JSON string replaces the editor content with 2-space
      indented pretty-printed JSON.
- [ ] The operation is idempotent: formatting already-formatted JSON produces no visible change.
- [ ] Smart quotes (`"`, `"`) in the input are normalised to `"` before formatting.

### AC-2: Format Button — invalid JSON

- [ ] Clicking the button when the editor contains invalid JSON does **not** modify the content.
- [ ] An inline error indicator (e.g. "Invalid JSON" badge near the button) is shown.
- [ ] The error indicator disappears when the editor content becomes valid JSON or is cleared.

### AC-3: Format Button — edge cases

- [ ] Formatting `{}` → result is `{}` (no expansion of empty objects).
- [ ] Formatting `{ }` (with spaces) → result is `{}`.
- [ ] Formatting an empty string → no-op, no error shown.
- [ ] Formatting a string containing an escaped JSON-like value (e.g. `{"a":"{\"b\":[]}"}`) →
      only the outer structure is pretty-printed; the string value is left intact.
- [ ] Button is disabled while `isLoading == true`.

### AC-4: Format Button — Metadata editor

- [ ] An identical Format button exists in the "Metadata" header.
- [ ] It operates on `metadataJson` independently of the Request Body editor.
- [ ] All AC-1, AC-2, AC-3 rules apply.

### AC-5: Auto-format on mock data load

- [ ] When the user clicks the auto-generate / `↺` button, the resulting JSON is pretty-printed
      (2-space indented) before being set in the editor.
- [ ] If `MockDataGenerator` returns `{}` (no required fields), `{}` is shown as-is.
- [ ] If `MockDataGenerator` returns structurally invalid JSON (should not happen), the raw string
      is shown without crash or data loss.

### AC-6: Auto-indentation — Enter after opening brace/bracket

- [ ] Pressing Enter immediately after `{` or `[` (not inside a string literal) → cursor moves to
      a new line with indentation = current line indentation + 2 spaces.
- [ ] No closing `}` or `]` is inserted automatically.
- [ ] No comma is inserted automatically.

### AC-7: Auto-indentation — Enter inside empty `{}` or `[]`

- [ ] When the cursor is positioned between `{` and `}` (or `[` and `]`) with only whitespace
      (spaces, tabs) between them — including the case of no characters at all (`{|}`) — and the
      user presses Enter, the closing symbol is pushed to a new line at the original indentation
      level, and the cursor lands on the empty middle line with original indentation + 2 spaces.
- [ ] This is the **only** case where the editor moves an existing closing symbol.
- [ ] This rule applies only when the cursor is **not** inside a string literal.

### AC-8: Auto-indentation — Enter after a field line

- [ ] Pressing Enter at the end of a field line (e.g. `  "name": "Alice"` or `  "name": "Alice",`)
      → next line starts at the same indentation level as the current line.
- [ ] The presence or absence of a trailing comma does not affect the indentation level.
- [ ] Pressing Enter in the **middle** of a line (cursor not at the end) → the text is split at the
      cursor and the new line starts at the same indentation level as the current line (the
      characters to the right of the cursor move down; no additional indent is added or removed).
- [ ] If the user has an active **text selection** when pressing Enter, the selected text is deleted
      and replaced with a newline; the new line starts at the indentation level of the line where
      the selection began.

### AC-9: Auto-indentation — Enter after closing brace/bracket

- [ ] If `}` or `]` is at the **end of a value line** (e.g. `  "nested": {}`), pressing Enter
      → next line indentation = current line's indentation (same level, not reduced further).
- [ ] If `}` or `]` is the **sole content of a line** (i.e. the closing brace is already on its
      own dedented line), pressing Enter → next line starts at the same indentation as that line.

### AC-10: Auto-indentation — string literal awareness

- [ ] When the cursor is inside a JSON string literal (between unescaped `"` characters), pressing
      Enter or typing `{`, `[`, `}`, `]` does **not** trigger any auto-indentation logic.
- [ ] Characters are inserted verbatim (creating potentially invalid JSON is the user's
      responsibility; the editor does not block it).
- [ ] Detection is implemented via `isInsideStringLiteral(in:at:)` logic (extending or reusing
      `JsonPathResolver`).

### AC-11: Auto-indentation — autocomplete insertion

- [ ] When a field is inserted via autocomplete (`SmartInsertService`), the inserted text respects
      the indentation context of the cursor position (same level as surrounding fields).
- [ ] If the inserted value is a nested object literal (e.g. `"field": {}`), it is placed inline;
      the user can subsequently press Enter between `{` and `}` to trigger AC-7.
- [ ] All auto-generated closing braces / brackets appended by `SmartInsertService` (the `\n}`
      and `\n]` suffix patches) are indented at the correct level relative to the insertion point.
      Example: a field inserted at 2-space depth must produce `\n  }`, not `\n}`.
- [ ] No commas are inserted or removed by autocomplete.

## Definition of Done

- [ ] All AC criteria above are met.
- [ ] `JsonFormatter` (or equivalent Domain utility) has 100% unit-test coverage for all Format
      scenarios including edge cases (empty string, `{}`, escaped values, invalid JSON).
- [ ] `isInsideStringLiteral` logic has dedicated unit tests covering nested escaped quotes,
      empty strings, and values like `"{\"b\":[]}"`.
- [ ] Auto-indentation logic in `JSONTextEditor` is covered by integration tests.
- [ ] `SmartInsertService` indentation tests updated: closing-brace suffixes carry correct
      leading whitespace for every nesting depth (including depth 0, 1, and 2+).
- [ ] Integration tests cover: Enter mid-line, Enter with active selection, Enter inside `{ }`
      with whitespace.
- [ ] `make format && make lint` exit 0.
- [ ] Project builds and all tests pass via `xcodebuild`.
