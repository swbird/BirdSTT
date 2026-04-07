# BirdSTT - macOS Speech-to-Text Floating Window App

## Overview

A macOS native app that provides a global hotkey-activated floating window for real-time speech-to-text. Uses Doubao (豆包) streaming ASR API for recognition and automatically copies results to the clipboard for pasting into Claude Code or other apps.

## Core Requirements

- Global hotkey: hold Space + press B to activate/deactivate
- Floating window at screen bottom center with translucent glass background
- Audio waveform bar animation as visual feedback during recording
- Real-time speech-to-text via Doubao streaming WebSocket API
- Chinese-English mixed language support
- Multi-line text preview area below waveform
- Manual stop → auto copy to clipboard → window auto-dismiss
- No Dock icon (LSUIElement), background + floating window only

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI + AppKit hybrid
  - SwiftUI: animation, text preview, content views
  - AppKit: NSPanel window management, CGEvent tap hotkey
- **Audio:** AVAudioEngine
- **Network:** URLSessionWebSocketTask (native, no third-party deps)
- **Reactive:** Combine framework

## Architecture

Single-process, single-target macOS app. Modules communicate via Combine Publishers.

### Project Structure

```
BirdSTT/
├── App/
│   ├── BirdSTTApp.swift              # App entry, LSUIElement menu bar mode
│   └── AppDelegate.swift              # NSApplicationDelegate, orchestrates managers
│
├── Hotkey/
│   └── HotkeyManager.swift            # CGEvent tap for Space+B
│
├── Audio/
│   └── AudioCaptureService.swift       # AVAudioEngine mic capture, PCM output
│
├── ASR/
│   ├── DoubaoASRService.swift          # WebSocket connection to Doubao streaming ASR
│   └── ASRModels.swift                 # Request/response data models
│
├── UI/
│   ├── FloatingWindowController.swift  # NSPanel: borderless, floating, transparent
│   ├── FloatingContentView.swift       # SwiftUI main view container
│   ├── WaveformView.swift              # Audio waveform bar animation
│   └── TranscriptView.swift            # Real-time text preview
│
├── Services/
│   └── ClipboardService.swift          # NSPasteboard clipboard write
│
├── Config/
│   └── Settings.swift                  # API key, hotkey config
│
└── Resources/
    ├── Info.plist
    └── Assets.xcassets
```

## Module Design

### 1. HotkeyManager (CGEvent Tap)

Intercepts keyboard events at system level to implement hold-Space+B activation.

**Logic:**
- Space keyDown → set `spaceHeld = true`, record timestamp, pass through to system normally
- B keyDown while `spaceHeld == true`:
  - If Space held >= 150ms (anti-accidental trigger): swallow B event, fire trigger
  - If Space held < 150ms: pass B through normally (user is typing)
- Space keyUp → reset `spaceHeld = false`
- 500ms cooldown after each trigger to prevent repeated activation

**Anti-accidental trigger mechanisms:**
- 150ms minimum Space hold duration before B is recognized as hotkey
- 500ms cooldown between triggers
- During recording, only Space+B (stop) is intercepted; all other keys pass through

**Requires:** Accessibility permission (`AXIsProcessTrusted()`)

**Output:** `PassthroughSubject<Void>` — fires on valid trigger

### 2. AudioCaptureService (AVAudioEngine)

Captures microphone audio and outputs PCM data suitable for Doubao ASR.

**Pipeline:**
```
Microphone → AVAudioEngine inputNode
  → installTap(bufferSize: 2048)
  → PCM Float32, 16kHz, mono
  → Convert to PCM 16-bit signed integer, little-endian
  → Package every ~200ms (~3200 bytes per packet)
  → Publish via Combine
```

**Configuration:**
- Sample rate: 16kHz
- Format: PCM 16-bit signed integer, little-endian
- Channel: mono
- Packet size: ~3200 bytes (200ms × 16000Hz × 2bytes)

**Outputs:**
- `PassthroughSubject<Data>` — audio chunks for ASR
- `PassthroughSubject<Float>` — audio level (0.0~1.0) for waveform animation

**Requires:** Microphone permission (`NSMicrophoneUsageDescription`)

### 3. DoubaoASRService (WebSocket Streaming)

Manages WebSocket connection to Doubao streaming ASR API.

**Connection details:**
- URL: `wss://openspeech.bytedance.com/api/v3/sauc/bigmodel`
- Auth headers:
  - `X-Api-App-Key: {appId}`
  - `X-Api-Access-Key: {accessToken}`
  - `X-Api-Resource-Id: volc.seedasr.sauc.duration`

**Protocol flow:**
1. Establish WebSocket connection with auth headers
2. Send `full_client_request` JSON handshake:
   ```json
   {
     "header": { "appid": "{from Settings}", "namespace": "SeedASR" },
     "payload": {
       "audio_config": {
         "format": "pcm",
         "rate": 16000,
         "bits": 16,
         "channel": 1
       },
       "language": "zh-CN,en-US"
     }
   }
   ```
3. Stream audio as binary messages (every 100~200ms)
4. Receive partial results: `{"text": "...", "is_final": false}`
5. Send empty binary message (end signal) when recording stops
6. Receive final result: `{"text": "...", "is_final": true}`
7. Close WebSocket

**Implementation:** `URLSessionWebSocketTask` — native, no third-party libraries

**Outputs:**
- `@Published var transcript: String` — real-time updated text
- `@Published var isFinal: Bool` — triggers copy + dismiss flow
- `PassthroughSubject<Error>` — connection/recognition errors

### 4. FloatingWindowController (NSPanel)

**NSPanel configuration:**
- `styleMask`: `.nonactivatingPanel` + `.borderless`
- `level`: `.floating` (always on top)
- `isOpaque`: false
- `backgroundColor`: `.clear`
- `hasShadow`: true
- Uses `NSVisualEffectView` with `.hudWindow` material for frosted glass effect

**Layout:**
- Width: ~420pt
- Height: auto-sizing (~220pt)
- Position: bottom center, 60pt from screen bottom (above Dock)
- Corner radius: 20pt

**Animations:**
- Show: fade in (0.3s ease-out)
- Dismiss: fade out (0.3s ease-in)

### 5. UI Views (SwiftUI)

**FloatingContentView** — main container, hosts:

**Status bar (top):**
- Red blinking recording indicator dot
- Recording duration timer

**WaveformView (center):**
- ~20 vertical bars with purple-pink gradient (`#6366f1` → `#ec4899`)
- Bar heights driven by `AudioCaptureService.audioLevel` publisher
- Smooth animation via SwiftUI `.animation(.easeInOut)`
- Idle state: gentle breathing animation
- Recording state: bars respond to actual audio levels

**TranscriptView (below waveform):**
- Semi-transparent rounded rectangle background (`rgba(255,255,255,0.06)`)
- Multi-line text display, scrollable
- Max height ~80pt with scroll
- Blinking cursor at text end during recognition
- Font: system 14pt

**Bottom bar:**
- Stop button with hotkey hint "停止 (Space+B)"
- Red accent color, rounded pill shape

### 6. ClipboardService

Simple wrapper around `NSPasteboard.general`:
- `copy(_ text: String)` — writes final transcript to clipboard
- Clears existing clipboard content before writing

## State Machine

```
States: Idle → Connecting → Recording → Stopping → Done → Idle
                  ↓
                Error → Idle (after 2s)
```

| State | Entry Action | Exit Action |
|-------|-------------|-------------|
| Idle | Hide window | — |
| Connecting | Show window, start fade-in, connect WebSocket | — |
| Recording | Start audio capture, begin streaming | — |
| Stopping | Stop audio capture, send end signal | — |
| Done | Copy to clipboard, show checkmark | Fade out window (1.5s delay) |
| Error | Show error message | Auto-dismiss (2s delay) |

## Data Flow (Combine)

| Publisher | Type | Subscriber |
|-----------|------|------------|
| `HotkeyManager.triggered` | `PassthroughSubject<Void>` | AppDelegate |
| `AudioCaptureService.audioChunk` | `PassthroughSubject<Data>` | DoubaoASRService |
| `AudioCaptureService.audioLevel` | `PassthroughSubject<Float>` | WaveformView |
| `DoubaoASRService.transcript` | `@Published String` | TranscriptView |
| `DoubaoASRService.isFinal` | `@Published Bool` | AppDelegate (triggers copy+close) |
| `DoubaoASRService.error` | `PassthroughSubject<Error>` | FloatingContentView |

## Permissions

| Permission | Purpose | Acquisition |
|------------|---------|-------------|
| Accessibility | CGEvent tap global hotkey | `AXIsProcessTrusted()` check, guide to System Preferences |
| Microphone | Audio capture | `AVCaptureDevice.requestAccess`, Info.plist declaration |

**First launch flow:**
1. Check Accessibility → if not granted, show guide dialog linking to System Preferences
2. Check Microphone → if not granted, system shows authorization dialog
3. Check API key → if not configured, show settings window for appId + accessToken input
4. All ready → enter Idle state, wait for hotkey

## Error Handling

| Scenario | Handling |
|----------|----------|
| WebSocket connection failed | Show error in floating window, auto-dismiss after 2s |
| Network disconnects during recording | Save recognized text so far, copy to clipboard, show "partial result" notice |
| Microphone occupied by other app | Show "microphone unavailable", auto-close window |
| API key invalid/expired | Show "authentication failed", guide to settings |
| Empty recognition result | Show "no speech detected", dismiss after 1.5s, don't write clipboard |

## Configuration (Settings.swift)

Stored in `UserDefaults`:
- `doubaoAppId: String` — Doubao API App ID
- `doubaoAccessToken: String` — Doubao API Access Token
- `hotkeySpaceHoldThreshold: Int` — Space hold ms before B triggers (default: 150)
- `hotkeyCooldown: Int` — cooldown ms between triggers (default: 500)
- `windowDismissDelay: Double` — seconds before auto-dismiss after done (default: 1.5)

## Dependencies

Zero third-party dependencies. All functionality uses native Apple frameworks:
- AppKit (NSPanel, NSEvent, CGEvent, NSPasteboard)
- SwiftUI (views, animation)
- AVFoundation (AVAudioEngine)
- Foundation (URLSessionWebSocketTask)
- Combine (reactive data flow)
