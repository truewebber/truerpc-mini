import XCTest
@testable import TrueRPCMini

final class FSEventsProtoFileWatcherTests: XCTestCase {
    var sut: FSEventsProtoFileWatcher!

    override func setUp() {
        super.setUp()
        sut = FSEventsProtoFileWatcher()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeFile(name: String = "test") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)_\(UUID().uuidString).proto")
        try "syntax = \"proto3\";".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeProtoFile(path: URL, dependencies: [URL] = []) -> ProtoFile {
        ProtoFile(name: path.lastPathComponent, path: path, services: [], dependencyPaths: dependencies)
    }

    // MARK: - Tests

    func test_startWatching_whenFileChanges_emitsProtoFile() async throws {
        let fileURL = try makeFile(name: "main")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let protoFile = makeProtoFile(path: fileURL)

        sut.startWatching(protoFile)
        try await Task.sleep(nanoseconds: 100_000_000)

        let expectation = XCTestExpectation(description: "emit on file change")
        var received: ProtoFile?
        let task = Task {
            for await change in sut.changes {
                received = change
                expectation.fulfill()
                break
            }
        }

        try "updated content".write(to: fileURL, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()

        XCTAssertEqual(received?.path, fileURL)
    }

    func test_startWatching_whenDependencyChanges_emitsRootProtoFile() async throws {
        let mainURL = try makeFile(name: "main_dep")
        let depURL = try makeFile(name: "dep")
        defer {
            try? FileManager.default.removeItem(at: mainURL)
            try? FileManager.default.removeItem(at: depURL)
        }
        let protoFile = makeProtoFile(path: mainURL, dependencies: [depURL])

        sut.startWatching(protoFile)
        try await Task.sleep(nanoseconds: 100_000_000)

        let expectation = XCTestExpectation(description: "emit on dependency change")
        var received: ProtoFile?
        let task = Task {
            for await change in sut.changes {
                received = change
                expectation.fulfill()
                break
            }
        }

        try "updated dep content".write(to: depURL, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()

        XCTAssertEqual(received?.path, mainURL, "Must emit the root ProtoFile, not the dependency")
    }

    func test_stopWatching_afterStop_doesNotEmit() async throws {
        let fileURL = try makeFile(name: "stop_test")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let protoFile = makeProtoFile(path: fileURL)

        sut.startWatching(protoFile)
        try await Task.sleep(nanoseconds: 100_000_000)

        sut.stopWatching(protoFile)
        try await Task.sleep(nanoseconds: 100_000_000)

        var receivedChange = false
        let task = Task {
            for await _ in sut.changes {
                receivedChange = true
                break
            }
        }

        try "updated after stop".write(to: fileURL, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 700_000_000)
        task.cancel()

        XCTAssertFalse(receivedChange, "No changes should be emitted after stopWatching")
    }

    func test_startWatching_replacesExistingWatch() async throws {
        let fileURL = try makeFile(name: "replace_test")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let proto1 = ProtoFile(id: UUID(), name: fileURL.lastPathComponent, path: fileURL, services: [])
        let proto2 = ProtoFile(id: UUID(), name: fileURL.lastPathComponent, path: fileURL, services: [])

        sut.startWatching(proto1)
        try await Task.sleep(nanoseconds: 50_000_000)
        sut.startWatching(proto2)
        try await Task.sleep(nanoseconds: 100_000_000)

        let expectation = XCTestExpectation(description: "emit after replacement")
        var received: [ProtoFile] = []
        let task = Task {
            for await change in sut.changes {
                received.append(change)
                if received.count == 1 { expectation.fulfill() }
            }
        }

        try "updated".write(to: fileURL, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 2.0)
        try await Task.sleep(nanoseconds: 500_000_000)
        task.cancel()

        XCTAssertEqual(received.count, 1, "Replacing watch must not cause duplicate emissions")
        XCTAssertEqual(received.first?.id, proto2.id, "Must emit the latest registered ProtoFile")
    }
}
