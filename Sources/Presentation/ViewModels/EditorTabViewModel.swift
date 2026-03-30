import AppKit
import Foundation
import SwiftUI

/// ViewModel for managing request editor tab state
@MainActor
public final class EditorTabViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var requestJson: String = ""
    @Published public var url: String = ""
    @Published public var metadataJson: String = "{}"
    @Published public var isMetadataVisible: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var response: GrpcResponse?
    @Published public var error: String?
    @Published public var isExecuting: Bool = false
    @Published public var tabEnvironment: ServerEnvironment?
    @Published public var availableEnvironments: [ServerEnvironment]
    @Published public var requestJsonFormatError: String? = nil
    @Published public var metadataFormatError: String? = nil

    // MARK: - Properties

    public let editorTab: EditorTab
    public let connectionSecurity: ConnectionSecurityViewModel
    public let autocompleteViewModel: AutocompleteViewModel

    // MARK: - Dependencies

    private let generateMockDataUseCase: GenerateMockDataUseCaseProtocol
    private let executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol
    public let exportResponseUseCase: ExportResponseUseCaseProtocol
    private let formatter: JsonFormatterProtocol
    private let logger: AppLogger

    // MARK: - Initialization

    public init(
        editorTab: EditorTab,
        initialEnvironment: ServerEnvironment? = nil,
        customUrl: String? = nil,
        restoredTabState: EditorTabState? = nil,
        availableEnvironments: [ServerEnvironment] = [],
        generateMockDataUseCase: GenerateMockDataUseCaseProtocol,
        executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol,
        exportResponseUseCase: ExportResponseUseCaseProtocol,
        formatter: JsonFormatterProtocol,
        autocompleteProvider: AutocompleteProviderProtocol,
        resolver: any JsonPathResolverProtocol,
        logger: AppLogger)
    {
        self.editorTab = editorTab
        self.tabEnvironment = initialEnvironment
        self.availableEnvironments = availableEnvironments
        self.url = initialEnvironment?.url ?? customUrl ?? ""
        self.generateMockDataUseCase = generateMockDataUseCase
        self.executeRequestUseCase = executeRequestUseCase
        self.exportResponseUseCase = exportResponseUseCase
        self.formatter = formatter
        let acVM = AutocompleteViewModel(
            provider: autocompleteProvider,
            resolver: resolver,
            methodInputType: editorTab.method.inputType)
        self.autocompleteViewModel = acVM
        self.logger = logger

        let security = ConnectionSecurityViewModel()
        security.update(
            activeEnvironment: initialEnvironment,
            restoredAdHocConfig: restoredTabState?.adHocTLSConfiguration)
        self.connectionSecurity = security

        acVM.fillDefaultsHandler = { [weak self] in await self?.resetToPreset() }
    }

    // MARK: - Computed Properties

    /// A snapshot of the current tab state for persistence.
    public var currentTabState: EditorTabState {
        EditorTabState(
            id: editorTab.id,
            protoFilePath: editorTab.protoFile.path.path,
            serviceName: editorTab.serviceName,
            methodName: editorTab.methodName,
            selectedEnvironmentId: tabEnvironment?.id,
            customUrl: tabEnvironment == nil ? (url.isEmpty ? nil : url) : nil,
            adHocTLSConfiguration: tabEnvironment == nil ? connectionSecurity.adHocConfig : nil)
    }

    // MARK: - Public Methods

    /// Loads mock data for the method's input type
    public func loadMockData() async {
        isLoading = true

        do {
            let mockJson = try await generateMockDataUseCase.execute(
                method: editorTab.method,
                protoFile: editorTab.protoFile)
            if let pretty = try? formatter.format(mockJson) {
                requestJson = pretty
            } else {
                requestJson = mockJson
            }
        } catch {
            logger.error("Mock data generation failed", metadata: [
                "method": "\(editorTab.method.name)",
                "inputType": "\(editorTab.method.inputType)",
                "error": "\(error)",
            ])
        }

        isLoading = false
    }

    /// Formats `requestJson` using the injected formatter.
    /// On success, replaces `requestJson` and clears `requestJsonFormatError`.
    /// On failure, sets `requestJsonFormatError` and leaves `requestJson` unchanged.
    public func formatRequestJson() {
        do {
            let formatted = try formatter.format(requestJson)
            requestJson = formatted
            requestJsonFormatError = nil
        } catch {
            requestJsonFormatError = "Invalid JSON"
        }
    }

    /// Formats `metadataJson` using the injected formatter.
    /// On success, replaces `metadataJson` and clears `metadataFormatError`.
    /// On failure, sets `metadataFormatError` and leaves `metadataJson` unchanged.
    public func formatMetadata() {
        do {
            let formatted = try formatter.format(metadataJson)
            metadataJson = formatted
            metadataFormatError = nil
        } catch {
            metadataFormatError = "Invalid JSON"
        }
    }

    /// Regenerates `requestJson` from the proto schema — semantic alias for `loadMockData()` called by the toolbar.
    public func resetToPreset() async {
        await loadMockData()
    }

    /// Updates the request JSON and clears any pending format error.
    public func updateJson(_ newJson: String) {
        requestJson = newJson
        requestJsonFormatError = nil
    }

    /// Updates the server URL (custom mode — clears any active tab environment)
    public func updateUrl(_ newUrl: String) {
        url = newUrl
    }

    /// Selects an environment for this tab; URL follows the environment
    public func selectTabEnvironment(_ environment: ServerEnvironment) {
        tabEnvironment = environment
        url = environment.url
        connectionSecurity.update(activeEnvironment: environment, restoredAdHocConfig: nil)
    }

    /// Switches to custom URL mode; clears the active tab environment
    public func useCustomUrl(_ customUrl: String) {
        tabEnvironment = nil
        url = customUrl
        connectionSecurity.update(activeEnvironment: nil, restoredAdHocConfig: nil)
    }

    /// Updates the metadata JSON and clears any pending format error.
    public func updateMetadata(_ newMetadata: String) {
        metadataJson = newMetadata
        metadataFormatError = nil
    }

    /// Toggles metadata visibility
    public func toggleMetadataVisibility() {
        isMetadataVisible.toggle()
    }

    /// Executes the gRPC request
    public func executeRequest() async {
        // Clear previous state
        response = nil
        error = nil
        isExecuting = true

        do {
            // Parse metadata if not empty
            var metadata: GrpcMetadata? = nil
            let trimmedMetadata = metadataJson.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedMetadata != "{}", !trimmedMetadata.isEmpty {
                metadata = try GrpcMetadata.from(json: metadataJson)
            }

            // Create request draft
            let requestDraft = RequestDraft(
                jsonBody: requestJson,
                url: url,
                method: editorTab.method,
                metadata: metadata,
                tlsConfiguration: connectionSecurity.effectiveTLSConfiguration)

            // Execute request
            let grpcResponse = try await executeRequestUseCase.execute(
                request: requestDraft,
                method: editorTab.method,
                protoFile: editorTab.protoFile)

            // Update state with response
            response = grpcResponse
        } catch let metadataError as GrpcMetadataError {
            // Handle metadata parsing errors
            error = formatMetadataError(metadataError)
        } catch let grpcError as GrpcClientError {
            // Handle gRPC-specific errors
            // Extract response if error contains it (for metadata visibility)
            if case let .grpcError(_, errorResponse) = grpcError {
                response = errorResponse
            }
            error = formatError(grpcError)
        } catch let protoError as ProtoRepositoryError {
            logger.error("Proto repository error during request execution", metadata: [
                "method": editorTab.method.name,
                "service": editorTab.method.serviceName,
                "error": protoError.localizedDescription,
            ])
            error = protoError.localizedDescription
        } catch let otherError {
            logger.error("Unexpected error during request execution", metadata: [
                "method": editorTab.method.name,
                "service": editorTab.method.serviceName,
                "error": otherError.localizedDescription,
            ])
            error = "Request failed: \(otherError.localizedDescription)"
        }

        isExecuting = false
    }

    // MARK: - Private Methods

    /// Copy response to clipboard
    public func copyResponse() {
        guard let response else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(response.jsonBody, forType: .string)
    }

    /// Export response to file
    public func exportResponse(to url: URL) throws {
        guard let response else { return }

        try exportResponseUseCase.execute(
            response: response,
            destination: url,
            includeMetadata: false)
    }

    /// Format gRPC error for display
    private func formatError(_ error: GrpcClientError) -> String {
        switch error {
        case let .invalidJSON(message):
            "Invalid JSON: \(message)"
        case let .networkError(message):
            "Network error: \(message)"
        case .timeout:
            "Request timeout"
        case .unavailable:
            "Service unavailable"
        case .invalidResponse:
            "Invalid response from server"
        case let .grpcError(message, _):
            "gRPC error: \(message)"
        case let .unknown(message):
            "Error: \(message)"
        case let .tlsConfigurationFailed(reason):
            "TLS configuration error: \(reason)"
        }
    }

    /// Format metadata error for display
    private func formatMetadataError(_ error: GrpcMetadataError) -> String {
        switch error {
        case .invalidJSON:
            "Invalid metadata JSON format"
        case .notAnObject:
            "Metadata must be a JSON object with key-value pairs"
        case .serializationFailed:
            "Failed to serialize metadata"
        }
    }
}
