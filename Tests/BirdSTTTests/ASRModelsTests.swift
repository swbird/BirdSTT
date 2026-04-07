import Testing
import Foundation
@testable import BirdSTT

@Suite("ASR Models Tests")
struct ASRModelsTests {
    @Test("encodes client request to correct JSON structure")
    func encodesClientRequest() throws {
        let request = ASRClientRequest(
            user: ASRUser(uid: "test-uid"),
            audio: ASRAudioConfig(
                format: "pcm",
                rate: 16000,
                bits: 16,
                channel: 1,
                language: "zh-CN"
            ),
            request: ASRRequestConfig(
                model_name: "bigmodel",
                enable_itn: true,
                enable_punc: true
            )
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let user = json["user"] as! [String: Any]
        #expect(user["uid"] as! String == "test-uid")

        let audio = json["audio"] as! [String: Any]
        #expect(audio["format"] as! String == "pcm")
        #expect(audio["rate"] as! Int == 16000)
        #expect(audio["bits"] as! Int == 16)
        #expect(audio["channel"] as! Int == 1)
        #expect(audio["language"] as! String == "zh-CN")

        let req = json["request"] as! [String: Any]
        #expect(req["model_name"] as! String == "bigmodel")
    }

    @Test("decodes server response with result")
    func decodesServerResponse() throws {
        let json = """
        {"result": {"text": "你好World"}, "audio_info": {"duration": 3000}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ASRResponse.self, from: json)
        #expect(response.result?.text == "你好World")
        #expect(response.audio_info?.duration == 3000)
    }

    @Test("decodes response with utterances")
    func decodesUtterances() throws {
        let json = """
        {"result": {"text": "你好", "utterances": [{"text": "你好", "definite": true, "start_time": 0, "end_time": 1000}]}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ASRResponse.self, from: json)
        #expect(response.result?.utterances?.count == 1)
        #expect(response.result?.utterances?.first?.definite == true)
    }

    @Test("builds full client request binary message")
    func buildsFullClientRequest() {
        let payload = "{\"test\":true}".data(using: .utf8)!
        let message = ASRProtocol.buildFullClientRequest(payload: payload)

        // Header: 4 bytes + payload size: 4 bytes + payload
        #expect(message.count == 4 + 4 + payload.count)
        #expect(message[0] == 0x11) // version 1, header size 1
        #expect(message[1] == 0x10) // full client request, no sequence
        #expect(message[2] == 0x10) // JSON serialization, no compression
        #expect(message[3] == 0x00) // reserved
    }

    @Test("builds audio request binary message")
    func buildsAudioRequest() {
        let audio = Data([0x01, 0x02, 0x03, 0x04])
        let message = ASRProtocol.buildAudioRequest(audioData: audio)

        #expect(message.count == 4 + 4 + 4)
        #expect(message[1] == 0x20) // audio only request, no sequence
        #expect(message[2] == 0x00) // no serialization, no compression
    }

    @Test("builds last audio request (negative packet)")
    func buildsLastAudioRequest() {
        let message = ASRProtocol.buildLastAudioRequest()

        #expect(message.count == 8) // header + size only, no payload
        #expect(message[1] == 0x22) // audio only request, last packet flag
    }
}
