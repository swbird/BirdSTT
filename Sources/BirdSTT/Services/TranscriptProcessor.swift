import Foundation
import Combine

/// Processes ASR utterances, detects voice commands, and maintains clean display text.
final class TranscriptProcessor: ObservableObject {
    @Published var displayText: String = ""
    @Published var pendingText: String = ""
    @Published var lastCommand: String? = nil
    let stopRequested = PassthroughSubject<Void, Never>()

    /// The full text shown in UI: confirmed text + pending (non-definite) text
    var fullDisplayText: String {
        if pendingText.isEmpty { return displayText }
        return displayText + pendingText
    }

    private var undoStack: [String] = []
    private var processedUtteranceCount: Int = 0

    static let commands: [(name: String, description: String)] = [
        ("删掉所有 / 全部删除", "清空所有文字"),
        ("删掉这一行", "删除最后一行"),
        ("删除X个字", "从末尾删除X个字符"),
        ("换行", "插入换行符"),
        ("撤销", "撤销上一步操作"),
        ("结束录制 / 结束语音", "停止录音并复制"),
    ]

    func reset() {
        displayText = ""
        pendingText = ""
        lastCommand = nil
        undoStack = []
        processedUtteranceCount = 0
    }

    /// Process ASR result: check definite utterances for commands, accumulate text.
    func process(utterances: [ASRUtterance]?, fullText: String) {
        guard let utterances = utterances else {
            pendingText = fullText
            return
        }

        // Find the boundary between definite and non-definite
        var newDefiniteTexts: [String] = []
        var pending = ""

        for (i, utt) in utterances.enumerated() {
            if utt.definite == true {
                // Only process newly definite utterances
                if i >= processedUtteranceCount {
                    newDefiniteTexts.append(utt.text)
                }
            } else {
                pending += utt.text
            }
        }

        // Update pending (non-definite) text for live preview
        pendingText = pending

        // Process each new definite utterance
        for text in newDefiniteTexts {
            processedUtteranceCount += 1
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let command = matchCommand(trimmed) {
                executeCommand(command, rawText: trimmed)
            } else {
                // Normal text — append to display
                saveUndo()
                displayText += text
            }
        }
    }

    // MARK: - Command Matching

    private enum VoiceCommand {
        case clearAll
        case deleteLine
        case deleteChars(Int)
        case newLine
        case undo
        case stopSession
    }

    private func matchCommand(_ text: String) -> VoiceCommand? {
        let t = text.replacingOccurrences(of: "。", with: "")
                     .replacingOccurrences(of: "，", with: "")
                     .replacingOccurrences(of: " ", with: "")
                     .trimmingCharacters(in: .whitespacesAndNewlines)

        // 清空 / 删掉所有 / 全部删除 / 全部清空
        if t == "删掉所有" || t == "全部删除" || t == "清空" || t == "全部清空" || t == "删除所有" {
            return .clearAll
        }

        // 删掉这一行 / 删除这一行 / 删除上一行
        if t == "删掉这一行" || t == "删除这一行" || t == "删掉上一行" || t == "删除上一行" {
            return .deleteLine
        }

        // 换行 / 另起一行
        if t == "换行" || t == "另起一行" {
            return .newLine
        }

        // 撤销 / 回退
        if t == "撤销" || t == "回退" {
            return .undo
        }

        // 结束会话 / 结束语音 / 结束录制
        if t == "结束会话" || t == "结束语音" || t == "结束录制" || t == "停止录音" || t == "停止录制" {
            return .stopSession
        }

        // 删除X个字 / 删掉X个字符
        if let n = parseDeleteChars(t) {
            return .deleteChars(n)
        }

        return nil
    }

    private func parseDeleteChars(_ text: String) -> Int? {
        // Match patterns: 删除三个字, 删掉5个字符, 删除十二个字
        let patterns = ["删除", "删掉"]
        for prefix in patterns {
            guard text.hasPrefix(prefix) else { continue }
            let rest = String(text.dropFirst(prefix.count))
            // Extract number part (before 个字/个字符)
            let suffixes = ["个字符", "个字"]
            for suffix in suffixes {
                guard rest.hasSuffix(suffix) else { continue }
                let numStr = String(rest.dropLast(suffix.count))
                if let n = parseChineseNumber(numStr), n > 0 {
                    return n
                }
            }
        }
        return nil
    }

    private func parseChineseNumber(_ s: String) -> Int? {
        // Try Arabic numeral first
        if let n = Int(s) { return n }

        // Chinese number mapping
        let digitMap: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
        ]

        // Simple cases: single digit
        if s.count == 1, let d = digitMap[s.first!] {
            return d
        }

        // 十, 十X, X十, X十X
        if s.contains("十") {
            let parts = s.split(separator: "十", maxSplits: 1, omittingEmptySubsequences: false)
            let tens: Int
            let ones: Int

            if parts[0].isEmpty {
                tens = 1 // 十 = 10
            } else if parts[0].count == 1, let d = digitMap[parts[0].first!] {
                tens = d
            } else {
                return nil
            }

            if parts.count < 2 || parts[1].isEmpty {
                ones = 0
            } else if parts[1].count == 1, let d = digitMap[parts[1].first!] {
                ones = d
            } else {
                return nil
            }

            return tens * 10 + ones
        }

        return nil
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: VoiceCommand, rawText: String) {
        switch command {
        case .clearAll:
            saveUndo()
            displayText = ""
            lastCommand = "已清空所有文字"

        case .deleteLine:
            saveUndo()
            deleteLastLine()
            lastCommand = "已删除最后一行"

        case .deleteChars(let n):
            saveUndo()
            let actual = min(n, displayText.count)
            if actual > 0 {
                displayText = String(displayText.dropLast(actual))
            }
            lastCommand = "已删除\(actual)个字符"

        case .newLine:
            saveUndo()
            displayText += "\n"
            lastCommand = "已换行"

        case .undo:
            if let previous = undoStack.popLast() {
                displayText = previous
                lastCommand = "已撤销"
            } else {
                lastCommand = "无可撤销内容"
            }

        case .stopSession:
            lastCommand = "正在结束..."
            stopRequested.send()
        }

        // Clear command feedback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.lastCommand = nil
        }
    }

    private func deleteLastLine() {
        guard !displayText.isEmpty else { return }
        if let lastNewline = displayText.lastIndex(of: "\n") {
            displayText = String(displayText[displayText.startIndex...lastNewline])
        } else {
            // Only one line — clear everything
            displayText = ""
        }
    }

    private func saveUndo() {
        undoStack.append(displayText)
        // Keep undo stack manageable
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
