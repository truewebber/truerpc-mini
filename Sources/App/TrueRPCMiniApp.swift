import AppKit
import Sparkle
import SwiftUI

@main
struct TrueRPCMiniApp: App {
    // MARK: - Properties

    /// Dependency Injection container
    private let di: AppDI

    /// Sparkle updater — must be retained for the app's lifetime.
    private let sparkleUpdater: SPUUpdater

    /// Sparkle user driver — must be retained; SPUUpdater holds it weakly.
    private let sparkleUserDriver: SilentOnErrorSparkleUserDriver

    /// Sparkle delegate — must be retained; SPUUpdater holds it weakly.
    private let sparkleUpdaterDelegate: SparkleUpdaterDelegate

    /// Sidebar ViewModel (created once and reused)
    @StateObject private var sidebarViewModel: SidebarViewModel

    /// App coordinator ViewModel
    @StateObject private var appViewModel: AppViewModel

    /// Global environment selection (singleton)
    @StateObject private var globalEnvironmentViewModel: GlobalEnvironmentViewModel

    /// Updater ViewModel for the "Check for Updates..." menu item
    @StateObject private var updaterViewModel: UpdaterViewModel

    /// About dialog ViewModel
    @StateObject private var aboutViewModel: AboutViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRestoredTabs = false
    @State private var isAboutPresented = false

    // MARK: - Initialization

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        UserDefaults.runAnalyticsMigration()

        let config = Config.fromBundle

        // === LOGGING ===
        // Must be set up before Sparkle so the delegate can log immediately.
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

        // === SPARKLE ===
        let sparkleDelegate = SparkleUpdaterDelegate(logger: logger)
        self.sparkleUpdaterDelegate = sparkleDelegate
        let userDriver = SilentOnErrorSparkleUserDriver(hostBundle: .main, delegate: nil, logger: logger)
        self.sparkleUserDriver = userDriver
        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: userDriver,
            delegate: sparkleDelegate)
        do {
            try updater.start()
        } catch {
            logger.error("Sparkle: failed to start updater", metadata: ["error": error.localizedDescription])
        }
        self.sparkleUpdater = updater

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
            MockDataGenerator(protoRepository: di.resolve(ProtoRepositoryProtocol.self)!)
        }

        di.register(AutocompleteProviderProtocol.self) {
            #if DEBUG
                if isUITesting {
                    return UITestAutocompleteProvider()
                }
            #endif
            return ProtoSchemaAutocompleteProvider(protoRepository: di.resolve(ProtoRepositoryProtocol.self)!)
        }

        di.register(JsonPathResolver.self) {
            JsonPathResolver()
        }

        di.register(JsonFormatterProtocol.self) {
            JsonFormatter()
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
            SparkleUpdaterService(updater: updater)
        }

        di.register(UpdaterViewModel.self) {
            UpdaterViewModel(updaterService: di.resolve(UpdaterServiceProtocol.self)!)
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
            autocompleteProvider: di.resolve(AutocompleteProviderProtocol.self)!,
            resolver: di.resolve(JsonPathResolver.self)!,
            telemetry: di.resolve(TelemetryServiceProtocol.self)!,
            logger: logger)
        appVM.onLaunched()

        #if DEBUG
            if isUITesting {
                let testMethod = Method(
                    name: "TestMethod",
                    inputType: ".uitest.TestRequest",
                    outputType: ".uitest.TestResponse",
                    isStreaming: false)
                let testService = Service(name: "TestService", methods: [testMethod])
                let testProto = ProtoFile(
                    name: "uitest.proto",
                    path: URL(fileURLWithPath: "/tmp/uitest.proto"),
                    services: [testService])
                appVM.openMethod(method: testMethod, service: testService, protoFile: testProto)
            }
        #endif

        let globalEnvVM = di.resolve(GlobalEnvironmentViewModel.self)!
        globalEnvVM.onEnvironmentDeleted = { [weak tabManagerVM] env in
            tabManagerVM?.handleEnvironmentDeleted(env)
        }
        globalEnvVM.onEnvironmentUpdated = { [weak tabManagerVM] env in
            tabManagerVM?.handleEnvironmentUpdated(env)
        }

        // Use _StateObject to initialize @StateObject properties
        _sidebarViewModel = StateObject(wrappedValue: sidebarVM)
        _appViewModel = StateObject(wrappedValue: appVM)
        _globalEnvironmentViewModel = StateObject(wrappedValue: globalEnvVM)
        _updaterViewModel = StateObject(wrappedValue: di.resolve(UpdaterViewModel.self)!)
        _aboutViewModel = StateObject(wrappedValue: AboutViewModel())
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
            .sheet(isPresented: $isAboutPresented) {
                AboutView(viewModel: aboutViewModel)
            }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About TrueRPC Mini") {
                    isAboutPresented = true
                }

                Divider()

                Button("Check for Updates...") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
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
