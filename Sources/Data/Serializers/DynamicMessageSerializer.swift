import Foundation
import GRPCCore
import SwiftProtoReflect

/// Serializer that converts DynamicMessage to binary bytes for gRPC transport
/// Bridges SwiftProtoReflect to grpc-swift-2
public struct DynamicMessageSerializer: MessageSerializer {
    
    public init() {}
    
    public func serialize<Bytes: GRPCContiguousBytes>(_ message: DynamicMessage) throws -> Bytes {
        let binarySerializer = BinarySerializer()
        let data = try binarySerializer.serialize(message)
        return Bytes(data)
    }
}
