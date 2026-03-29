import Foundation

/// Formats a JSON string to 2-space pretty-printed form.
/// Normalises Unicode smart quotes to `"` before parsing.
final class JsonFormatter: JsonFormatterProtocol, Sendable {
    func format(_ json: String) throws -> String {
        guard !json.isEmpty else { return "" }

        let normalised = json
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")

        guard let data = normalised.data(using: .utf8) else {
            throw JsonFormatterError.invalidJSON(json)
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw JsonFormatterError.invalidJSON(error.localizedDescription)
        }

        let prettyData: Data
        do {
            prettyData = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys])
        } catch {
            throw JsonFormatterError.invalidJSON(error.localizedDescription)
        }

        guard var result = String(data: prettyData, encoding: .utf8) else {
            throw JsonFormatterError.invalidJSON(json)
        }

        // Foundation emits "{\n\n}" / "[\n\n]" for empty containers; collapse them.
        result = result
            .replacingOccurrences(of: "{\n\n}", with: "{}")
            .replacingOccurrences(of: "[\n\n]", with: "[]")
        return result
    }
}
