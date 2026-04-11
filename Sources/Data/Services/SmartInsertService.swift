import Foundation

/// UTF-16 code-unit constants for JSON structural ASCII characters used by
/// `SmartInsertService` and `JSONTextEditor.Coordinator`.
enum JsonScanUTF16 {
    static let quote: UInt16 = 0x22
    static let backslash: UInt16 = 0x5C
    static let bracketOpen: UInt16 = 0x5B
    static let bracketClose: UInt16 = 0x5D
    static let braceOpen: UInt16 = 0x7B
    static let braceClose: UInt16 = 0x7D
    static let space: UInt16 = 0x20
    static let lf: UInt16 = 0x0A
    static let cr: UInt16 = 0x0D
    static let tab: UInt16 = 0x09
    static let comma: UInt16 = 0x2C
    static let colon: UInt16 = 0x3A
}

/// Pure-algorithm service for JSON text smart-insertion.
/// All methods are stateless; the struct is trivially `Sendable`.
struct SmartInsertService {
    // MARK: - Snippet generation

    /// Returns the snippet text and the number of UTF-16 code units to step the cursor
    /// back after insertion (for placing the cursor inside quotes/braces).
    ///
    /// For `.message` suggestions, `lineIndent` is used to produce a properly-indented
    /// opening block: inner content at `lineIndent + "  "`, closing brace at `lineIndent`.
    func smartInsertComponents(
        for suggestion: AutocompleteSuggestion,
        lineIndent: String = "")
        -> (text: String, cursorBack: Int)
    {
        let name = suggestion.name
        switch suggestion.kind {
        case .string, .wktString:
            return ("\"\(name)\": \"\"", 1)

        case .number, .bool, .enumField:
            return ("\"\(name)\": ", 0)

        case .message:
            let innerIndent = lineIndent + "  "
            return ("\"\(name)\": {\n\(innerIndent)\n\(lineIndent)}", lineIndent.count + 2)

        case .enum:
            return ("\"\(name)\"", 0)

        case .wktDefault:
            let value = suggestion.insertValue ?? name
            return ("\"\(value)\"", 0)

        case .repeated:
            return ("\"\(name)\": []", 1)

        case .fillDefaults:
            return ("", 0)
        }
    }

    // MARK: - Brace / bracket balance

    /// Counts `{` minus `}` outside of JSON string literals.
    func unclosedBraceCount(in text: String) -> Int {
        var balance = 0
        var inString = false
        var escaped = false

        for char in text {
            if escaped { escaped = false
                continue
            }
            if char == "\\", inString { escaped = true
                continue
            }
            if char == "\"" { inString.toggle()
                continue
            }
            guard !inString else { continue }

            if char == "{" { balance += 1 }
            else if char == "}" { balance -= 1 }
        }

        return max(0, balance)
    }

    /// Counts `[` minus `]` outside of JSON string literals in `ns[0..<endUTF16]`.
    func arrayBracketBalanceInPrefix(ns: NSString, endUTF16: Int) -> Int {
        var balance = 0
        var inString = false
        var escaped = false
        let length = min(endUTF16, ns.length)
        var i = 0
        while i < length {
            let c = ns.character(at: i)
            if escaped {
                escaped = false
                i += 1
                continue
            }
            if inString {
                if c == JsonScanUTF16.backslash { escaped = true }
                else if c == JsonScanUTF16.quote { inString = false }
                i += 1
                continue
            }
            if c == JsonScanUTF16.quote {
                inString = true
                i += 1
                continue
            }
            if c == JsonScanUTF16.bracketOpen { balance += 1 }
            else if c == JsonScanUTF16.bracketClose { balance -= 1 }
            i += 1
        }
        return balance
    }

    /// Counts `{` minus `}` in `[fromUTF16, toUTF16)` outside of string literals.
    func netBraceCountInUTF16Range(ns: NSString, fromUTF16: Int, toUTF16: Int) -> Int {
        var balance = 0
        var inString = false
        var escaped = false
        var i = fromUTF16
        let end = min(toUTF16, ns.length)
        while i < end {
            let c = ns.character(at: i)
            if escaped {
                escaped = false
                i += 1
                continue
            }
            if inString {
                if c == JsonScanUTF16.backslash { escaped = true }
                else if c == JsonScanUTF16.quote { inString = false }
                i += 1
                continue
            }
            if c == JsonScanUTF16.quote {
                inString = true
                i += 1
                continue
            }
            if c == JsonScanUTF16.braceOpen { balance += 1 }
            else if c == JsonScanUTF16.braceClose { balance -= 1 }
            i += 1
        }
        return max(0, balance)
    }

    // MARK: - Index navigation

    /// First non-whitespace UTF-16 index at/after `fromUTF16`, or `nil` if EOF.
    func nextSignificantUTF16IndexAndScalar(
        ns: NSString,
        fromUTF16: Int)
        -> (index: Int, scalar: UInt16)?
    {
        var i = fromUTF16
        while i < ns.length {
            let c = ns.character(at: i)
            if c == JsonScanUTF16.space || c == JsonScanUTF16.lf
                || c == JsonScanUTF16.cr || c == JsonScanUTF16.tab
            {
                i += 1
                continue
            }
            return (i, c)
        }
        return nil
    }

    /// The `]` that closes the innermost array still open at `fromUTF16` (skips strings).
    func indexOfClosingBracketForContainingArray(ns: NSString, fromUTF16: Int) -> Int? {
        var pending = arrayBracketBalanceInPrefix(ns: ns, endUTF16: fromUTF16)
        guard pending > 0 else { return nil }

        var inString = false
        var escaped = false
        var i = fromUTF16
        let length = ns.length
        while i < length {
            let c = ns.character(at: i)
            if escaped {
                escaped = false
                i += 1
                continue
            }
            if inString {
                if c == JsonScanUTF16.backslash { escaped = true }
                else if c == JsonScanUTF16.quote { inString = false }
                i += 1
                continue
            }
            if c == JsonScanUTF16.quote {
                inString = true
                i += 1
                continue
            }
            if c == JsonScanUTF16.bracketOpen {
                pending += 1
            } else if c == JsonScanUTF16.bracketClose {
                pending -= 1
                if pending == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// Matching `[` index for `]` at `closingBracketUTF16` (prefix `0..<closing`).
    func indexOfMatchingOpenBracket(ns: NSString, closingBracketUTF16: Int) -> Int? {
        var stack: [Int] = []
        var inString = false
        var escaped = false
        var i = 0
        while i < closingBracketUTF16 {
            let c = ns.character(at: i)
            if escaped {
                escaped = false
                i += 1
                continue
            }
            if inString {
                if c == JsonScanUTF16.backslash { escaped = true }
                else if c == JsonScanUTF16.quote { inString = false }
                i += 1
                continue
            }
            if c == JsonScanUTF16.quote {
                inString = true
                i += 1
                continue
            }
            if c == JsonScanUTF16.bracketOpen {
                stack.append(i)
            } else if c == JsonScanUTF16.bracketClose {
                _ = stack.popLast()
            }
            i += 1
        }
        return stack.last
    }

    // MARK: - Partial key detection

    /// Scans backwards from `cursorOffset` to find the start of bare (unquoted) text
    /// the user has typed in key position (e.g. `{dfdf` → index of `d`).
    /// Returns `nil` when only whitespace or a structural character precedes the cursor.
    func findBareTextStart(in ns: NSString, cursorOffset: Int) -> Int? {
        var i = cursorOffset - 1
        var firstNonWhitespace = -1
        while i >= 0 {
            let ch = ns.character(at: i)
            if ch == JsonScanUTF16.braceOpen || ch == JsonScanUTF16.braceClose
                || ch == JsonScanUTF16.bracketOpen || ch == JsonScanUTF16.bracketClose
                || ch == JsonScanUTF16.comma || ch == JsonScanUTF16.colon
                || ch == JsonScanUTF16.quote
            {
                return firstNonWhitespace >= 0 ? firstNonWhitespace : nil
            }
            if ch != JsonScanUTF16.space, ch != JsonScanUTF16.lf,
               ch != JsonScanUTF16.cr, ch != JsonScanUTF16.tab
            {
                firstNonWhitespace = i
            }
            i -= 1
        }
        return firstNonWhitespace >= 0 ? firstNonWhitespace : nil
    }

    /// Scans backwards from `cursorOffset` to find the UTF-16 offset of the opening `"`
    /// of an unclosed string literal the cursor is currently inside.
    /// Returns `nil` when the cursor is not inside a string.
    func findPartialStringStart(in ns: NSString, cursorOffset: Int) -> Int? {
        var i = cursorOffset - 1
        while i >= 0 {
            let ch = ns.character(at: i)
            if ch == JsonScanUTF16.quote {
                var backslashCount = 0
                var bs = i - 1
                while bs >= 0, ns.character(at: bs) == JsonScanUTF16.backslash {
                    backslashCount += 1
                    bs -= 1
                }
                guard backslashCount % 2 == 0 else {
                    i -= 1
                    continue
                }

                // Even unescaped-quote count before this position → opening quote.
                if countUnescapedQuotes(in: ns, upTo: i) % 2 == 0 {
                    return i
                }
                return nil
            }
            if ch == JsonScanUTF16.braceOpen || ch == JsonScanUTF16.braceClose
                || ch == JsonScanUTF16.bracketOpen || ch == JsonScanUTF16.bracketClose
                || ch == JsonScanUTF16.comma || ch == JsonScanUTF16.colon
            {
                return nil
            }
            i -= 1
        }
        return nil
    }

    // MARK: - Value-string replacement range

    /// When a value-type suggestion (enum value, WKT default) is committed while the cursor
    /// sits inside an existing quoted value such as `"field": "█"` or `"field": "partial█"`,
    /// returns the `NSRange` that covers the full quoted token `"..."` (both the opening and
    /// closing `"` inclusive) so the caller can replace it wholesale.
    ///
    /// Returns `nil` when the cursor is **not** inside a quoted value literal — e.g. when
    /// it is positioned after `: ` with no surrounding quotes, indicating a fresh insertion.
    func valueStringRange(in ns: NSString, cursorOffset: Int) -> NSRange? {
        // Scan backward from the cursor to find the opening `"` of the value literal.
        // Stop early on any structural character that cannot appear inside a string value.
        var openQ: Int?
        var j = cursorOffset - 1
        while j >= 0 {
            let c = ns.character(at: j)
            if c == JsonScanUTF16.quote { openQ = j
                break
            }
            if c == JsonScanUTF16.colon || c == JsonScanUTF16.comma
                || c == JsonScanUTF16.braceOpen || c == JsonScanUTF16.braceClose
                || c == JsonScanUTF16.bracketOpen || c == JsonScanUTF16.bracketClose
            { return nil }
            j -= 1
        }
        guard let open = openQ else { return nil }

        // Scan forward from the cursor to find the closing `"` of the value literal.
        var closeQ: Int?
        var k = cursorOffset
        while k < ns.length {
            let c = ns.character(at: k)
            if c == JsonScanUTF16.quote { closeQ = k
                break
            }
            if c == JsonScanUTF16.comma
                || c == JsonScanUTF16.braceClose
                || c == JsonScanUTF16.bracketClose
            { break }
            k += 1
        }

        if let close = closeQ {
            return NSRange(location: open, length: close - open + 1)
        }
        // No closing quote found — cursor is after the opening `"` of an unclosed string.
        // Replace from the opening quote to the cursor only.
        return NSRange(location: open, length: cursorOffset - open)
    }

    // MARK: - String-literal context

    /// Returns `true` when `utf16Offset` falls inside an open string literal in `ns`.
    /// Scans from position 0 tracking escape sequences and quote pairs.
    func isInsideStringLiteral(in ns: NSString, at utf16Offset: Int) -> Bool {
        var inString = false
        var escaped = false
        let length = min(utf16Offset, ns.length)
        var i = 0
        while i < length {
            let c = ns.character(at: i)
            if escaped {
                escaped = false
                i += 1
                continue
            }
            if inString {
                if c == JsonScanUTF16.backslash { escaped = true }
                else if c == JsonScanUTF16.quote { inString = false }
                i += 1
                continue
            }
            if c == JsonScanUTF16.quote { inString = true }
            i += 1
        }
        return inString
    }

    /// Returns the leading whitespace (spaces and tabs) of the line that contains
    /// `utf16Offset`. Scans backwards to find the preceding LF (or start of text),
    /// then collects consecutive space/tab characters from the start of that line.
    func lineIndentation(in ns: NSString, at utf16Offset: Int) -> String {
        var lineStart = 0
        var i = utf16Offset - 1
        while i >= 0 {
            if ns.character(at: i) == JsonScanUTF16.lf {
                lineStart = i + 1
                break
            }
            i -= 1
        }

        var indentation = ""
        var j = lineStart
        while j < ns.length {
            let c = ns.character(at: j)
            if c == JsonScanUTF16.space {
                indentation += " "
            } else if c == JsonScanUTF16.tab {
                indentation += "\t"
            } else {
                break
            }
            j += 1
        }
        return indentation
    }

    // MARK: - Indented closing suffix

    /// Generates a suffix of `count` closing braces, each on its own line.
    /// Indentation decreases by 2 spaces per level starting from `baseIndent`.
    /// Returns an empty string when `count == 0`.
    func indentedClosingSuffix(count: Int, baseIndent: String) -> String {
        guard count > 0 else { return "" }

        var result = ""
        var currentIndent = baseIndent
        for _ in 0 ..< count {
            result += "\n\(currentIndent)}"
            if currentIndent.count >= 2 {
                currentIndent = String(currentIndent.dropLast(2))
            } else {
                currentIndent = ""
            }
        }
        return result
    }

    // MARK: - Private helpers

    private func countUnescapedQuotes(in ns: NSString, upTo limit: Int) -> Int {
        var count = 0
        var escaped = false
        var i = 0
        while i < limit, i < ns.length {
            let c = ns.character(at: i)
            if escaped {
                escaped = false
            } else if c == JsonScanUTF16.backslash {
                escaped = true
            } else if c == JsonScanUTF16.quote {
                count += 1
            }
            i += 1
        }
        return count
    }
}
