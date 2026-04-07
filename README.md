# 🐦 BirdSTT — macOS 语音转文字助手

<p align="center">
  <strong>一款轻量级 macOS 原生语音转文字工具，全局快捷键唤醒，实时识别，自动复制到剪贴板。</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.10-orange" alt="Swift 5.10">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/ASR-豆包大模型-purple" alt="Doubao ASR">
</p>

---

## ✨ 功能特性

- 🎙️ **全局快捷键** — `Ctrl + Shift + B` 一键唤醒/停止，任何界面可用
- 🪟 **悬浮窗** — 毛玻璃半透明悬浮窗，屏幕底部居中，不遮挡工作区
- 🌊 **音频波形** — 紫粉渐变动态波形条，实时反映说话音量
- 📝 **实时预览** — 边说边显示识别文字，流式输出无需等待
- 📋 **自动复制** — 停止后自动复制到剪贴板，直接 `Cmd + V` 粘贴
- 🗣️ **语音命令** — 说"删掉所有"、"换行"、"撤销"等指令编辑文字
- 🌐 **中英混合** — 支持中文普通话和英语混合识别
- 🐦 **Dock 常驻** — 应用图标显示在 Dock 栏，方便切换管理

---

## 🎬 快速开始

### 📋 前置要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode Command Line Tools（`xcode-select --install`）
- 火山引擎账号（用于语音识别 API）

### 1️⃣ 克隆项目

```bash
git clone https://github.com/your-username/bird-Speech-to-Text.git
cd bird-Speech-to-Text
```

### 2️⃣ 编译构建

```bash
bash scripts/bundle.sh
```

构建成功后输出：

```
Bundle created at: build/BirdSTT.app
```

### 3️⃣ 启动应用

```bash
open build/BirdSTT.app
```

> 💡 **调试模式**（可看终端日志）：
> ```bash
> ./build/BirdSTT.app/Contents/MacOS/BirdSTT
> ```

### 4️⃣ 配置 API 密钥

首次启动会弹出设置窗口，填入你的火山引擎 API 信息（获取方式见下方 👇）

### 5️⃣ 开始使用

按下 **`Ctrl + Shift + B`**，开始说话！

---

## 🔑 获取火山引擎 API 密钥

BirdSTT 使用 **豆包大模型流式语音识别** 服务，你需要在火山引擎注册并获取 API 密钥。

### 步骤一：注册账号

1. 打开 [火山引擎官网](https://www.volcengine.com/) 并注册账号
2. 完成实名认证（必须，否则无法使用 API）

### 步骤二：开通语音识别服务

1. 进入 [语音识别控制台](https://console.volcengine.com/speech/service/10011)
2. 找到 **「豆包流式语音识别」** 服务
3. 点击 **「开通服务」**（有免费额度）

### 步骤三：创建应用并获取密钥

1. 进入 [语音识别应用管理](https://console.volcengine.com/speech/service/10011)
2. 点击 **「创建应用」**
3. 创建完成后，你会看到以下信息：

| 字段 | 说明 | 示例 |
|------|------|------|
| **App ID** | 应用唯一标识 | `6766744367` |
| **Access Token** | API 访问令牌 | `Y6y5xB3J...` |

> ⚠️ **请妥善保管 Access Token**，不要泄露到公开仓库中。

### 步骤四：填入 BirdSTT 设置

启动 BirdSTT 后，在设置窗口填入：

| 设置项 | 填写内容 |
|--------|---------|
| 🔹 **App ID** | 控制台中的 App ID |
| 🔹 **Access Token** | 控制台中的 Access Token |
| 🔹 **Resource ID** | 保持默认 `volc.bigasr.sauc.duration` 即可 |

> 📌 **Resource ID 说明：**
> - 模型 1.0（默认）：`volc.bigasr.sauc.duration`
> - 模型 2.0：`volc.seedasr.sauc.duration`
> - 选择哪个取决于你在控制台开通了哪个版本

设置完成后点击 **Save**，然后按 `Ctrl + Shift + B` 即可开始使用！

---

## 🎤 使用方法

### 基本流程

```
按下 Ctrl+Shift+B  →  悬浮窗弹出  →  开始说话  →  再按 Ctrl+Shift+B 或说"结束录制"  →  文字自动复制到剪贴板  →  Cmd+V 粘贴
```

### 🎯 语音命令

录音过程中，你可以通过语音指令编辑已识别的文字：

| 🗣️ 语音指令 | 📝 功能 | 💬 示例 |
|-------------|---------|--------|
| **"删掉所有"** / "全部删除" / "清空" | 清空所有已识别文字 | 说错了想重新开始 |
| **"删掉这一行"** / "删除这一行" | 删除最后一行文字 | 删除刚说的一整句 |
| **"删除X个字"** / "删掉X个字符" | 从末尾删除指定数量字符 | "删除三个字"、"删除10个字" |
| **"换行"** / "另起一行" | 插入换行符 | 需要分段时使用 |
| **"撤销"** / "回退" | 撤销上一步操作 | 误删了可以撤回 |
| **"结束录制"** / "结束语音" / "结束会话" | 停止录音并复制到剪贴板 | 无需按键，语音停止 |

> 💡 **提示：**
> - 语音命令仅在句子被确认后才触发，不会因为中间识别状态误触
> - 支持中文数字（一到九十九）和阿拉伯数字
> - 撤销栈最多保留 50 步

---

## ⚙️ 配置管理

### 重置设置

如果需要清除所有已保存的配置：

```bash
defaults delete com.bird.stt
```

### 查看当前配置

```bash
defaults read com.bird.stt
```

### 手动修改设置

```bash
# 修改 Resource ID
defaults write com.bird.stt doubaoResourceId "volc.seedasr.sauc.duration"

# 修改窗口自动消失延迟（秒）
defaults write com.bird.stt windowDismissDelay -float 2.0
```

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────┐
│                  BirdSTT                     │
├──────────┬──────────┬──────────┬────────────┤
│ Hotkey   │ Audio    │ ASR      │ UI         │
│ Manager  │ Capture  │ Service  │ Layer      │
│ (Carbon) │(AVAudio) │(WebSocket│(SwiftUI+   │
│          │          │ +Binary) │ AppKit)    │
├──────────┴──────┬───┴──────────┴────────────┤
│  TranscriptProcessor (语音命令处理)           │
├─────────────────┴───────────────────────────┤
│  AppDelegate (状态机 & 模块编排)              │
└─────────────────────────────────────────────┘
```

| 模块 | 技术 | 说明 |
|------|------|------|
| 🎹 全局快捷键 | Carbon `RegisterEventHotKey` | 无需辅助功能权限 |
| 🎙️ 音频采集 | AVAudioEngine | PCM 16kHz 16-bit Mono |
| 🌐 语音识别 | URLSessionWebSocketTask | 豆包二进制协议 + Gzip |
| 🪟 悬浮窗 | NSPanel + NSVisualEffectView | 毛玻璃 HUD 风格 |
| 🎨 UI 视图 | SwiftUI | 波形、文字、动画 |
| 📋 剪贴板 | NSPasteboard | 自动复制 |
| ⚙️ 配置存储 | UserDefaults | 持久化设置 |
| 🗜️ 数据压缩 | zlib | Gzip 压缩/解压 |

### 状态机

```
Idle → Connecting → Recording → Stopping → Done → Idle
                       ↓           ↓
                     Error ←────────┘
                       ↓
                     Idle
```

---

## 📁 项目结构

```
bird-Speech-to-Text/
├── 📦 Package.swift               # SPM 项目配置
├── 📂 Sources/BirdSTT/
│   ├── 📂 App/
│   │   ├── main.swift             # 应用入口
│   │   └── AppDelegate.swift      # 状态机 & 模块编排
│   ├── 📂 ASR/
│   │   ├── ASRModels.swift        # 豆包二进制协议 & 数据模型
│   │   └── DoubaoASRService.swift # WebSocket ASR 服务
│   ├── 📂 Audio/
│   │   └── AudioCaptureService.swift  # 麦克风采集 & PCM 转换
│   ├── 📂 Config/
│   │   └── Settings.swift         # UserDefaults 配置管理
│   ├── 📂 Hotkey/
│   │   └── HotkeyManager.swift    # 全局快捷键 (Carbon)
│   ├── 📂 Services/
│   │   ├── ClipboardService.swift # 剪贴板操作
│   │   └── TranscriptProcessor.swift  # 语音命令处理器
│   └── 📂 UI/
│       ├── FloatingContentView.swift  # 主界面
│       ├── FloatingWindowController.swift  # 悬浮窗控制器
│       ├── WaveformView.swift     # 波形动画
│       ├── TranscriptView.swift   # 文字显示
│       └── SettingsWindowController.swift  # 设置窗口
├── 📂 Tests/BirdSTTTests/        # 单元测试
├── 📂 Resources/
│   └── Info.plist                 # 应用配置
├── 📂 scripts/
│   └── bundle.sh                  # 构建 & 打包脚本
└── 📄 README.md
```

---

## 🔒 权限说明

| 权限 | 是否必需 | 说明 |
|------|---------|------|
| 🎙️ 麦克风 | ✅ 必需 | 首次录音时系统会弹窗请求，需要允许 |
| ♿ 辅助功能 | ❌ 不需要 | 使用 Carbon API 注册快捷键，无需辅助功能权限 |
| 📡 网络 | ✅ 必需 | 连接火山引擎语音识别服务 |

---

## ❓ 常见问题

### 🔹 按 Ctrl+Shift+B 没反应？

确保应用正在运行。在终端执行查看是否输出 `[HotkeyManager] Started`：
```bash
./build/BirdSTT.app/Contents/MacOS/BirdSTT
```

### 🔹 提示 "There was a bad response from the server"？

1. 检查 API 密钥是否正确填写
2. 确认火山引擎控制台已**开通**语音识别服务
3. 检查 Resource ID 是否与开通的模型版本匹配

### 🔹 如何重新打开设置窗口？

清除配置后重启即可弹出设置：
```bash
defaults delete com.bird.stt
killall BirdSTT
open build/BirdSTT.app
```

### 🔹 识别结果为空？

- 检查系统设置中是否已允许 BirdSTT 使用麦克风
- 前往 **系统设置 → 隐私与安全性 → 麦克风** 确认已开启

### 🔹 能识别英语吗？

可以！豆包大模型默认支持中英文混合识别，直接说英语即可。

### 🔹 语音命令没触发？

语音命令仅在 ASR 将句子标记为「确定」(definite) 后才匹配。如果说得太快和前面的文字连在一起，可能不会被识别为独立命令。建议稍作停顿后再说指令。

---

## 🛠️ 开发

### 构建调试版本

```bash
swift build
```

### 运行测试

```bash
swift test
```

### 构建发布版本

```bash
bash scripts/bundle.sh
```

---

## 📄 License

MIT License — 随意使用、修改和分发。

---

## 🙏 致谢

- [火山引擎 · 豆包语音识别](https://www.volcengine.com/docs/6561/1354869) — ASR 服务提供方
- 使用 [Claude Code](https://claude.ai/claude-code) 辅助开发
