import os
import XCTest
@testable import TrueRPCMini

@MainActor
final class SidebarViewModelTests: XCTestCase {
    var sut: SidebarViewModel!
    var mockUseCase: MockImportProtoFileUseCase!
    var mockRefreshUseCase: MockRefreshProtoFileUseCase!
    var mockWatcher: MockProtoFileWatcher!
    var mockImportPathsRepository: MockImportPathsRepository!
    var mockProtoPathsPersistence: MockProtoPathsPersistence!
    var mockLoadSavedProtosUseCase: MockLoadSavedProtosUseCase!
    var mockLogger: MockAppLogger!
    var mockTelemetry: MockTelemetryService!

    override func setUp() {
        super.setUp()
        mockUseCase = MockImportProtoFileUseCase()
        mockRefreshUseCase = MockRefreshProtoFileUseCase()
        mockWatcher = MockProtoFileWatcher()
        mockImportPathsRepository = MockImportPathsRepository()
        mockProtoPathsPersistence = MockProtoPathsPersistence()
        mockLoadSavedProtosUseCase = MockLoadSavedProtosUseCase()
        mockLogger = MockAppLogger()
        mockTelemetry = MockTelemetryService()
        sut = SidebarViewModel(
            importProtoFileUseCase: mockUseCase,
            refreshProtoFileUseCase: mockRefreshUseCase,
            watcher: mockWatcher,
            importPathsRepository: mockImportPathsRepository,
            protoPathsPersistence: mockProtoPathsPersistence,
            loadSavedProtosUseCase: mockLoadSavedProtosUseCase,
            logger: mockLogger,
            telemetry: mockTelemetry)
    }

    override func tearDown() {
        sut = nil
        mockUseCase = nil
        mockRefreshUseCase = nil
        mockWatcher = nil
        mockImportPathsRepository = nil
        mockProtoPathsPersistence = nil
        mockLoadSavedProtosUseCase = nil
        mockLogger = nil
        mockTelemetry = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_init_setsInitialState() {
        // Then
        XCTAssertTrue(sut.protoFiles.isEmpty)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.importPathsCount, 0)
    }

    func test_init_setsImportPathsCountFromRepository() {
        mockImportPathsRepository.importPaths = ["/a", "/b"]

        sut = SidebarViewModel(
            importProtoFileUseCase: mockUseCase,
            refreshProtoFileUseCase: mockRefreshUseCase,
            watcher: mockWatcher,
            importPathsRepository: mockImportPathsRepository,
            protoPathsPersistence: mockProtoPathsPersistence,
            loadSavedProtosUseCase: mockLoadSavedProtosUseCase,
            logger: mockLogger,
            telemetry: mockTelemetry)

        XCTAssertEqual(sut.importPathsCount, 2)
    }

    func test_refreshImportPathsCount_updatesFromRepository() {
        mockImportPathsRepository.importPaths = ["/a"]

        sut.refreshImportPathsCount()

        XCTAssertEqual(sut.importPathsCount, 1)

        mockImportPathsRepository.importPaths = ["/a", "/b", "/c"]
        sut.refreshImportPathsCount()

        XCTAssertEqual(sut.importPathsCount, 3)
    }

    // MARK: - Import Success Tests

    func test_importProtoFile_whenSuccess_updatesProtoFiles() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/example.proto")
        let expectedProto = ProtoFile(
            name: "example.proto",
            path: testURL,
            services: [])
        mockUseCase.mockResultsByURL[testURL] = .success(expectedProto)

        // When
        await sut.importProtoFile(url: testURL)

        // Then
        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles.first?.name, "example.proto")
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func test_importProtoFile_whenSuccess_clearsError() async {
        // Given
        sut.error = "Previous error"
        let testURL = URL(fileURLWithPath: "/test/example.proto")
        mockUseCase.mockResultsByURL[testURL] = .success(ProtoFile(name: "test", path: testURL, services: []))

        // When
        await sut.importProtoFile(url: testURL)

        // Then
        XCTAssertNil(sut.error)
    }

    // MARK: - Import Error Tests

    func test_importProtoFile_whenError_setsErrorMessage() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/invalid.proto")
        mockUseCase.mockResultsByURL[testURL] = .failure(TestError.importFailed)

        // When
        await sut.importProtoFile(url: testURL)

        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.protoFiles.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func test_importProtoFile_whenError_logsError() async {
        let testURL = URL(fileURLWithPath: "/test/broken.proto")
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "parse failed"])
        mockUseCase.mockResultsByURL[testURL] = .failure(error)

        await sut.importProtoFile(url: testURL)

        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["path"], testURL.path)
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["error"], error.localizedDescription)
    }

    func test_handlePickerError_logsErrorAndSetsErrorMessage() {
        let error = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "picker failed"])

        sut.handlePickerError(error)

        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["error"], error.localizedDescription)
        XCTAssertEqual(sut.error, error.localizedDescription)
    }

    func test_importProtoFile_whenError_doesNotAddToList() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/invalid.proto")
        mockUseCase.mockResultsByURL[testURL] = .failure(TestError.importFailed)

        // When
        await sut.importProtoFile(url: testURL)

        // Then
        XCTAssertEqual(sut.protoFiles.count, 0)
    }

    // MARK: - Multiple Imports Tests

    func test_importMultipleFiles_addsAllToList() async {
        // Given
        let url1 = URL(fileURLWithPath: "/test/file1.proto")
        let url2 = URL(fileURLWithPath: "/test/file2.proto")

        mockUseCase.mockResultsByURL[url1] = .success(ProtoFile(name: "file1", path: url1, services: []))
        mockUseCase.mockResultsByURL[url2] = .success(ProtoFile(name: "file2", path: url2, services: []))

        // When
        await sut.importProtoFile(url: url1)
        await sut.importProtoFile(url: url2)

        // Then
        XCTAssertEqual(sut.protoFiles.count, 2)
    }

    func test_importProtoFile_whenSameFileImportedTwice_keepsSingleEntry() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/duplicate.proto")
        let expectedProto = ProtoFile(
            name: "duplicate.proto",
            path: testURL,
            services: [])
        mockUseCase.mockResultsByURL[testURL] = .success(expectedProto)

        // When
        await sut.importProtoFile(url: testURL)
        await sut.importProtoFile(url: testURL)

        // Then
        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles.first?.path, testURL)
    }

    // MARK: - Telemetry Tests

    func test_importProtoFile_whenSuccess_tracksProtoAddedEvent() async {
        let testURL = URL(fileURLWithPath: "/test/service.proto")
        mockUseCase.mockResultsByURL[testURL] = .success(ProtoFile(name: "service.proto", path: testURL, services: []))

        await sut.importProtoFile(url: testURL)

        XCTAssertEqual(mockTelemetry.trackedEvents.count, 1)
        XCTAssertEqual(mockTelemetry.trackedEvents[0].name, "proto_added")
        XCTAssertEqual(mockTelemetry.trackedEvents[0].properties["source"], "file")
    }

    func test_importProtoFile_whenError_tracksProtoLoadFailedEvent() async {
        let testURL = URL(fileURLWithPath: "/test/broken.proto")
        mockUseCase.mockResultsByURL[testURL] = .failure(TestError.importFailed)

        await sut.importProtoFile(url: testURL)

        XCTAssertEqual(mockTelemetry.trackedEvents.count, 1)
        XCTAssertEqual(mockTelemetry.trackedEvents[0].name, "proto_load_failed")
        XCTAssertEqual(mockTelemetry.trackedEvents[0].properties["source"], "file")
    }

    func test_importProtoFile_whenSuccess_doesNotTrackProtoLoadFailed() async {
        let testURL = URL(fileURLWithPath: "/test/ok.proto")
        mockUseCase.mockResultsByURL[testURL] = .success(ProtoFile(name: "ok.proto", path: testURL, services: []))

        await sut.importProtoFile(url: testURL)

        XCTAssertFalse(mockTelemetry.trackedEvents.contains { $0.name == "proto_load_failed" })
    }

    func test_importProtoFile_whenError_doesNotTrackProtoAdded() async {
        let testURL = URL(fileURLWithPath: "/test/bad.proto")
        mockUseCase.mockResultsByURL[testURL] = .failure(TestError.importFailed)

        await sut.importProtoFile(url: testURL)

        XCTAssertFalse(mockTelemetry.trackedEvents.contains { $0.name == "proto_added" })
    }

    func test_removeProtoFile_tracksProtoRemovedEvent() async {
        let testURL = URL(fileURLWithPath: "/test/removable.proto")
        let proto = ProtoFile(name: "removable.proto", path: testURL, services: [])
        mockUseCase.mockResultsByURL[testURL] = .success(proto)
        await sut.importProtoFile(url: testURL)
        mockTelemetry.reset()

        await sut.removeProtoFile(proto)

        let events = mockTelemetry.trackedEvents
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, "proto_removed")
    }

    func test_removeProtoFile_removesFromList() async {
        let testURL = URL(fileURLWithPath: "/test/removable2.proto")
        let proto = ProtoFile(name: "removable2.proto", path: testURL, services: [])
        mockUseCase.mockResultsByURL[testURL] = .success(proto)
        await sut.importProtoFile(url: testURL)
        XCTAssertEqual(sut.protoFiles.count, 1)

        await sut.removeProtoFile(proto)

        XCTAssertTrue(sut.protoFiles.isEmpty)
    }

    func test_removeProtoFile_persistsUpdatedPaths() async {
        let testURL = URL(fileURLWithPath: "/test/removable3.proto")
        let proto = ProtoFile(name: "removable3.proto", path: testURL, services: [])
        mockUseCase.mockResultsByURL[testURL] = .success(proto)
        await sut.importProtoFile(url: testURL)

        await sut.removeProtoFile(proto)

        XCTAssertTrue(mockProtoPathsPersistence.savedPaths.isEmpty)
    }

    func test_importProtoFile_trackEventPropertiesContainNoFilePath() async {
        let testURL = URL(fileURLWithPath: "/private/secrets/service.proto")
        mockUseCase.mockResultsByURL[testURL] = .success(ProtoFile(name: "service.proto", path: testURL, services: []))

        await sut.importProtoFile(url: testURL)

        let event = mockTelemetry.trackedEvents[0]
        XCTAssertFalse(event.properties.values.contains { $0.contains("/private/secrets") })
    }

    // MARK: - Load Saved Protos Tests

    // MARK: - Refresh Proto File Tests (TRMN-153)

    func test_refreshProtoFile_whenSucceeds_replacesProtoFileInList() async {
        let url = URL(fileURLWithPath: "/test/refresh.proto")
        let oldProto = ProtoFile(name: "old.proto", path: url, services: [])
        let newProto = ProtoFile(name: "new.proto", path: url, services: [])
        sut.protoFiles = [oldProto]
        mockRefreshUseCase.mockResultsByPath[url] = .success(newProto)

        await sut.refreshProtoFile(oldProto)

        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles[0].name, "new.proto")
        XCTAssertNil(sut.error)
    }

    func test_refreshProtoFile_whenFails_keepsOldProtoFileAndShowsError() async {
        let url = URL(fileURLWithPath: "/test/broken.proto")
        let oldProto = ProtoFile(name: "broken.proto", path: url, services: [])
        let expectedError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "parse failed"])
        sut.protoFiles = [oldProto]
        mockRefreshUseCase.mockResultsByPath[url] = .failure(expectedError)

        await sut.refreshProtoFile(oldProto)

        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles[0].name, "broken.proto")
        XCTAssertEqual(sut.error, expectedError.localizedDescription)
    }

    func test_refreshProtoFile_tracksRefreshedTelemetryEvent() async {
        let url = URL(fileURLWithPath: "/test/track.proto")
        let proto = ProtoFile(name: "track.proto", path: url, services: [])
        let updated = ProtoFile(name: "track.proto", path: url, services: [])
        sut.protoFiles = [proto]
        mockRefreshUseCase.mockResultsByPath[url] = .success(updated)

        await sut.refreshProtoFile(proto)

        XCTAssertEqual(mockTelemetry.trackedEvents.count, 1)
        XCTAssertEqual(mockTelemetry.trackedEvents[0].name, "proto_refreshed")
    }

    // MARK: - Watcher Lifecycle Tests (TRMN-158)

    func test_importProtoFile_whenSucceeds_startsWatchingFile() async {
        let testURL = URL(fileURLWithPath: "/test/watch.proto")
        let proto = ProtoFile(name: "watch.proto", path: testURL, services: [])
        mockUseCase.mockResultsByURL[testURL] = .success(proto)

        await sut.importProtoFile(url: testURL)

        XCTAssertEqual(mockWatcher.startWatchingCalls.count, 1)
        XCTAssertEqual(mockWatcher.startWatchingCalls.first?.path, testURL)
    }

    func test_removeProtoFile_stopsWatchingFile() async {
        let testURL = URL(fileURLWithPath: "/test/remove_watch.proto")
        let proto = ProtoFile(name: "remove_watch.proto", path: testURL, services: [])
        sut.protoFiles = [proto]

        await sut.removeProtoFile(proto)

        XCTAssertEqual(mockWatcher.stopWatchingCalls.count, 1)
        XCTAssertEqual(mockWatcher.stopWatchingCalls.first?.path, testURL)
    }

    func test_watcherChange_triggersRefreshProtoFile() async {
        let url = URL(fileURLWithPath: "/test/auto_refresh.proto")
        let proto = ProtoFile(name: "auto_refresh.proto", path: url, services: [])
        let refreshed = ProtoFile(name: "auto_refresh.proto", path: url, services: [])
        sut.protoFiles = [proto]
        mockRefreshUseCase.mockResultsByPath[url] = .success(refreshed)

        mockWatcher.emit(proto)
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertGreaterThan(mockRefreshUseCase.callCount, 0)
        XCTAssertEqual(mockRefreshUseCase.lastProtoFile?.path, url)
    }

    func test_loadSavedProtos_whenAlreadyLoaded_doesNotDuplicate() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/saved.proto")
        let existingProto = ProtoFile(
            name: "saved.proto",
            path: testURL,
            services: [])
        sut.protoFiles = [existingProto]
        mockProtoPathsPersistence.savedPaths = [testURL]
        mockLoadSavedProtosUseCase.mockProtos = [existingProto]

        // When
        await sut.loadSavedProtos()

        // Then
        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles.first?.path, testURL)
    }
}

// MARK: - Mock ImportPaths Repository

final class MockImportPathsRepository: ImportPathsRepositoryProtocol, Sendable {
    private struct Storage {
        var importPaths: [String] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var importPaths: [String] {
        get { storage.withLock { $0.importPaths } }
        set { storage.withLock { $0.importPaths = newValue } }
    }

    func getImportPaths() -> [String] {
        storage.withLock { $0.importPaths }
    }

    func saveImportPaths(_ paths: [String]) {
        storage.withLock { $0.importPaths = paths }
    }
}

// MARK: - Mock ProtoPathsPersistence

final class MockProtoPathsPersistence: ProtoPathsPersistenceProtocol, Sendable {
    private struct Storage {
        var savedPaths: [URL] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var savedPaths: [URL] {
        get { storage.withLock { $0.savedPaths } }
        set { storage.withLock { $0.savedPaths = newValue } }
    }

    func saveProtoPaths(_ paths: [URL]) {
        storage.withLock { $0.savedPaths = paths }
    }

    func getProtoPaths() -> [URL] {
        storage.withLock { $0.savedPaths }
    }
}

// MARK: - Mock LoadSavedProtosUseCase

@MainActor
final class MockLoadSavedProtosUseCase: LoadSavedProtosUseCaseProtocol {
    var executeCalled = false
    var executeURLs: [URL]?
    var executeImportPaths: [String]?
    var mockProtos: [ProtoFile] = []

    init() {}

    func execute(urls: [URL], importPaths: [String]) -> [ProtoFile] {
        executeCalled = true
        executeURLs = urls
        executeImportPaths = importPaths
        return mockProtos
    }
}

private enum TestError: Error {
    case importFailed
    case noProtoFile
}
