import Foundation
import Combine

final class DoubaoASRService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var transcript: String = ""
    @Published var isFinal: Bool = false
    let error = PassthroughSubject<Error, Never>()
    let resultReceived = PassthroughSubject<(utterances: [ASRUtterance]?, fullText: String), Never>()

    private let settings: Settings
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioSubscription: AnyCancellable?
    private var urlSession: URLSession?
    private let wsURL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"

    init(settings: Settings) {
        self.settings = settings
        super.init()
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    }

    func connect(audioStream: PassthroughSubject<Data, Never>) {
        guard let url = URL(string: wsURL) else { return }

        var request = URLRequest(url: url)
        request.setValue(settings.doubaoAppId, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(settings.doubaoAccessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(settings.doubaoResourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession!.webSocketTask(with: request)
        webSocketTask?.resume()

        sendFullClientRequest()
        receiveLoop()
        subscribeToAudio(audioStream)
    }

    func sendEndSignal() {
        let lastPacket = ASRProtocol.buildLastAudioRequest()
        let message = URLSessionWebSocketTask.Message.data(lastPacket)
        webSocketTask?.send(message) { [weak self] err in
            if let err = err {
                self?.error.send(err)
            }
        }
    }

    func disconnect() {
        audioSubscription?.cancel()
        audioSubscription = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    func reset() {
        transcript = ""
        isFinal = false
    }

    // MARK: - Private

    private func sendFullClientRequest() {
        let clientRequest = ASRClientRequest(
            user: ASRUser(uid: "birdSTT-\(UUID().uuidString.prefix(8))"),
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

        guard let jsonData = try? JSONEncoder().encode(clientRequest) else { return }

        let binaryMessage = ASRProtocol.buildFullClientRequest(payload: jsonData)
        let message = URLSessionWebSocketTask.Message.data(binaryMessage)
        webSocketTask?.send(message) { [weak self] err in
            if let err = err {
                self?.error.send(err)
            }
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveLoop()
            case .failure(let err):
                self.error.send(err)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return }
            data = d
        @unknown default:
            return
        }

        guard let serverMessage = ASRProtocol.parseServerResponse(data) else { return }

        switch serverMessage {
        case .response(let response):
            if let result = response.result {
                DispatchQueue.main.async {
                    self.transcript = result.text
                    self.resultReceived.send((utterances: result.utterances, fullText: result.text))

                    let allDefinite = result.utterances?.allSatisfy { $0.definite == true } ?? false
                    if allDefinite && !(result.utterances?.isEmpty ?? true) {
                        self.isFinal = true
                    }
                }
            }

        case .error(let code, let message):
            DispatchQueue.main.async {
                self.error.send(NSError(
                    domain: "DoubaoASR",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            }
        }
    }

    private func subscribeToAudio(_ audioStream: PassthroughSubject<Data, Never>) {
        audioSubscription = audioStream.sink { [weak self] chunk in
            let binaryMessage = ASRProtocol.buildAudioRequest(audioData: chunk)
            let message = URLSessionWebSocketTask.Message.data(binaryMessage)
            self?.webSocketTask?.send(message) { err in
                if let err = err {
                    self?.error.send(err)
                }
            }
        }
    }
}
