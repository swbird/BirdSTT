import AppKit
import Combine
import SwiftUI

enum AppState: Equatable {
    case idle
    case connecting
    case recording
    case stopping
    case done
    case error(String)

    func canTransition(to next: AppState) -> Bool {
        switch (self, next) {
        case (.idle, .connecting):       return true
        case (.connecting, .recording):  return true
        case (.connecting, .error):      return true
        case (.recording, .stopping):    return true
        case (.recording, .error):       return true
        case (.stopping, .done):         return true
        case (.stopping, .error):        return true
        case (.done, .idle):             return true
        case (.error, .idle):            return true
        default:                         return false
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @Published private(set) var state: AppState = .idle

    let settings = Settings()
    private lazy var hotkeyManager = HotkeyManager()
    private let audioService = AudioCaptureService()
    private lazy var asrService = DoubaoASRService(settings: settings)
    let transcriptProcessor = TranscriptProcessor()
    private let windowController = FloatingWindowController()
    private let settingsWindowController = SettingsWindowController()
    private var cancellables = Set<AnyCancellable>()

    func transition(to newState: AppState) {
        guard state.canTransition(to: newState) else {
            print("Invalid transition: \(state) → \(newState)")
            return
        }
        state = newState
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApp()
    }

    private func setupApp() {
        guard hotkeyManager.start() else {
            print("Failed to start hotkey manager")
            return
        }

        hotkeyManager.triggered
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleHotkeyTrigger() }
            .store(in: &cancellables)

        asrService.$isFinal
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleFinalResult() }
            .store(in: &cancellables)

        asrService.error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] err in self?.handleError(err) }
            .store(in: &cancellables)

        asrService.resultReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.transcriptProcessor.process(utterances: result.utterances, fullText: result.fullText)
            }
            .store(in: &cancellables)

        transcriptProcessor.stopRequested
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.stopRecording() }
            .store(in: &cancellables)

        if !settings.isConfigured {
            settingsWindowController.show(settings: settings) { [weak self] in
                self?.settingsWindowController.close()
                print("BirdSTT ready. Press Ctrl+Shift+B to start/stop recording.")
            }
        } else {
            print("BirdSTT ready. Press Ctrl+Shift+B to start/stop recording.")
        }
    }

    private func handleHotkeyTrigger() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        default:
            break
        }
    }

    private func startRecording() {
        guard settings.isConfigured else {
            settingsWindowController.show(settings: settings) { [weak self] in
                self?.settingsWindowController.close()
            }
            return
        }

        transition(to: .connecting)
        asrService.reset()
        transcriptProcessor.reset()

        let contentView = FloatingContentView(
            transcriptProcessor: transcriptProcessor,
            audioLevel: audioService.audioLevel.eraseToAnyPublisher(),
            statePublisher: $state.eraseToAnyPublisher(),
            onStop: { [weak self] in self?.stopRecording() }
        )
        windowController.show(content: contentView)

        do {
            try audioService.start()
        } catch {
            handleError(error)
            return
        }

        asrService.connect(audioStream: audioService.audioChunk)
        transition(to: .recording)
    }

    private func stopRecording() {
        guard state == .recording else { return }
        transition(to: .stopping)

        audioService.stop()
        asrService.sendEndSignal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, self.state == .stopping else { return }
            self.handleFinalResult()
        }
    }

    private func handleFinalResult() {
        guard state == .stopping || state == .recording else { return }

        let text = transcriptProcessor.displayText.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            showError("未检测到语音")
            return
        }

        transition(to: .done)
        ClipboardService.copy(text)

        asrService.disconnect()

        DispatchQueue.main.asyncAfter(deadline: .now() + settings.windowDismissDelay) { [weak self] in
            self?.windowController.dismiss()
            self?.transition(to: .idle)
        }
    }

    private func handleError(_ error: Error) {
        // Ignore errors if we're already done or idle
        guard state == .stopping || state == .recording || state == .connecting else { return }

        let text = transcriptProcessor.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            handleFinalResult()
            return
        }

        let msg = error.localizedDescription
        showError(msg)
    }

    private func showError(_ message: String) {
        audioService.stop()
        asrService.disconnect()

        if state.canTransition(to: .error(message)) {
            transition(to: .error(message))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.windowController.dismiss()
            if self.state.canTransition(to: .idle) {
                self.transition(to: .idle)
            }
        }
    }
}
