import Foundation

/// Resolves JSON edit position to a field path and autocomplete mode by scanning only before `cursorOffset`.
public final class JsonPathResolver: JsonPathResolverProtocol, Sendable {
    public init() {}

    public func resolve(json: String, cursorOffset: Int) -> AutocompleteContext {
        let limit = min(max(0, cursorOffset), json.count)
        guard limit > 0 else {
            return AutocompleteContext(resolvedPath: [], mode: .key)
        }

        var path: [String] = []
        var stack: [StackEntry] = []
        var i = json.startIndex
        var processed = 0
        var rootClosed = false

        while processed < limit, i < json.endIndex {
            skipWhitespace(json: json, index: &i, processed: &processed, limit: limit)
            guard processed < limit, i < json.endIndex else { break }

            if stack.isEmpty {
                let ch = json[i]
                if ch == "{" {
                    stack.append(.object(ObjectFrame()))
                    advance(json: json, index: &i, processed: &processed)
                    continue
                }
                if ch == "[" {
                    stack.append(.array(ArrayFrame()))
                    advance(json: json, index: &i, processed: &processed)
                    continue
                }
                advance(json: json, index: &i, processed: &processed)
                continue
            }

            let stackSizeBefore = stack.count

            switch stack[stack.count - 1] {
            case var .object(frame):
                if processObjectFrame(
                    json: json,
                    limit: limit,
                    frame: &frame,
                    path: &path,
                    stack: &stack,
                    index: &i,
                    processed: &processed)
                {
                    stack[stack.count - 1] = .object(frame)
                }

            case var .array(frame):
                if processArrayFrame(
                    json: json,
                    limit: limit,
                    frame: &frame,
                    path: &path,
                    stack: &stack,
                    index: &i,
                    processed: &processed)
                {
                    stack[stack.count - 1] = .array(frame)
                }
            }

            if stackSizeBefore == 1, stack.isEmpty {
                rootClosed = true
            }
        }

        if rootClosed, stack.isEmpty {
            return AutocompleteContext(resolvedPath: [], mode: .key, isOutsideRootObject: true)
        }

        return context(path: path, stack: stack)
    }

    // MARK: - Private types

    private struct ObjectFrame {
        var afterColon = false
        var lastKey: String?
        var inString = false
        var stringIsKey = false
        var pendingKey = ""
        /// Accumulates characters typed inside a value string literal (for enum-value prefix filtering).
        var pendingValue = ""
        var escapeNext = false
        var popsPathOnClose = false
        var seenKeys: Set<String> = []
        /// Accumulates bare (unquoted) characters typed in key position.
        var pendingBareText = ""
    }

    private struct ArrayFrame {
        var popsPathOnClose = false
        /// Accumulates characters typed inside an incomplete string element (for enum-value prefix filtering).
        /// Reset to `""` when the string closes or a new element begins (`,`).
        var pendingValue = ""
    }

    private enum StackEntry {
        case object(ObjectFrame)
        case array(ArrayFrame)
    }

    // MARK: - Context derivation

    private func context(path: [String], stack: [StackEntry]) -> AutocompleteContext {
        guard let top = stack.last else {
            return AutocompleteContext(resolvedPath: path, mode: .key)
        }

        switch top {
        case let .array(frame):
            return AutocompleteContext(resolvedPath: path, mode: .arrayElement, partialKey: frame.pendingValue)
        case let .object(frame):
            let siblings = frame.seenKeys
            if frame.inString {
                if frame.stringIsKey {
                    return AutocompleteContext(
                        resolvedPath: path,
                        mode: .key,
                        siblingKeys: siblings,
                        partialKey: frame.pendingKey)
                } else {
                    return AutocompleteContext(
                        resolvedPath: path,
                        mode: .enumValue,
                        siblingKeys: siblings,
                        partialKey: frame.pendingValue,
                        currentFieldKey: frame.lastKey)
                }
            }
            if frame.afterColon {
                return AutocompleteContext(
                    resolvedPath: path,
                    mode: .enumValue,
                    siblingKeys: siblings,
                    currentFieldKey: frame.lastKey)
            }
            return AutocompleteContext(
                resolvedPath: path,
                mode: .key,
                siblingKeys: siblings,
                partialKey: frame.pendingBareText)
        }
    }

    // MARK: - Frame processors

    /// Returns true when the frame was mutated and should be written back to the stack.
    private func processObjectFrame(
        json: String,
        limit: Int,
        frame: inout ObjectFrame,
        path: inout [String],
        stack: inout [StackEntry],
        index: inout String.Index,
        processed: inout Int)
        -> Bool
    {
        if frame.inString {
            let ch = json[index]
            advance(json: json, index: &index, processed: &processed)
            if frame.escapeNext {
                frame.escapeNext = false
                if frame.stringIsKey { frame.pendingKey.append(ch) }
                else { frame.pendingValue.append(ch) }
                return true
            }
            if ch == "\\" {
                frame.escapeNext = true
                return true
            }
            if ch == "\"" {
                frame.inString = false
                if frame.stringIsKey {
                    frame.lastKey = frame.pendingKey
                    frame.seenKeys.insert(frame.pendingKey)
                }
                frame.pendingKey = ""
                frame.pendingValue = ""
                return true
            }
            if frame.stringIsKey { frame.pendingKey.append(ch) }
            else { frame.pendingValue.append(ch) }
            return true
        }

        let ch = json[index]
        if ch == "}" {
            let pops = frame.popsPathOnClose
            stack.removeLast()
            if pops, !path.isEmpty { path.removeLast() }
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "," {
            frame.afterColon = false
            frame.lastKey = nil
            frame.pendingBareText = ""
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == ":" {
            frame.afterColon = true
            frame.pendingBareText = ""
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == "\"" {
            frame.inString = true
            frame.stringIsKey = !frame.afterColon
            frame.pendingKey = ""
            frame.pendingValue = ""
            frame.escapeNext = false
            frame.pendingBareText = ""
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == "{" {
            if frame.afterColon, let key = frame.lastKey {
                path.append(key)
                frame.lastKey = nil
                frame.afterColon = false
                stack[stack.count - 1] = .object(frame)
                var nested = ObjectFrame()
                nested.popsPathOnClose = true
                stack.append(.object(nested))
            } else {
                stack.append(.object(ObjectFrame()))
            }
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "[" {
            if frame.afterColon, let key = frame.lastKey {
                path.append(key)
                frame.lastKey = nil
                frame.afterColon = false
                stack[stack.count - 1] = .object(frame)
                var nested = ArrayFrame()
                nested.popsPathOnClose = true
                stack.append(.array(nested))
            } else {
                stack.append(.array(ArrayFrame()))
            }
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if frame.afterColon {
            consumeValueAfterColon(
                json: json,
                limit: limit,
                frame: &frame,
                index: &index,
                processed: &processed)
            return true
        }
        // Bare (unquoted) character in key position — accumulate for partial-key filtering.
        frame.pendingBareText.append(json[index])
        advance(json: json, index: &index, processed: &processed)
        return true
    }

    /// Returns true when the frame was mutated and should be written back to the stack.
    private func processArrayFrame(
        json: String,
        limit: Int,
        frame: inout ArrayFrame,
        path: inout [String],
        stack: inout [StackEntry],
        index: inout String.Index,
        processed: inout Int)
        -> Bool
    {
        let ch = json[index]
        if ch == "]" {
            let pops = frame.popsPathOnClose
            stack.removeLast()
            if pops, !path.isEmpty { path.removeLast() }
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "," {
            frame.pendingValue = ""
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == "{" {
            frame.pendingValue = ""
            stack.append(.object(ObjectFrame()))
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "[" {
            frame.pendingValue = ""
            stack.append(.array(ArrayFrame()))
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "\"" {
            advance(json: json, index: &index, processed: &processed)
            // Track partial string content for enum-value prefix filtering.
            // If the string closes before the limit, reset pendingValue (complete element).
            // If the limit is reached inside the string, pendingValue holds what the user typed so far.
            var accumulated = ""
            var escape = false
            var completed = false
            while index < json.endIndex, processed < limit {
                let c = json[index]
                advance(json: json, index: &index, processed: &processed)
                if escape { escape = false
                    accumulated.append(c)
                    continue
                }
                if c == "\\" { escape = true
                    continue
                }
                if c == "\"" { completed = true
                    break
                }
                accumulated.append(c)
            }
            frame.pendingValue = completed ? "" : accumulated
            return true
        }
        frame.pendingValue = ""
        consumePrimitive(json: json, limit: limit, index: &index, processed: &processed)
        return true
    }

    // MARK: - Value consumers

    private func consumeValueAfterColon(
        json: String,
        limit: Int,
        frame: inout ObjectFrame,
        index: inout String.Index,
        processed: inout Int)
    {
        guard index < json.endIndex, processed < limit else { return }

        let ch = json[index]
        if ch == "\"" {
            advance(json: json, index: &index, processed: &processed)
            skipString(json: json, limit: limit, index: &index, processed: &processed)
            frame.afterColon = false
            frame.lastKey = nil
            return
        }
        if ch == "t" {
            if consumeLiteral(json: json, literal: "true", limit: limit, index: &index, processed: &processed) {
                frame.afterColon = false
                frame.lastKey = nil
            }
            return
        }
        if ch == "f" {
            if consumeLiteral(json: json, literal: "false", limit: limit, index: &index, processed: &processed) {
                frame.afterColon = false
                frame.lastKey = nil
            }
            return
        }
        if ch == "n" {
            if consumeLiteral(json: json, literal: "null", limit: limit, index: &index, processed: &processed) {
                frame.afterColon = false
                frame.lastKey = nil
            }
            return
        }
        if ch == "-" || ch.isNumber {
            while index < json.endIndex, processed < limit {
                let c = json[index]
                if c.isNumber || c == "." || c == "e" || c == "E" || c == "+" || c == "-" {
                    advance(json: json, index: &index, processed: &processed)
                } else {
                    break
                }
            }
            if processed < limit {
                frame.afterColon = false
                frame.lastKey = nil
            }
            return
        }
        advance(json: json, index: &index, processed: &processed)
        frame.afterColon = false
        frame.lastKey = nil
    }

    private func consumePrimitive(
        json: String,
        limit: Int,
        index: inout String.Index,
        processed: inout Int)
    {
        guard index < json.endIndex, processed < limit else { return }

        let ch = json[index]
        if ch == "t" {
            consumeLiteral(json: json, literal: "true", limit: limit, index: &index, processed: &processed)
            return
        }
        if ch == "f" {
            consumeLiteral(json: json, literal: "false", limit: limit, index: &index, processed: &processed)
            return
        }
        if ch == "n" {
            consumeLiteral(json: json, literal: "null", limit: limit, index: &index, processed: &processed)
            return
        }
        if ch == "-" || ch.isNumber {
            while index < json.endIndex, processed < limit {
                let c = json[index]
                if c.isNumber || c == "." || c == "e" || c == "E" || c == "+" || c == "-" {
                    advance(json: json, index: &index, processed: &processed)
                } else {
                    break
                }
            }
            return
        }
        advance(json: json, index: &index, processed: &processed)
    }

    // MARK: - Full sibling key collection

    /// Collects additional keys in the current object scope AFTER `cursorOffset`.
    /// Scans forward from the cursor, tracking brace/bracket depth. Keys at depth 0
    /// (same level) are collected. Stops when depth goes negative (exiting the object).
    public func collectKeysAfterCursor(json: String, cursorOffset: Int) -> Set<String> {
        let startIdx = json.index(json.startIndex, offsetBy: min(cursorOffset, json.count))
        guard startIdx < json.endIndex else { return [] }

        var keys: Set<String> = []
        var depth = 0
        var inString = false
        var escaped = false
        var isKey = false
        var afterColon = false
        var pendingKey = ""
        var i = startIdx

        while i < json.endIndex {
            let ch = json[i]
            i = json.index(after: i)

            if escaped {
                escaped = false
                if inString, isKey { pendingKey.append(ch) }
                continue
            }

            if ch == "\\" {
                if inString { escaped = true }
                continue
            }

            if ch == "\"" {
                if inString {
                    inString = false
                    if depth == 0, isKey {
                        keys.insert(pendingKey)
                    }
                    pendingKey = ""
                } else {
                    inString = true
                    isKey = depth == 0 && !afterColon
                    pendingKey = ""
                }
                continue
            }

            if inString {
                if isKey { pendingKey.append(ch) }
                continue
            }

            switch ch {
            case "{", "[":
                depth += 1

            case "}", "]":
                if depth == 0 { return keys }
                depth -= 1

            case ":":
                if depth == 0 { afterColon = true }

            case ",":
                if depth == 0 { afterColon = false }

            default:
                break
            }
        }

        return keys
    }

    // MARK: - Low-level helpers

    private func skipWhitespace(
        json: String,
        index: inout String.Index,
        processed: inout Int,
        limit: Int)
    {
        while index < json.endIndex, processed < limit, json[index].isWhitespace {
            index = json.index(after: index)
            processed += 1
        }
    }

    private func advance(json: String, index: inout String.Index, processed: inout Int) {
        index = json.index(after: index)
        processed += 1
    }

    private func skipString(
        json: String,
        limit: Int,
        index: inout String.Index,
        processed: inout Int)
    {
        var escape = false
        while index < json.endIndex, processed < limit {
            let c = json[index]
            advance(json: json, index: &index, processed: &processed)
            if escape { escape = false
                continue
            }
            if c == "\\" { escape = true
                continue
            }
            if c == "\"" { break }
        }
    }

    @discardableResult
    private func consumeLiteral(
        json: String,
        literal: String,
        limit: Int,
        index: inout String.Index,
        processed: inout Int)
        -> Bool
    {
        for expected in literal {
            guard index < json.endIndex, processed < limit else { return false }

            let c = json[index]
            advance(json: json, index: &index, processed: &processed)
            if c != expected { return false }
        }
        return true
    }
}
