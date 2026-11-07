import Foundation

/// Detects JSON that still keeps several values on one line, and maps a caret across a pretty-print.
/// Key order is preserved. The Format action sorts keys separately via `JsonFormatterProtocol`.
public enum JsonInlineDocument {
    /// `true` when a non-empty container opens and closes on the same line, or a comma is followed
    /// by more tokens on that line. Empty `{}` and `[]` are not inline.
    public static func isInline(_ json: String) -> Bool {
        let ns = json as NSString
        var stack: [Frame] = []
        var line = 0
        var inString = false
        var escaped = false
        var index = 0

        while index < ns.length {
            let character = ns.character(at: index)
            if inString {
                if escaped {
                    escaped = false
                } else if character == JsonScanUTF16.backslash {
                    escaped = true
                } else if character == JsonScanUTF16.quote {
                    inString = false
                }
                markContent(&stack)
                index += 1
                continue
            }

            if character == JsonScanUTF16.quote {
                inString = true
                markContent(&stack)
                index += 1
                continue
            }
            if character == JsonScanUTF16.lf || character == JsonScanUTF16.cr {
                line += 1
                index += 1
                continue
            }
            if isHorizontalSpace(character) {
                index += 1
                continue
            }
            if character == JsonScanUTF16.braceOpen || character == JsonScanUTF16.bracketOpen {
                markContent(&stack)
                stack.append(Frame(line: line))
                index += 1
                continue
            }
            if character == JsonScanUTF16.braceClose || character == JsonScanUTF16.bracketClose {
                if let frame = stack.popLast(), frame.line == line, frame.hasContent {
                    return true
                }
                index += 1
                continue
            }
            if character == JsonScanUTF16.comma, lineContinues(in: ns, after: index) {
                return true
            }
            markContent(&stack)
            index += 1
        }
        return false
    }

    /// Pretty-prints `json` when it is inline. Key order is preserved so the caret can stay in the same value.
    /// `format` is used only to reject invalid JSON.
    public static func pretty(_ json: String, using format: (String) throws -> String) -> String? {
        guard isInline(json) else { return nil }
        guard (try? format(json)) != nil else { return nil }

        let formatted = reindent(json)
        guard formatted != json, !isInline(formatted) else { return nil }

        return formatted
    }

    /// Inline valid JSON expanded for display. Already pretty, empty, and invalid text is returned unchanged.
    public static func expanded(_ json: String) -> String {
        pretty(json) { candidate in
            guard let data = candidate.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil
            else { throw JsonFormatterError.invalidJSON(candidate) }

            return candidate
        } ?? json
    }

    /// Caret offset in `formatted` that corresponds to `cursorUTF16` in `original`.
    /// Whitespace outside strings is ignored, so indentation inserted by pretty-print does not move the caret.
    public static func cursor(in formatted: String, matching original: String, cursorUTF16: Int) -> Int {
        let count = significantCount(in: original, upTo: cursorUTF16)
        return index(in: formatted, afterSignificantCount: count)
    }

    private struct Frame {
        var line: Int
        var hasContent = false
    }

    private static func markContent(_ stack: inout [Frame]) {
        guard !stack.isEmpty else { return }

        stack[stack.count - 1].hasContent = true
    }

    private static func lineContinues(in text: NSString, after comma: Int) -> Bool {
        var index = comma + 1
        while index < text.length {
            let character = text.character(at: index)
            if character == JsonScanUTF16.lf || character == JsonScanUTF16.cr {
                return false
            }
            if !isHorizontalSpace(character) {
                return true
            }
            index += 1
        }
        return false
    }

    private static func significantCount(in text: String, upTo utf16: Int) -> Int {
        let ns = text as NSString
        let end = min(max(0, utf16), ns.length)
        var count = 0
        var inString = false
        var escaped = false
        var index = 0
        while index < end {
            let character = ns.character(at: index)
            if inString {
                count += 1
                if escaped {
                    escaped = false
                } else if character == JsonScanUTF16.backslash {
                    escaped = true
                } else if character == JsonScanUTF16.quote {
                    inString = false
                }
            } else if character == JsonScanUTF16.quote {
                inString = true
                count += 1
            } else if !isWhitespace(character) {
                count += 1
            }
            index += 1
        }
        return count
    }

    private static func index(in text: String, afterSignificantCount count: Int) -> Int {
        let ns = text as NSString
        var seen = 0
        var inString = false
        var escaped = false
        var index = 0
        while index < ns.length, seen < count {
            let character = ns.character(at: index)
            if inString {
                seen += 1
                if escaped {
                    escaped = false
                } else if character == JsonScanUTF16.backslash {
                    escaped = true
                } else if character == JsonScanUTF16.quote {
                    inString = false
                }
            } else if character == JsonScanUTF16.quote {
                inString = true
                seen += 1
            } else if !isWhitespace(character) {
                seen += 1
            }
            index += 1
        }
        return index
    }

    /// Inserts newlines and indentation without reordering keys or rewriting string contents.
    private static func reindent(_ json: String) -> String {
        let characters = Array(json)
        var result = ""
        var indent = 0
        var inString = false
        var escaped = false
        var index = 0

        func appendIndent() {
            result.append(String(repeating: " ", count: indent * 2))
        }

        func nextSignificant(after index: Int) -> Character? {
            var cursor = index + 1
            while cursor < characters.count, characters[cursor].isWhitespace {
                cursor += 1
            }
            return cursor < characters.count ? characters[cursor] : nil
        }

        while index < characters.count {
            let character = characters[index]
            if inString {
                result.append(character)
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                index += 1
                continue
            }
            if character.isWhitespace {
                index += 1
                continue
            }
            if character == "\"" {
                inString = true
                result.append(character)
                index += 1
                continue
            }
            if character == "{" || character == "[" {
                let closing: Character = character == "{" ? "}" : "]"
                if nextSignificant(after: index) == closing {
                    result.append(character)
                    result.append(closing)
                    index += 1
                    while index < characters.count, characters[index] != closing {
                        index += 1
                    }
                    index += 1
                    continue
                }
                result.append(character)
                indent += 1
                result.append("\n")
                appendIndent()
                index += 1
                continue
            }
            if character == "}" || character == "]" {
                indent = max(0, indent - 1)
                result.append("\n")
                appendIndent()
                result.append(character)
                index += 1
                continue
            }
            if character == "," {
                result.append(",\n")
                appendIndent()
                index += 1
                continue
            }
            if character == ":" {
                result.append(" : ")
                index += 1
                continue
            }
            result.append(character)
            index += 1
        }
        return result
    }

    private static func isHorizontalSpace(_ character: UInt16) -> Bool {
        character == JsonScanUTF16.space || character == JsonScanUTF16.tab
    }

    private static func isWhitespace(_ character: UInt16) -> Bool {
        isHorizontalSpace(character) || character == JsonScanUTF16.lf || character == JsonScanUTF16.cr
    }
}
