import Foundation

/// A JSON token that can be painted without treating the document as valid.
enum JsonSyntaxKind: Equatable, Sendable {
    case key
    case string
    case number
    case literal
    case punctuation
}

/// One colored range, measured in UTF-16 so it lines up with `NSTextView`.
struct JsonSyntaxSpan: Equatable, Sendable {
    let startUTF16: Int
    let endUTF16: Int
    let kind: JsonSyntaxKind
}

/// Best-effort JSON lexer. An unclosed string keeps its color through the end of the text.
struct JsonSyntaxHighlighter: Sendable {
    func spans(in text: String) -> [JsonSyntaxSpan] {
        var scanner = Scanner(text: text)
        return scanner.scan()
    }

    private struct Scanner {
        private let text: String
        private var index: String.Index
        private var utf16 = 0
        private var spans: [JsonSyntaxSpan] = []
        private var containers: [Container] = []
        private var expectation: Expectation = .value

        private enum Container {
            case object
            case array
        }

        private enum Expectation {
            case value
            case key
            case colon
            case commaOrEnd
        }

        init(text: String) {
            self.text = text
            self.index = text.startIndex
        }

        mutating func scan() -> [JsonSyntaxSpan] {
            while !isAtEnd {
                skipWhitespace()
                guard !isAtEnd else { break }

                switch text[index] {
                case "{":
                    emitPunctuation()
                    containers.append(.object)
                    expectation = .key

                case "}":
                    emitPunctuation()
                    if containers.last == .object {
                        containers.removeLast()
                    }
                    expectation = .commaOrEnd

                case "[":
                    emitPunctuation()
                    containers.append(.array)
                    expectation = .value

                case "]":
                    emitPunctuation()
                    if containers.last == .array {
                        containers.removeLast()
                    }
                    expectation = .commaOrEnd

                case ":", ",":
                    let isComma = text[index] == ","
                    emitPunctuation()
                    if isComma {
                        expectation = containers.last == .object ? .key : .value
                    } else {
                        expectation = .value
                    }

                case "\"":
                    if !scanString() {
                        return spans
                    }

                default:
                    if scanNumber() || scanLiteral() {
                        expectation = .commaOrEnd
                    } else {
                        advance()
                    }
                }
            }
            return spans
        }

        private var isAtEnd: Bool {
            index == text.endIndex
        }

        private var peek: Character? {
            isAtEnd ? nil : text[index]
        }

        private var peekIsDigit: Bool {
            guard let peek, peek.isASCII, peek.isNumber else { return false }

            return true
        }

        private mutating func advance() {
            guard !isAtEnd else { return }

            let character = text[index]
            index = text.index(after: index)
            utf16 += character.utf16.count
        }

        private mutating func skipWhitespace() {
            while let peek, peek.isWhitespace {
                advance()
            }
        }

        private mutating func emitPunctuation() {
            let start = utf16
            advance()
            spans.append(JsonSyntaxSpan(startUTF16: start, endUTF16: utf16, kind: .punctuation))
        }

        /// Returns whether the string found its closing quote.
        private mutating func scanString() -> Bool {
            let start = utf16
            advance()
            var closed = false
            while !isAtEnd {
                let character = text[index]
                if character == "\\" {
                    advance()
                    if !isAtEnd {
                        advance()
                    }
                    continue
                }
                if character == "\"" {
                    advance()
                    closed = true
                    break
                }
                advance()
            }
            let kind: JsonSyntaxKind = expectation == .key ? .key : .string
            spans.append(JsonSyntaxSpan(startUTF16: start, endUTF16: utf16, kind: kind))
            if closed {
                expectation = kind == .key ? .colon : .commaOrEnd
            }
            return closed
        }

        private mutating func scanNumber() -> Bool {
            let savedIndex = index
            let savedUTF16 = utf16
            if peek == "-" {
                advance()
            }
            guard peekIsDigit else {
                index = savedIndex
                utf16 = savedUTF16
                return false
            }

            while peekIsDigit {
                advance()
            }
            if peek == "." {
                let beforeDot = index
                let beforeDotUTF16 = utf16
                advance()
                if peekIsDigit {
                    while peekIsDigit {
                        advance()
                    }
                } else if !isAtEnd {
                    index = beforeDot
                    utf16 = beforeDotUTF16
                }
            }
            if peek == "e" || peek == "E" {
                let beforeExponent = index
                let beforeExponentUTF16 = utf16
                advance()
                if peek == "+" || peek == "-" {
                    advance()
                }
                if peekIsDigit {
                    while peekIsDigit {
                        advance()
                    }
                } else if !isAtEnd {
                    index = beforeExponent
                    utf16 = beforeExponentUTF16
                }
            }
            spans.append(JsonSyntaxSpan(startUTF16: savedUTF16, endUTF16: utf16, kind: .number))
            return true
        }

        private mutating func scanLiteral() -> Bool {
            let startIndex = index
            let startUTF16 = utf16
            for word in ["true", "false", "null"] {
                if consumeWord(word) {
                    spans.append(JsonSyntaxSpan(startUTF16: startUTF16, endUTF16: utf16, kind: .literal))
                    return true
                }
                index = startIndex
                utf16 = startUTF16
            }
            return false
        }

        private mutating func consumeWord(_ word: String) -> Bool {
            var cursor = index
            var extraUTF16 = 0
            for character in word {
                guard cursor < text.endIndex, text[cursor] == character else { return false }

                extraUTF16 += character.utf16.count
                cursor = text.index(after: cursor)
            }
            if cursor < text.endIndex {
                let next = text[cursor]
                if next.isLetter || next.isNumber || next == "_" {
                    return false
                }
            }
            index = cursor
            utf16 += extraUTF16
            return true
        }
    }
}
