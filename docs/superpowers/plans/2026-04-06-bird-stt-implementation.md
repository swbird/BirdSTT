# BirdSTT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS native speech-to-text floating window app activated by global hotkey (Space+B), using Doubao streaming ASR API.

**Architecture:** Single-process SwiftUI+AppKit hybrid app. Modules communicate via Combine Publishers. AppDelegate orchestrates HotkeyManager, AudioCaptureService, DoubaoASRService, and FloatingWindowController. Built with Swift Package Manager, bundled into .app via shell script.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSPanel, CGEvent), AVAudioEngine, URLSessionWebSocketTask, Combine

**Note:** System has Swift 6.0.3 command line tools only (no full Xcode IDE). We use Swift Package Manager for building and a shell script to create the .app bundle.

---

## File Map

```
bird-Speech-to-Text/
├── Package.swift                          # SPM manifest, macOS 14+ executable target
├── Sources/
│   └── BirdSTT/
│       ├── App/
│       │   ├── main.swift                 # App entry point, NSApplication bootstrap
│       │   └── AppDelegate.swift          # Orchestrates all managers, state machine
│       ├── Hotkey/
│       │   └── HotkeyManager.swift        # CGEvent tap for Space+B with anti-misfire
│       ├── Audio/
│       │   └── AudioCaptureService.swift   # AVAudioEngine → PCM 16-bit 16kHz mono
│       ├── ASR/
│       │   ├── DoubaoASRService.swift      # WebSocket streaming to Doubao API
│       │   └── ASRModels.swift             # JSON request/response Codable models
│       ├── UI/
│       │   ├── FloatingWindowController.swift  # NSPanel setup: borderless, floating, blur
│       │   ├── FloatingContentView.swift       # SwiftUI root container
│       │   ├── WaveformView.swift              # Animated audio bars
│       │   └── TranscriptView.swift            # Scrollable text preview
│       ├── Services/
│       │   └── ClipboardService.swift      # NSPasteboard wrapper
│       └── Config/
│           └── Settings.swift              # UserDefaults-backed configuration
├── Tests/
│   └── BirdSTTTests/
│       ├── ASRModelsTests.swift            # JSON parsing tests
│       ├── SettingsTests.swift             # Config defaults tests
│       └── AppStateTests.swift             # State machine transition tests
├── Resources/
│   └── Info.plist                          # App bundle metadata + permissions
├── scripts/
│   └── bundle.sh                          # Build + create .app bundle
└── docs/
    └── superpowers/
        ├── specs/2026-04-06-bird-stt-design.md
        └── plans/2026-04-06-bird-stt-implementation.md
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/BirdSTT/App/main.swift`
- Create: `Resources/Info.plist`
- Create: `scripts/bundle.sh`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BirdSTT",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BirdSTT",
            path: "Sources/BirdSTT",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .testTarget(
            name: "BirdSTTTests",
            dependencies: ["BirdSTT"],
            path: "Tests/BirdSTTTests"
        ),
    ]
)
```

- [ ] **Step 2: Create minimal main.swift**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // LSUIElement equivalent: no Dock icon
app.run()
```

- [ ] **Step 3: Create placeholder AppDelegate.swift**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("BirdSTT launched")
    }
}
```

- [ ] **Step 4: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>BirdSTT</string>
    <key>CFBundleIdentifier</key>
    <string>com.bird.stt</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>BirdSTT</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>BirdSTT needs microphone access for speech-to-text recognition.</string>
</dict>
</plist>
```

- [ ] **Step 5: Create bundle.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BirdSTT"
BUILD_DIR="$PROJECT_DIR/.build/release"
BUNDLE_DIR="$PROJECT_DIR/build/$APP_NAME.app"

cd "$PROJECT_DIR"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"
cp "$PROJECT_DIR/Resources/Info.plist" "$BUNDLE_DIR/Contents/"

echo "Bundle created at: $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
```

- [ ] **Step 6: Build to verify scaffolding**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds, prints "Build complete!"

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/ Resources/ scripts/ Tests/
git commit -m "feat: project scaffolding with SPM and app bundle script"
```

---

### Task 2: Settings & Configuration

**Files:**
- Create: `Sources/BirdSTT/Config/Settings.swift`
- Create: `Tests/BirdSTTTests/SettingsTests.swift`

- [ ] **Step 1: Write Settings tests**

```swift
import Testing
@testable import BirdSTT

@Suite("Settings Tests")
struct SettingsTests {
    @Test("default values are correct")
    func defaultValues() {
        let defaults = UserDefaults(suiteName: "test.settings")!
        defaults.removePersistentDomain(forName: "test.settings")
        let settings = Settings(defaults: defaults)

        #expect(settings.doubaoAppId == "")
        #expect(settings.doubaoAccessToken == "")
        #expect(settings.spaceHoldThreshold == 150)
        #expect(settings.hotkeyCooldown == 500)
        #expect(settings.windowDismissDelay == 1.5)
    }

    @Test("persists values to UserDefaults")
    func persistsValues() {
        let defaults = UserDefaults(suiteName: "test.settings.persist")!
        defaults.removePersistentDomain(forName: "test.settings.persist")
        let settings = Settings(defaults: defaults)

        settings.doubaoAppId = "test-app-id"
        settings.doubaoAccessToken = "test-token"

        let settings2 = Settings(defaults: defaults)
        #expect(settings2.doubaoAppId == "test-app-id")
        #expect(settings2.doubaoAccessToken == "test-token")
    }

    @Test("isConfigured checks both fields")
    func isConfigured() {
        let defaults = UserDefaults(suiteName: "test.settings.configured")!
        defaults.removePersistentDomain(forName: "test.settings.configured")
        let settings = Settings(defaults: defaults)

        #expect(!settings.isConfigured)

        settings.doubaoAppId = "app"
        #expect(!settings.isConfigured)

        settings.doubaoAccessToken = "token"
        #expect(settings.isConfigured)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsTests 2>&1 | tail -10`
Expected: Compilation error — `Settings` not defined

- [ ] **Step 3: Implement Settings**

```swift
import Foundation

final class Settings: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var doubaoAppId: String {
        get { defaults.string(forKey: "doubaoAppId") ?? "" }
        set { defaults.set(newValue, forKey: "doubaoAppId"); objectWillChange.send() }
    }

    var doubaoAccessToken: String {
        get { defaults.string(forKey: "doubaoAccessToken") ?? "" }
        set { defaults.set(newValue, forKey: "doubaoAccessToken"); objectWillChange.send() }
    }

    var spaceHoldThreshold: Int {
        get {
            let val = defaults.integer(forKey: "spaceHoldThreshold")
            return val > 0 ? val : 150
        }
        set { defaults.set(newValue, forKey: "spaceHoldThreshold") }
    }

    var hotkeyCooldown: Int {
        get {
            let val = defaults.integer(forKey: "hotkeyCooldown")
            return val > 0 ? val : 500
        }
        set { defaults.set(newValue, forKey: "hotkeyCooldown") }
    }

    var windowDismissDelay: Double {
        get {
            let val = defaults.double(forKey: "windowDismissDelay")
            return val > 0 ? val : 1.5
        }
        set { defaults.set(newValue, forKey: "windowDismissDelay") }
    }

    var isConfigured: Bool {
        !doubaoAppId.isEmpty && !doubaoAccessToken.isEmpty
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SettingsTests 2>&1 | tail -10`
Expected: All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/BirdSTT/Config/Settings.swift Tests/BirdSTTTests/SettingsTests.swift
git commit -m "feat: Settings with UserDefaults persistence and defaults"
```

---

### Task 3: ASR Data Models

**Files:**
- Create: `Sources/BirdSTT/ASR/ASRModels.swift`
- Create: `Tests/BirdSTTTests/ASRModelsTests.swift`

- [ ] **Step 1: Write ASRModels tests**

```swift
import Testing
import Foundation
@testable import BirdSTT

@Suite("ASR Models Tests")
struct ASRModelsTests {
    @Test("encodes handshake request to JSON")
    func encodesHandshake() throws {
        let request = ASRHandshakeRequest(
            appId: "test-app",
            namespace: "SeedASR",
            format: "pcm",
            rate: 16000,
            bits: 16,
            channel: 1,
            language: "zh-CN,en-US"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let header = json["header"] as! [String: Any]
        #expect(header["appid"] as! String == "test-app")
        #expect(header["namespace"] as! String == "SeedASR")

        let payload = json["payload"] as! [String: Any]
        let audioConfig = payload["audio_config"] as! [String: Any]
        #expect(audioConfig["format"] as! String == "pcm")
        #expect(audioConfig["rate"] as! Int == 16000)
        #expect(payload["language"] as! String == "zh-CN,en-US")
    }

    @Test("decodes partial result")
    func decodesPartialResult() throws {
        let json = """
        {"text": "你好world", "is_final": false}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ASRResult.self, from: json)
        #expect(result.text == "你好world")
        #expect(result.isFinal == false)
    }

    @Test("decodes final result")
    func decodesFinalResult() throws {
        let json = """
        {"text": "你好World完整句子", "is_final": true}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ASRResult.self, from: json)
        #expect(result.text == "你好World完整句子")
        #expect(result.isFinal == true)
    }

    @Test("decodes result with missing is_final defaults to false")
    func decodesResultMissingIsFinal() throws {
        let json = """
        {"text": "partial"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ASRResult.self, from: json)
        #expect(result.text == "partial")
        #expect(result.isFinal == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ASRModelsTests 2>&1 | tail -10`
Expected: Compilation error — `ASRHandshakeRequest`, `ASRResult` not defined

- [ ] **Step 3: Implement ASRModels**

```swift
import Foundation

struct ASRHandshakeRequest: Encodable {
    let appId: String
    let namespace: String
    let format: String
    let rate: Int
    let bits: Int
    let channel: Int
    let language: String

    enum CodingKeys: String, CodingKey {
        case header, payload
    }

    enum HeaderKeys: String, CodingKey {
        case appid, namespace
    }

    enum PayloadKeys: String, CodingKey {
        case audio_config, language
    }

    enum AudioConfigKeys: String, CodingKey {
        case format, rate, bits, channel
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        var header = container.nestedContainer(keyedBy: HeaderKeys.self, forKey: .header)
        try header.encode(appId, forKey: .appid)
        try header.encode(namespace, forKey: .namespace)

        var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        try payload.encode(language, forKey: .language)

        var audioConfig = payload.nestedContainer(keyedBy: AudioConfigKeys.self, forKey: .audio_config)
        try audioConfig.encode(format, forKey: .format)
        try audioConfig.encode(rate, forKey: .rate)
        try audioConfig.encode(bits, forKey: .bits)
        try audioConfig.encode(channel, forKey: .channel)
    }
}

struct ASRResult: Decodable {
    let text: String
    let isFinal: Bool

    enum CodingKeys: String, CodingKey {
        case text
        case isFinal = "is_final"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        isFinal = try container.decodeIfPresent(Bool.self, forKey: .isFinal) ?? false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ASRModelsTests 2>&1 | tail -10`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/BirdSTT/ASR/ASRModels.swift Tests/BirdSTTTests/ASRModelsTests.swift
git commit -m "feat: ASR Codable models for Doubao handshake and result parsing"
```

---

### Task 4: App State Machine

**Files:**
- Create: `Tests/BirdSTTTests/AppStateTests.swift`
- Modify: `Sources/BirdSTT/App/AppDelegate.swift`

- [ ] **Step 1: Write state machine tests**

```swift
import Testing
@testable import BirdSTT

@Suite("App State Tests")
struct AppStateTests {
    @Test("initial state is idle")
    func initialState() {
        #expect(AppState.idle == AppState.idle)
    }

    @Test("all states are equatable")
    func statesEquatable() {
        let states: [AppState] = [.idle, .connecting, .recording, .stopping, .done, .error("test")]
        for (i, a) in states.enumerated() {
            for (j, b) in states.enumerated() {
                if i == j {
                    #expect(a == b)
                } else {
                    #expect(a != b)
                }
            }
        }
    }

    @Test("valid transitions")
    func validTransitions() {
        #expect(AppState.idle.canTransition(to: .connecting))
        #expect(AppState.connecting.canTransition(to: .recording))
        #expect(AppState.connecting.canTransition(to: .error("fail")))
        #expect(AppState.recording.canTransition(to: .stopping))
        #expect(AppState.stopping.canTransition(to: .done))
        #expect(AppState.stopping.canTransition(to: .error("fail")))
        #expect(AppState.done.canTransition(to: .idle))
        #expect(AppState.error("x").canTransition(to: .idle))
    }

    @Test("invalid transitions")
    func invalidTransitions() {
        #expect(!AppState.idle.canTransition(to: .recording))
        #expect(!AppState.idle.canTransition(to: .done))
        #expect(!AppState.recording.canTransition(to: .idle))
        #expect(!AppState.done.canTransition(to: .recording))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppStateTests 2>&1 | tail -10`
Expected: Compilation error — `AppState` not defined

- [ ] **Step 3: Add AppState enum to AppDelegate.swift**

Replace the entire `Sources/BirdSTT/App/AppDelegate.swift` with:

```swift
import AppKit
import Combine

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
    private var cancellables = Set<AnyCancellable>()

    func transition(to newState: AppState) {
        guard state.canTransition(to: newState) else {
            print("Invalid transition: \(state) → \(newState)")
            return
        }
        state = newState
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("BirdSTT launched")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AppStateTests 2>&1 | tail -10`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/BirdSTT/App/AppDelegate.swift Tests/BirdSTTTests/AppStateTests.swift
git commit -m "feat: AppState enum with validated transitions"
```

---

### Task 5: ClipboardService

**Files:**
- Create: `Sources/BirdSTT/Services/ClipboardService.swift`

- [ ] **Step 1: Implement ClipboardService**

```swift
import AppKit

enum ClipboardService {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/BirdSTT/Services/ClipboardService.swift
git commit -m "feat: ClipboardService for copying text to pasteboard"
```

---

### Task 6: HotkeyManager

**Files:**
- Create: `Sources/BirdSTT/Hotkey/HotkeyManager.swift`

- [ ] **Step 1: Implement HotkeyManager**

```swift
import CoreGraphics
import Combine
import Foundation

final class HotkeyManager {
    let triggered = PassthroughSubject<Void, Never>()

    private let spaceHoldThreshold: Int // ms
    private let cooldown: Int // ms

    private var spaceHeld = false
    private var spaceDownTime: UInt64 = 0
    private var lastTriggerTime: UInt64 = 0
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(spaceHoldThreshold: Int = 150, cooldown: Int = 500) {
        self.spaceHoldThreshold = spaceHoldThreshold
        self.cooldown = cooldown
    }

    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: userInfo
        ) else {
            print("Failed to create event tap. Check Accessibility permissions.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleEvent(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let spaceKeyCode: Int64 = 49
        let bKeyCode: Int64 = 11

        if type == .keyDown && keyCode == spaceKeyCode {
            if !spaceHeld {
                spaceHeld = true
                spaceDownTime = mach_absolute_time()
            }
            return Unmanaged.passUnretained(event) // pass Space through normally
        }

        if type == .keyUp && keyCode == spaceKeyCode {
            spaceHeld = false
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown && keyCode == bKeyCode && spaceHeld {
            let now = mach_absolute_time()
            let holdMs = machTimeToMs(now - spaceDownTime)
            let sinceLastTrigger = machTimeToMs(now - lastTriggerTime)

            if holdMs >= UInt64(spaceHoldThreshold) && sinceLastTrigger >= UInt64(cooldown) {
                lastTriggerTime = now
                triggered.send()
                return nil // swallow B
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func machTimeToMs(_ elapsed: UInt64) -> UInt64 {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let nanos = elapsed * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        return nanos / 1_000_000
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // Re-enable the tap
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(proxy, type, event)
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/BirdSTT/Hotkey/HotkeyManager.swift
git commit -m "feat: HotkeyManager with CGEvent tap for Space+B with anti-misfire"
```

---

### Task 7: AudioCaptureService

**Files:**
- Create: `Sources/BirdSTT/Audio/AudioCaptureService.swift`

- [ ] **Step 1: Implement AudioCaptureService**

```swift
import AVFoundation
import Combine

final class AudioCaptureService {
    let audioChunk = PassthroughSubject<Data, Never>()
    let audioLevel = PassthroughSubject<Float, Never>()

    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16000
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Calculate audio level from input buffer
            let level = self.calculateRMS(buffer: buffer)
            self.audioLevel.send(level)

            // Convert to target format
            guard let converter = converter else {
                return
            }

            let frameCapacity = AVAudioFrameCount(
                targetSampleRate * Double(buffer.frameLength) / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCapacity
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            // Convert Float32 to Int16 little-endian PCM
            let pcmData = self.float32ToInt16(buffer: convertedBuffer)
            self.audioChunk.send(pcmData)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(count))
        // Normalize to 0.0~1.0 range (clamp loud signals)
        return min(rms * 5.0, 1.0)
    }

    private func float32ToInt16(buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData?[0] else { return Data() }
        let count = Int(buffer.frameLength)
        var int16Array = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let clamped = max(-1.0, min(1.0, channelData[i]))
            int16Array[i] = Int16(clamped * Float(Int16.max))
        }
        return int16Array.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/BirdSTT/Audio/AudioCaptureService.swift
git commit -m "feat: AudioCaptureService with AVAudioEngine, PCM16 output, RMS levels"
```

---

### Task 8: DoubaoASRService

**Files:**
- Create: `Sources/BirdSTT/ASR/DoubaoASRService.swift`

- [ ] **Step 1: Implement DoubaoASRService**

```swift
import Foundation
import Combine

final class DoubaoASRService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isFinal: Bool = false
    let error = PassthroughSubject<Error, Never>()

    private let settings: Settings
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioSubscription: AnyCancellable?
    private let wsURL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"

    init(settings: Settings) {
        self.settings = settings
    }

    func connect(audioStream: PassthroughSubject<Data, Never>) {
        guard let url = URL(string: wsURL) else { return }

        var request = URLRequest(url: url)
        request.setValue(settings.doubaoAppId, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(settings.doubaoAccessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue("volc.seedasr.sauc.duration", forHTTPHeaderField: "X-Api-Resource-Id")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        sendHandshake()
        receiveLoop()
        subscribeToAudio(audioStream)
    }

    func sendEndSignal() {
        // Send empty binary as end-of-stream marker
        let message = URLSessionWebSocketTask.Message.data(Data())
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

    private func sendHandshake() {
        let handshake = ASRHandshakeRequest(
            appId: settings.doubaoAppId,
            namespace: "SeedASR",
            format: "pcm",
            rate: 16000,
            bits: 16,
            channel: 1,
            language: "zh-CN,en-US"
        )

        guard let data = try? JSONEncoder().encode(handshake),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
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
                self.receiveLoop() // continue listening
            case .failure(let err):
                self.error.send(err)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let result = try? JSONDecoder().decode(ASRResult.self, from: data) else {
            return
        }

        DispatchQueue.main.async {
            self.transcript = result.text
            if result.isFinal {
                self.isFinal = true
            }
        }
    }

    private func subscribeToAudio(_ audioStream: PassthroughSubject<Data, Never>) {
        audioSubscription = audioStream.sink { [weak self] chunk in
            let message = URLSessionWebSocketTask.Message.data(chunk)
            self?.webSocketTask?.send(message) { err in
                if let err = err {
                    self?.error.send(err)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/BirdSTT/ASR/DoubaoASRService.swift
git commit -m "feat: DoubaoASRService with WebSocket streaming, handshake, and result parsing"
```

---

### Task 9: FloatingWindowController

**Files:**
- Create: `Sources/BirdSTT/UI/FloatingWindowController.swift`

- [ ] **Step 1: Implement FloatingWindowController**

```swift
import AppKit
import SwiftUI

final class FloatingWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show<Content: View>(content: Content) {
        if panel != nil {
            dismiss(animated: false)
        }

        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 220
        let bottomMargin: CGFloat = 60

        let panelX = (screen.visibleFrame.width - panelWidth) / 2 + screen.visibleFrame.origin.x
        let panelY = screen.visibleFrame.origin.y + bottomMargin

        let panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        // Visual effect view for frosted glass
        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true
        panel.contentView?.addSubview(visualEffect)

        // SwiftUI hosting view
        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        self.hostingView = hosting
    }

    func dismiss(animated: Bool = true) {
        guard let panel = panel else { return }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                panel.orderOut(nil)
                self?.panel = nil
                self?.hostingView = nil
            })
        } else {
            panel.orderOut(nil)
            self.panel = nil
            self.hostingView = nil
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/BirdSTT/UI/FloatingWindowController.swift
git commit -m "feat: FloatingWindowController with NSPanel, frosted glass, fade animations"
```

---

### Task 10: SwiftUI Views

**Files:**
- Create: `Sources/BirdSTT/UI/WaveformView.swift`
- Create: `Sources/BirdSTT/UI/TranscriptView.swift`
- Create: `Sources/BirdSTT/UI/FloatingContentView.swift`

- [ ] **Step 1: Implement WaveformView**

```swift
import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    audioLevel: audioLevel,
                    index: index,
                    barCount: barCount
                )
            }
        }
        .frame(height: 48)
    }
}

private struct WaveformBar: View {
    let audioLevel: Float
    let index: Int
    let barCount: Int

    @State private var phase: Double = 0

    private var normalizedHeight: CGFloat {
        let baseHeight: CGFloat = 0.3
        let variation = sin(Double(index) * 0.8 + phase) * 0.3
        let level = CGFloat(audioLevel) * (0.7 + variation)
        return min(max(baseHeight + level, 0.15), 1.0)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.39, green: 0.4, blue: 0.95),   // #6366f1
                        Color(red: 0.93, green: 0.3, blue: 0.6)     // #ec4899
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: 48 * normalizedHeight)
            .animation(.easeInOut(duration: 0.15), value: audioLevel)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}
```

- [ ] **Step 2: Implement TranscriptView**

```swift
import SwiftUI

struct TranscriptView: View {
    let text: String
    let isRecording: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    Text(text.isEmpty ? "正在聆听..." : text)
                        .font(.system(size: 14))
                        .foregroundColor(text.isEmpty ? .white.opacity(0.4) : .white.opacity(0.9))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isRecording {
                        BlinkingCursor()
                    }

                    Spacer(minLength: 0)
                    Color.clear.frame(width: 1, height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 80)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .onChange(of: text) {
                withAnimation {
                    proxy.scrollTo("bottom")
                }
            }
        }
    }
}

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Text("|")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(visible ? 0.6 : 0))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}
```

- [ ] **Step 3: Implement FloatingContentView**

```swift
import SwiftUI
import Combine

struct FloatingContentView: View {
    @ObservedObject var asrService: DoubaoASRService
    let audioLevel: AnyPublisher<Float, Never>
    let statePublisher: AnyPublisher<AppState, Never>
    let onStop: () -> Void

    @State private var state: AppState = .connecting
    @State private var currentLevel: Float = 0
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

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
                Text(formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .monospacedDigit()
            }
            .padding(.bottom, 14)

            // Waveform
            WaveformView(audioLevel: currentLevel)
                .padding(.bottom, 16)

            // Transcript
            TranscriptView(
                text: asrService.transcript,
                isRecording: state == .recording
            )
            .padding(.bottom, 14)

            // Bottom bar
            if state == .recording || state == .stopping {
                Button(action: onStop) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red)
                            .frame(width: 14, height: 14)
                        Text("停止 (Space+B)")
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
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Sources/BirdSTT/UI/WaveformView.swift Sources/BirdSTT/UI/TranscriptView.swift Sources/BirdSTT/UI/FloatingContentView.swift
git commit -m "feat: SwiftUI views — WaveformView, TranscriptView, FloatingContentView"
```

---

### Task 11: AppDelegate Orchestration

**Files:**
- Modify: `Sources/BirdSTT/App/AppDelegate.swift`

- [ ] **Step 1: Wire up all services in AppDelegate**

Replace the entire `Sources/BirdSTT/App/AppDelegate.swift` with:

```swift
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
    private lazy var hotkeyManager = HotkeyManager(
        spaceHoldThreshold: settings.spaceHoldThreshold,
        cooldown: settings.hotkeyCooldown
    )
    private let audioService = AudioCaptureService()
    private lazy var asrService = DoubaoASRService(settings: settings)
    private let windowController = FloatingWindowController()
    private var cancellables = Set<AnyCancellable>()

    func transition(to newState: AppState) {
        guard state.canTransition(to: newState) else {
            print("Invalid transition: \(state) → \(newState)")
            return
        }
        state = newState
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissionsAndStart()
    }

    private func checkPermissionsAndStart() {
        // Check Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility.")
            // Retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.checkPermissionsAndStart()
            }
            return
        }

        // Start hotkey listener
        guard hotkeyManager.start() else {
            print("Failed to start hotkey manager")
            return
        }

        // Bind hotkey trigger
        hotkeyManager.triggered
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleHotkeyTrigger() }
            .store(in: &cancellables)

        // Bind ASR final result
        asrService.$isFinal
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleFinalResult() }
            .store(in: &cancellables)

        // Bind ASR errors
        asrService.error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] err in self?.handleError(err) }
            .store(in: &cancellables)

        print("BirdSTT ready. Press and hold Space + B to start recording.")
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
            showError("请先配置 API Key。在终端运行：defaults write com.bird.stt doubaoAppId 'YOUR_APP_ID' && defaults write com.bird.stt doubaoAccessToken 'YOUR_TOKEN'")
            return
        }

        transition(to: .connecting)
        asrService.reset()

        // Show floating window
        let contentView = FloatingContentView(
            asrService: asrService,
            audioLevel: audioService.audioLevel.eraseToAnyPublisher(),
            statePublisher: $state.eraseToAnyPublisher(),
            onStop: { [weak self] in self?.stopRecording() }
        )
        windowController.show(content: contentView)

        // Start audio capture
        do {
            try audioService.start()
        } catch {
            handleError(error)
            return
        }

        // Connect ASR
        asrService.connect(audioStream: audioService.audioChunk)
        transition(to: .recording)
    }

    private func stopRecording() {
        guard state == .recording else { return }
        transition(to: .stopping)

        audioService.stop()
        asrService.sendEndSignal()

        // Timeout: if no final result in 5s, use what we have
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, self.state == .stopping else { return }
            self.handleFinalResult()
        }
    }

    private func handleFinalResult() {
        guard state == .stopping || state == .recording else { return }

        let text = asrService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            showError("未检测到语音")
            return
        }

        transition(to: .done)
        ClipboardService.copy(text)

        asrService.disconnect()

        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.windowDismissDelay) { [weak self] in
            self?.windowController.dismiss()
            self?.transition(to: .idle)
        }
    }

    private func handleError(_ error: Error) {
        let msg = error.localizedDescription
        showError(msg)
    }

    private func showError(_ message: String) {
        if state.canTransition(to: .error(message)) {
            transition(to: .error(message))
        }
        audioService.stop()
        asrService.disconnect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.windowController.dismiss()
            self?.transition(to: .idle)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Verify tests still pass**

Run: `swift test 2>&1 | tail -10`
Expected: All tests pass (SettingsTests, ASRModelsTests, AppStateTests)

- [ ] **Step 4: Commit**

```bash
git add Sources/BirdSTT/App/AppDelegate.swift
git commit -m "feat: AppDelegate orchestration — wires hotkey, audio, ASR, UI with state machine"
```

---

### Task 12: Bundle Script & First Run

**Files:**
- Modify: `scripts/bundle.sh` (make executable)

- [ ] **Step 1: Make bundle.sh executable and build the app**

Run:
```bash
chmod +x scripts/bundle.sh
./scripts/bundle.sh
```
Expected: "Bundle created at: build/BirdSTT.app"

- [ ] **Step 2: Verify the .app bundle structure**

Run:
```bash
ls -la build/BirdSTT.app/Contents/
ls -la build/BirdSTT.app/Contents/MacOS/
```
Expected: `Info.plist` in Contents/, `BirdSTT` executable in MacOS/

- [ ] **Step 3: Run all tests one final time**

Run: `swift test 2>&1 | tail -15`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add scripts/bundle.sh
git commit -m "chore: finalize bundle script, verify build"
```

---

### Task 13: Manual Integration Test

This task is a manual verification checklist. Run the app and verify each feature.

- [ ] **Step 1: Grant Accessibility permission**

Run: `open build/BirdSTT.app`

macOS will prompt for Accessibility access. Grant it in System Settings > Privacy & Security > Accessibility.

- [ ] **Step 2: Configure API keys**

Run:
```bash
defaults write com.bird.stt doubaoAppId "YOUR_ACTUAL_APP_ID"
defaults write com.bird.stt doubaoAccessToken "YOUR_ACTUAL_TOKEN"
```

Then restart the app: `open build/BirdSTT.app`

- [ ] **Step 3: Test hotkey activation**

Hold Space for ~200ms, then press B.
Expected: Floating window appears at bottom center with fade-in animation.

- [ ] **Step 4: Test recording and waveform**

Speak into the microphone.
Expected: Waveform bars animate in response to voice. Timer counts up.

- [ ] **Step 5: Test real-time transcription**

Speak a sentence mixing Chinese and English.
Expected: Text appears in the transcript area in real-time, updating progressively.

- [ ] **Step 6: Test stop and clipboard**

Hold Space + press B again to stop.
Expected: Window shows "已复制到剪贴板" with checkmark, then fades out after 1.5s.

- [ ] **Step 7: Verify clipboard content**

Run: `pbpaste`
Expected: The transcribed text is printed.

- [ ] **Step 8: Test anti-misfire**

Type normally including spaces and the letter B at normal typing speed.
Expected: No accidental activation (Space must be held >= 150ms).
