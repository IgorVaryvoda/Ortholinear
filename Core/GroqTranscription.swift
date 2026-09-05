import Foundation

enum GroqTranscription {
    static let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    static let model = "whisper-large-v3-turbo"

    static func multipart(audio: Data, language: String?, boundary: String) -> Data {
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        var fields = [("model", model), ("response_format", "json"), ("temperature", "0")]
        if let language, ["uk", "en"].contains(language) { fields.append(("language", language)) }
        for (name, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n")
        body.append(audio)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    static func transcript(from data: Data, status: Int) throws -> String {
        switch status {
        case 200..<300: break
        case 401, 403: throw Failure.message("Groq rejected the API key. Check your key and account permissions.")
        case 429: throw Failure.message("Groq’s rate or usage limit was reached. Check your account and try again shortly.")
        default: throw Failure.message("Groq could not transcribe this recording (HTTP \(status)). Try again.")
        }
        struct Response: Decodable { let text: String }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw Failure.message("Groq returned an unreadable response. Try again.")
        }
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.message("No speech was recognized. Try recording again.") }
        return text
    }

    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let text) = self { text } else { nil } }
    }
}

struct VoiceTranscript: Codable {
    var id = UUID()
    let text: String
    var createdAt = Date()
    func isAvailable(at date: Date = Date(), consumedID: UUID?) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && id != consumedID
            && date.timeIntervalSince(createdAt) >= 0 && date.timeIntervalSince(createdAt) < 600
    }
}
