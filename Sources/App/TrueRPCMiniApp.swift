import AppKit
import Sparkle
import SwiftUI

@main
struct TrueRPCMiniApp: App {
    // MARK: - Properties

    /// Dependency Injection container
    private let di: AppDI

    /// Sparkle updater controller — must be retained for the app's lifetime.
    private let sparkleUpdaterController: SPUStandardUpdaterController

    /// Sidebar ViewModel (created once and reused)
    @StateObject private var sidebarViewModel: SidebarViewModel

    /// App coordinator ViewModel
    @StateObject private var appViewModel: AppViewModel

    /// Global environment selection (singleton)
    @StateObject private var globalEnvironmentViewModel: GlobalEnvironmentViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRestoredTabs = false

    // MARK: - Initialization

    init() {
        UserDefaults.runAnalyticsMigration()

        let config = Config.fromBundle

        // === SPARKLE ===
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        sparkleUpdaterController = updaterController

        // === LOGGING ===
        #if DEBUG
            let logger: any AppLogger = OSLogger(category: "app")
        #else
            // Defer Sentry init to next run loop to avoid blocking main thread at startup.
            // Sentry SDK can perform I/O and sync work that triggers App Hang on slow systems.
            DispatchQueue.main.async {
                SentryBootstrapper.start(dsn: config.sentryDsn)
            }
            let logger: any AppLogger = MultiplexLogger([
                OSLogger(category: "app"),
                SentryLogger(minLevel: .warning),
            ])
        #endif

        let di = AppDI()
        self.di = di

        di.register(AppLogger.self) { logger }

        // Register Data Layer dependencies
        di.register(ProtoRepositoryProtocol.self) {
            FileSystemProtoRepository(logger: logger)
        }

        di.register(ImportPathsRepositoryProtocol.self) {
            UserDefaultsImportPathsRepository()
        }

        di.register(ImportPathsViewModel.self, lifecycle: .transient) {
            ImportPathsViewModel(importPathsRepository: di.resolve(ImportPathsRepositoryProtocol.self)!)
        }

        di.register(EnvironmentRepositoryProtocol.self) {
            UserDefaultsEnvironmentRepository()
        }

        di.register(LoadEnvironmentsUseCaseProtocol.self) {
            LoadEnvironmentsUseCase(repository: di.resolve(EnvironmentRepositoryProtocol.self)!)
        }

        di.register(SaveEnvironmentUseCaseProtocol.self) {
            SaveEnvironmentUseCase(repository: di.resolve(EnvironmentRepositoryProtocol.self)!)
        }

        di.register(DeleteEnvironmentUseCaseProtocol.self) {
            DeleteEnvironmentUseCase(repository: di.resolve(EnvironmentRepositoryProtocol.self)!)
        }

        di.register(SelectEnvironmentUseCaseProtocol.self) {
            SelectEnvironmentUseCase(repository: di.resolve(EnvironmentRepositoryProtocol.self)!)
        }

        di.register(GetSelectedEnvironmentUseCaseProtocol.self) {
            GetSelectedEnvironmentUseCase(repository: di.resolve(EnvironmentRepositoryProtocol.self)!)
        }

        di.register(GlobalEnvironmentViewModel.self) {
            GlobalEnvironmentViewModel(
                loadEnvironmentsUseCase: di.resolve(LoadEnvironmentsUseCaseProtocol.self)!,
                saveEnvironmentUseCase: di.resolve(SaveEnvironmentUseCaseProtocol.self)!,
                deleteEnvironmentUseCase: di.resolve(DeleteEnvironmentUseCaseProtocol.self)!,
                selectEnvironmentUseCase: di.resolve(SelectEnvironmentUseCaseProtocol.self)!,
                getSelectedEnvironmentUseCase: di.resolve(GetSelectedEnvironmentUseCaseProtocol.self)!)
        }

        di.register(SettingsViewModel.self) {
            SettingsViewModel(telemetry: di.resolve(TelemetryServiceProtocol.self)!)
        }

        di.register(ProtoPathsPersistenceProtocol.self) {
            UserDefaultsProtoPathsRepository(logger: logger)
        }

        di.register(MockDataGeneratorProtocol.self) {
            MockDataGenerator()
        }

        di.register(GrpcClientProtocol.self) {
            GrpcSwiftDynamicClient(
                protoRepository: di.resolve(ProtoRepositoryProtocol.self)!,
                logger: logger)
        }

        di.register(FileManagerProtocol.self) {
            SystemFileManager()
        }

        // === TELEMETRY ===
        di.register(TelemetryServiceProtocol.self) {
            #if DEBUG
                OSLogTelemetryService()
            #else
                AmplitudeTelemetryService(
                    apiKey: config.amplitudeKey,
                    isEnabled: { UserDefaults.standard.analyticsIsEnabled },
                    responseHandler: LoggingTrackerResponseHandler(logger: logger))
            #endif
        }

        // === UPDATER ===
        di.register(UpdaterServiceProtocol.self) {
            SparkleUpdaterService(updater: updaterController)
        }

        // Register Domain Layer dependencies
        di.register(ImportProtoFileUseCaseProtocol.self) {
            ImportProtoFileUseCase(repository: di.resolve(ProtoRepositoryProtocol.self)!)
        }

        di.register(RefreshProtoFileUseCaseProtocol.self) {
            RefreshProtoFileUseCase(repository: di.resolve(ProtoRepositoryProtocol.self)!)
        }

        di.register(ProtoFileWatcherProtocol.self) {
            FSEventsProtoFileWatcher()
        }

        di.register(LoadSavedProtosUseCase.self) {
            LoadSavedProtosUseCase(
                importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!,
                logger: logger)
        }

        di.register(CreateEditorTabUseCase.self) {
            CreateEditorTabUseCase()
        }

        di.register(GenerateMockDataUseCase.self) {
            GenerateMockDataUseCase(
                mockDataGenerator: di.resolve(MockDataGeneratorProtocol.self)!)
        }

        di.register(ExecuteUnaryRequestUseCaseProtocol.self) {
            ExecuteUnaryRequestUseCase(
                grpcClient: di.resolve(GrpcClientProtocol.self)!,
                telemetry: di.resolve(TelemetryServiceProtocol.self)!)
        }

        di.register(ExportResponseUseCase.self) {
            ExportResponseUseCase(
                fileManager: di.resolve(FileManagerProtocol.self)!)
        }

        di.register(TabPersistenceProtocol.self) {
            UserDefaultsTabRepository()
        }

        di.register(SaveTabStateUseCaseProtocol.self) {
            SaveTabStateUseCase(repository: di.resolve(TabPersistenceProtocol.self)!)
        }

        di.register(RestoreTabsUseCaseProtocol.self) {
            RestoreTabsUseCase(repository: di.resolve(TabPersistenceProtocol.self)!)
        }

        di.register(TabManagerViewModel.self) {
            TabManagerViewModel(
                saveTabStateUseCase: di.resolve(SaveTabStateUseCaseProtocol.self)!,
                restoreTabsUseCase: di.resolve(RestoreTabsUseCaseProtocol.self)!)
        }

        // Create SidebarViewModel once
        let sidebarVM = SidebarViewModel(
            importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!,
            refreshProtoFileUseCase: di.resolve(RefreshProtoFileUseCaseProtocol.self)!,
            watcher: di.resolve(ProtoFileWatcherProtocol.self)!,
            importPathsRepository: di.resolve(ImportPathsRepositoryProtocol.self)!,
            protoPathsPersistence: di.resolve(ProtoPathsPersistenceProtocol.self)!,
            loadSavedProtosUseCase: di.resolve(LoadSavedProtosUseCase.self)!,
            logger: logger,
            telemetry: di.resolve(TelemetryServiceProtocol.self)!)

        // Create TabManagerViewModel and AppViewModel
        let tabManagerVM = di.resolve(TabManagerViewModel.self)!
        let appVM = AppViewModel(
            tabManager: tabManagerVM,
            createEditorTabUseCase: di.resolve(CreateEditorTabUseCase.self)!,
            generateMockDataUseCase: di.resolve(GenerateMockDataUseCase.self)!,
            executeRequestUseCase: di.resolve(ExecuteUnaryRequestUseCaseProtocol.self)!,
            exportResponseUseCase: di.resolve(ExportResponseUseCase.self)!,
            telemetry: di.resolve(TelemetryServiceProtocol.self)!,
            logger: logger)
        appVM.onLaunched()

        let globalEnvVM = di.resolve(GlobalEnvironmentViewModel.self)!
        globalEnvVM.onEnvironmentDeleted = { [weak tabManagerVM] env in
            tabManagerVM?.handleEnvironmentDeleted(env)
        }

        // Use _StateObject to initialize @StateObject properties
        _sidebarViewModel = StateObject(wrappedValue: sidebarVM)
        _appViewModel = StateObject(wrappedValue: appVM)
        _globalEnvironmentViewModel = StateObject(wrappedValue: globalEnvVM)
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(
                    viewModel: sidebarViewModel,
                    onMethodSelected: { method, service, protoFile in
                        appViewModel.openMethod(
                            method: method,
                            service: service,
                            protoFile: protoFile,
                            initialEnvironment: globalEnvironmentViewModel.selectedEnvironment,
                            availableEnvironments: globalEnvironmentViewModel.environments)
                    },
                    onSettingsOpened: {
                        appViewModel.onSettingsOpened()
                    })
                    .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
                    .task {
                        globalEnvironmentViewModel.loadEnvironments()
                        await sidebarViewModel.loadSavedProtos()
                    }
                    .onChange(of: sidebarViewModel.protoFiles.count) { _, _ in
                        if !hasRestoredTabs, !sidebarViewModel.protoFiles.isEmpty {
                            hasRestoredTabs = true
                            appViewModel.restoreTabs(
                                protoFiles: sidebarViewModel.protoFiles,
                                availableEnvironments: globalEnvironmentViewModel.environments)
                        }
                    }
            } detail: {
                VStack(spacing: 0) {
                    TabBarView(tabManager: appViewModel.tabManager)

                    if let editorTab = appViewModel.selectedEditorTab {
                        RequestEditorView(viewModel: editorTab, globalEnvironmentViewModel: globalEnvironmentViewModel)
                    } else {
                        placeholderView
                    }
                }
            }
            .environmentObject(di)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    GlobalEnvironmentSelectorView(viewModel: globalEnvironmentViewModel)
                }
            }
            .onAppear {
                applyWindowConstraints(hasTab: !appViewModel.tabManager.tabs.isEmpty, animate: false)
            }
            .onChange(of: appViewModel.tabManager.tabs.count) { _, _ in
                applyWindowConstraints(hasTab: !appViewModel.tabManager.tabs.isEmpty, animate: true)
            }
        }
        .defaultSize(width: 1100, height: 700)
        .onChange(of: scenePhase) { _, newPhase in
            appViewModel.onScenePhaseChanged(to: newPhase)
        }
    }

    // MARK: - Private

    private func applyWindowConstraints(hasTab: Bool, animate: Bool) {
        // Defer so SwiftUI finishes its layout pass before we touch the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = NSApplication.shared.windows
                .first(where: { !$0.isMiniaturized && $0.contentView != nil })
            else { return }

            if hasTab {
                // Sidebar(260) + divider + RequestEditor(300) + divider + Response(300) + chrome
                let minW: CGFloat = 900
                let minH: CGFloat = 600
                window.minSize = NSSize(width: minW, height: minH)
                var frame = window.frame
                if frame.size.width < minW || frame.size.height < minH {
                    frame.size.width = max(frame.size.width, minW)
                    frame.size.height = max(frame.size.height, minH)
                    window.setFrame(frame, display: true, animate: animate)
                }
            } else {
                // Only sidebar needed
                window.minSize = NSSize(width: 420, height: 400)
            }
        }
    }

    // MARK: - Subviews

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Select a method to start")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
