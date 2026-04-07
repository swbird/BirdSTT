import SwiftUI
import Combine

struct FloatingContentView: View {
    @ObservedObject var transcriptProcessor: TranscriptProcessor
    let audioLevel: AnyPublisher<Float, Never>
    let statePublisher: AnyPublisher<AppState, Never>
    let onStop: () -> Void

    @State private var state: AppState = .connecting
    @State private var currentLevel: Float = 0
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var showCommands: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(state == .recording ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: state == .recording)

                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()

                // Command feedback
                if let cmd = transcriptProcessor.lastCommand {
                    Text(cmd)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green.opacity(0.8))
                        .transition(.opacity)
                }

                // Commands toggle
                Button(action: { withAnimation { showCommands.toggle() } }) {
                    Image(systemName: "command")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(showCommands ? 0.8 : 0.35))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)

                Text(formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .monospacedDigit()
            }
            .padding(.bottom, 10)

            // Commands panel
            if showCommands {
                commandsPanel
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Waveform
            WaveformView(audioLevel: currentLevel)
                .padding(.bottom, 12)

            // Transcript
            TranscriptView(
                text: transcriptProcessor.fullDisplayText,
                isRecording: state == .recording
            )
            .padding(.bottom, 8)

            // Voice command hints
            if state == .recording {
                Text("语音指令: 删掉所有 | 删掉这一行 | 删除X个字 | 换行 | 撤销 | 结束录制")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.bottom, 10)
            }

            // Bottom bar
            if state == .recording || state == .stopping {
                Button(action: onStop) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red)
                            .frame(width: 14, height: 14)
                        Text("停止 (Ctrl+Shift+B)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.99, green: 0.65, blue: 0.65))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if state == .done {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已复制到剪贴板")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if case .error(let msg) = state {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: 420)
        .onReceive(audioLevel) { level in
            currentLevel = level
        }
        .onReceive(statePublisher) { newState in
            state = newState
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var commandsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(TranscriptProcessor.commands, id: \.name) { cmd in
                HStack(spacing: 8) {
                    Text(cmd.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.purple.opacity(0.9))
                    Text(cmd.description)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        switch state {
        case .connecting: return "连接中..."
        case .recording: return "录音中"
        case .stopping: return "处理中..."
        case .done: return "完成"
        case .error: return "错误"
        default: return ""
        }
    }

    private var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
