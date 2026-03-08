import Foundation
import GRPCCore
import SwiftProtoReflect

/// Deserializer that converts binary bytes to DynamicMessage from gRPC transport
/// Bridges grpc-swift-2 to SwiftProtoReflect
public struct DynamicMessageDeserializer: MessageDeserializer {
    public let messageDescriptor: MessageDescriptor

    public init(messageDescriptor: MessageDescriptor) {
        self.messageDescriptor = messageDescriptor
    }

    public func deserialize(_ bytes: some GRPCContiguousBytes) throws -> DynamicMessage {
        let data = bytes.withUnsafeBytes { Data($0) }
        let binaryDeserializer = BinaryDeserializer()
        return try binaryDeserializer.deserialize(data, using: messageDescriptor)
    }
}
