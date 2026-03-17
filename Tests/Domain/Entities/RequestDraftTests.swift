import XCTest
@testable import TrueRPCMini

final class RequestDraftTests: XCTestCase {
    func test_requestDraft_defaultsTLSToPlaintext() {
        let draft = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: Method(
                name: "SayHello",
                inputType: "HelloRequest",
                outputType: "HelloReply"))

        XCTAssertEqual(draft.tlsConfiguration, TLSConfiguration.defaults)
        XCTAssertFalse(draft.tlsConfiguration.isTLSEnabled)
    }

    func test_requestDraft_equalityRespectsTLSConfiguration() {
        let method = Method(
            name: "SayHello",
            inputType: "HelloRequest",
            outputType: "HelloReply")

        let plaintext = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method,
            tlsConfiguration: TLSConfiguration.defaults)

        let tls = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method,
            tlsConfiguration: TLSConfiguration(isTLSEnabled: true))

        XCTAssertNotEqual(plaintext, tls)
        XCTAssertEqual(plaintext, plaintext)
        XCTAssertEqual(tls, tls)
    }
}
