import Foundation

/// Use case for creating editor tabs for gRPC methods
/// Simple transformation of method metadata into an EditorTab entity
public final class CreateEditorTabUseCase {
    public init() {}
    
    /// Executes the creation of an editor tab
    /// - Parameters:
    ///   - method: The gRPC method to create a tab for
    ///   - service: The service containing the method
    ///   - protoFile: The proto file containing the service
    /// - Returns: A new EditorTab configured for the method
    public func execute(method: Method, service: Service, protoFile: ProtoFile) -> EditorTab {
        return EditorTab(
            methodName: method.name,
            serviceName: service.name,
            protoFile: protoFile,
            method: method
        )
    }
}
