import XCTest
@testable import OrtholinearCore

final class VoiceInputTests: XCTestCase {
    func testMultipartPreservesAudioAndUsesTurboWithoutTypingContext() {
        let audio = Data([0, 255, 10, 13, 128])
        let body = GroqTranscription.multipart(audio: audio, language: "uk", boundary: "test-boundary")
        XCTAssertNotNil(body.range(of: audio))
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("whisper-large-v3-turbo"))
        XCTAssertTrue(text.contains("name=\"language\"\r\n\r\nuk\r\n"))
        XCTAssertTrue(text.hasSuffix("--test-boundary--\r\n"))
        XCTAssertFalse(text.contains("name=\"prompt\""))
        let automatic = GroqTranscription.multipart(audio: audio, language: nil, boundary: "test")
        XCTAssertFalse(String(decoding: automatic, as: UTF8.self).contains("name=\"language\""))
    }
    func testTranscriptionResponsesPreserveLanguageAndRejectFailures() throws {
        let data = Data(#"{"text":"  Привіт, Ґанно! Hello.\n"}"#.utf8)
        XCTAssertEqual(try GroqTranscription.transcript(from: data, status: 200), "Привіт, Ґанно! Hello.")
        for status in [401, 403, 429, 500] { XCTAssertThrowsError(try GroqTranscription.transcript(from: data, status: status)) }
        for invalid in [#"{"text":"  "}"#, "{}", "not json"] {
            XCTAssertThrowsError(try GroqTranscription.transcript(from: Data(invalid.utf8), status: 200))
        }
    }
    func testHandoffExpiresAndCannotBeInsertedTwice() {
        let date = Date()
        let transcript = VoiceTranscript(text: "Текст", createdAt: date)
        XCTAssertTrue(transcript.isAvailable(at: date, consumedID: nil))
        XCTAssertFalse(transcript.isAvailable(at: date, consumedID: transcript.id))
        XCTAssertFalse(transcript.isAvailable(at: date.addingTimeInterval(600), consumedID: nil))
        XCTAssertFalse(transcript.isAvailable(at: date.addingTimeInterval(-1), consumedID: nil))
        XCTAssertFalse(VoiceTranscript(text: "\n").isAvailable(consumedID: nil))
    }
}
