import Foundation
import GRPCCore

/// Deserializer that passes through binary bytes from gRPC transport as raw Data.
/// The actual dynamic-message deserialization happens asynchronously in the gRPC response
/// handler via `BinaryDeserializer`, which became async in SwiftProtoReflect 6.0.0.
public struct DynamicMessageDeserializer: MessageDeserializer {
    public init() {}

    public func deserialize(_ bytes: some GRPCContiguousBytes) throws -> Data {
        bytes.withUnsafeBytes { Data($0) }
    }
}
