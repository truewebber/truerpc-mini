import Foundation

/// Resolves JSON edit position to a field path and autocomplete mode by scanning only before `cursorOffset`.
public final class JsonPathResolver: Sendable {
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
        var escapeNext = false
        var popsPathOnClose = false
    }

    private struct ArrayFrame {
        var popsPathOnClose = false
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
        case .array:
            return AutocompleteContext(resolvedPath: path, mode: .arrayElement)
        case let .object(frame):
            if frame.inString {
                let mode: AutocompleteMode = frame.stringIsKey ? .key : .enumValue
                return AutocompleteContext(resolvedPath: path, mode: mode)
            }
            if frame.afterColon {
                return AutocompleteContext(resolvedPath: path, mode: .enumValue)
            }
            return AutocompleteContext(resolvedPath: path, mode: .key)
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
                return true
            }
            if ch == "\\" {
                frame.escapeNext = true
                return true
            }
            if ch == "\"" {
                frame.inString = false
                if frame.stringIsKey { frame.lastKey = frame.pendingKey }
                frame.pendingKey = ""
                return true
            }
            if frame.stringIsKey { frame.pendingKey.append(ch) }
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
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == ":" {
            frame.afterColon = true
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == "\"" {
            frame.inString = true
            frame.stringIsKey = !frame.afterColon
            frame.pendingKey = ""
            frame.escapeNext = false
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
            advance(json: json, index: &index, processed: &processed)
            return true
        }
        if ch == "{" {
            stack.append(.object(ObjectFrame()))
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "[" {
            stack.append(.array(ArrayFrame()))
            advance(json: json, index: &index, processed: &processed)
            return false
        }
        if ch == "\"" {
            advance(json: json, index: &index, processed: &processed)
            skipString(json: json, limit: limit, index: &index, processed: &processed)
            return true
        }
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
