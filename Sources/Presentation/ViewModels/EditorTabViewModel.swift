import Foundation
import SwiftUI

/// ViewModel for managing request editor tab state
@MainActor
public final class EditorTabViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var requestJson: String = ""
    @Published public var url: String = ""
    @Published public var isLoading: Bool = false
    @Published public var response: GrpcResponse?
    @Published public var error: String?
    @Published public var isExecuting: Bool = false
    
    // MARK: - Properties
    
    public let editorTab: EditorTab
    
    // MARK: - Dependencies
    
    private let generateMockDataUseCase: GenerateMockDataUseCase
    private let executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol
    
    // MARK: - Initialization
    
    public init(
        editorTab: EditorTab,
        generateMockDataUseCase: GenerateMockDataUseCase,
        executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol
    ) {
        self.editorTab = editorTab
        self.generateMockDataUseCase = generateMockDataUseCase
        self.executeRequestUseCase = executeRequestUseCase
    }
    
    // MARK: - Public Methods
    
    /// Loads mock data for the method's input type
    public func loadMockData() async {
        isLoading = true
        
        do {
            let mockJson = try await generateMockDataUseCase.execute(method: editorTab.method)
            requestJson = mockJson
        } catch {
            // Silently fail for MVP - just leave empty JSON
            print("DEBUG: Failed to generate mock data: \(error)")
        }
        
        isLoading = false
    }
    
    /// Updates the request JSON
    public func updateJson(_ newJson: String) {
        requestJson = newJson
    }
    
    /// Updates the server URL
    public func updateUrl(_ newUrl: String) {
        url = newUrl
    }
    
    /// Executes the gRPC request
    public func executeRequest() async {
        // Clear previous state
        response = nil
        error = nil
        isExecuting = true
        
        do {
            // Create request draft
            let requestDraft = RequestDraft(
                jsonBody: requestJson,
                url: url,
                method: editorTab.method
            )
            
            // Execute request
            let grpcResponse = try await executeRequestUseCase.execute(
                request: requestDraft,
                method: editorTab.method
            )
            
            // Update state with response
            response = grpcResponse
        } catch let grpcError as GrpcClientError {
            // Handle gRPC-specific errors
            error = formatError(grpcError)
        } catch let otherError {
            // Handle other errors
            error = "Request failed: \(otherError.localizedDescription)"
        }
        
        isExecuting = false
    }
    
    // MARK: - Private Methods
    
    /// Format gRPC error for display
    private func formatError(_ error: GrpcClientError) -> String {
        switch error {
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Request timeout"
        case .unavailable:
            return "Service unavailable"
        case .invalidResponse:
            return "Invalid response from server"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}
