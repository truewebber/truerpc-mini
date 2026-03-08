import Foundation
import SwiftUI

/// Main app coordinator managing navigation between sidebar and editor
@MainActor
public final class AppViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var selectedEditorTab: EditorTabViewModel?

    // MARK: - Dependencies

    private let createEditorTabUseCase: CreateEditorTabUseCase
    private let generateMockDataUseCase: GenerateMockDataUseCase
    private let executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol
    private let exportResponseUseCase: ExportResponseUseCase
    private let telemetry: TelemetryServiceProtocol
    private let logger: AppLogger

    // MARK: - Initialization

    public init(
        createEditorTabUseCase: CreateEditorTabUseCase,
        generateMockDataUseCase: GenerateMockDataUseCase,
        executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol,
        exportResponseUseCase: ExportResponseUseCase,
        telemetry: TelemetryServiceProtocol,
        logger: AppLogger)
    {
        self.createEditorTabUseCase = createEditorTabUseCase
        self.generateMockDataUseCase = generateMockDataUseCase
        self.executeRequestUseCase = executeRequestUseCase
        self.exportResponseUseCase = exportResponseUseCase
        self.telemetry = telemetry
        self.logger = logger
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

    /// Opens an editor tab for the selected method
    public func openMethod(method: Method, service: Service, protoFile: ProtoFile) {
        let editorTab = createEditorTabUseCase.execute(method: method, service: service, protoFile: protoFile)
        let tabViewModel = EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            logger: logger)
        selectedEditorTab = tabViewModel
        Task {
            await telemetry.track(.tabSwitched(tabName: "request"))
            await telemetry.track(.requestFormOpened(hasProto: true))
        }
    }
}
