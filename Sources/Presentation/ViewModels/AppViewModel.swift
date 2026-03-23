import Combine
import Foundation
import SwiftUI

/// Main app coordinator managing navigation between sidebar and editor
@MainActor
public final class AppViewModel: ObservableObject {
    // MARK: - Published Properties

    public var selectedEditorTab: EditorTabViewModel? {
        tabManager.selectedTab
    }

    // MARK: - Dependencies

    public let tabManager: TabManagerViewModel
    private var cancellables = Set<AnyCancellable>()
    private let createEditorTabUseCase: CreateEditorTabUseCase
    private let generateMockDataUseCase: GenerateMockDataUseCaseProtocol
    private let executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol
    private let exportResponseUseCase: ExportResponseUseCaseProtocol
    private let autocompleteProvider: AutocompleteProviderProtocol
    private let resolver: JsonPathResolver
    private let telemetry: TelemetryServiceProtocol
    private let logger: AppLogger

    // MARK: - Initialization

    public init(
        tabManager: TabManagerViewModel,
        createEditorTabUseCase: CreateEditorTabUseCase,
        generateMockDataUseCase: GenerateMockDataUseCaseProtocol,
        executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol,
        exportResponseUseCase: ExportResponseUseCaseProtocol,
        autocompleteProvider: AutocompleteProviderProtocol,
        resolver: JsonPathResolver,
        telemetry: TelemetryServiceProtocol,
        logger: AppLogger)
    {
        self.tabManager = tabManager
        self.createEditorTabUseCase = createEditorTabUseCase
        self.generateMockDataUseCase = generateMockDataUseCase
        self.executeRequestUseCase = executeRequestUseCase
        self.exportResponseUseCase = exportResponseUseCase
        self.autocompleteProvider = autocompleteProvider
        self.resolver = resolver
        self.telemetry = telemetry
        self.logger = logger

        tabManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    /// Must be called once at app launch. Tracks the `app_launched` event with version info.
    public func onLaunched() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        Task {
            await telemetry.track(.appLaunched(appVersion: appVersion, osVersion: osVersion))
        }
    }

    /// Must be called on every SwiftUI scene phase change.
    /// Tracks `app_backgrounded` on `.background` and `app_foregrounded` on `.active`.
    public func onScenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            Task { await telemetry.track(.appBackgrounded()) }
        case .active:
            Task { await telemetry.track(.appForegrounded()) }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Navigation Telemetry

    /// Called when the user navigates to the protos sidebar section.
    public func onProtosTabSelected() {
        Task { await telemetry.track(.tabSwitched(tabName: "protos")) }
    }

    /// Called when the user opens the Settings sheet.
    public func onSettingsOpened() {
        Task { await telemetry.track(.tabSwitched(tabName: "settings")) }
    }

    // MARK: - Public Methods

    /// Opens an editor tab for the selected method, inheriting the current global environment
    public func openMethod(
        method: Method,
        service: Service,
        protoFile: ProtoFile,
        initialEnvironment: ServerEnvironment? = nil,
        availableEnvironments: [ServerEnvironment] = [])
    {
        let editorTab = createEditorTabUseCase.execute(method: method, service: service, protoFile: protoFile)
        let tabViewModel = EditorTabViewModel(
            editorTab: editorTab,
            initialEnvironment: initialEnvironment,
            availableEnvironments: availableEnvironments,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            autocompleteProvider: autocompleteProvider,
            resolver: resolver,
            logger: logger)
        tabManager.addTab(tabViewModel)
        Task {
            await telemetry.track(.tabSwitched(tabName: "request"))
            await telemetry.track(.requestFormOpened(hasProto: true))
        }
    }

    /// Restores tabs from persisted state using loaded proto files
    public func restoreTabs(protoFiles: [ProtoFile], availableEnvironments: [ServerEnvironment] = []) {
        let states = tabManager.restoredStates()
        guard !states.isEmpty, !protoFiles.isEmpty else { return }

        for state in states {
            guard let (method, service, protoFile) = findMethod(
                protoFilePath: state.protoFilePath,
                serviceName: state.serviceName,
                methodName: state.methodName,
                in: protoFiles)
            else { continue }

            let initialEnvironment = state.selectedEnvironmentId.flatMap { envId in
                availableEnvironments.first { $0.id == envId }
            }
            let customUrl = initialEnvironment == nil ? state.customUrl : nil

            let editorTab = EditorTab(
                id: state.id,
                methodName: method.name,
                serviceName: service.name,
                protoFile: protoFile,
                method: method)
            let tabViewModel = EditorTabViewModel(
                editorTab: editorTab,
                initialEnvironment: initialEnvironment,
                customUrl: customUrl,
                restoredTabState: state,
                availableEnvironments: availableEnvironments,
                generateMockDataUseCase: generateMockDataUseCase,
                executeRequestUseCase: executeRequestUseCase,
                exportResponseUseCase: exportResponseUseCase,
                autocompleteProvider: autocompleteProvider,
                resolver: resolver,
                logger: logger)
            tabManager.addTab(tabViewModel)
        }
    }

    private func findMethod(
        protoFilePath: String,
        serviceName: String,
        methodName: String,
        in protoFiles: [ProtoFile])
        -> (Method, Service, ProtoFile)?
    {
        let normalizedPath = (protoFilePath as NSString).standardizingPath
        guard let protoFile = protoFiles.first(where: {
            ($0.path.path as NSString).standardizingPath == normalizedPath
        })
        else { return nil }
        guard let service = protoFile.services.first(where: { $0.name == serviceName }) else { return nil }
        guard let method = service.methods.first(where: { $0.name == methodName }) else { return nil }

        return (method, service, protoFile)
    }
}
