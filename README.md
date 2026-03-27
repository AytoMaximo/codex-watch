<p align="center">
  <img src="logo.png" width="140" alt="Claude Logo" />
</p>

<h1 align="center"><strong>Codex Watch (fork)</strong></h1>

<p align="center">
  Control Codex CLI from your Apple Watch.<br/>
  See terminal output, approve permissions, and send voice commands — all from your wrist.
</p>

https://github.com/user-attachments/assets/5f478c28-2086-4696-9d76-e43dda853201

---

```
                    WCSession
 Apple Watch  <===============>  iPhone  <=======>  Mac
  (SwiftUI)     sendMessage       (Relay)   HTTP    Bridge Server
                transferUserInfo           SSE     (Node.js)
                                                      |
                                            HTTP Hooks | PTY stdin
                                                      v
                                               Codex CLI Session
```

## What It Does

- **Live terminal output** on your Apple Watch — see what Claude is doing in real-time
- **Permission prompts** — approve or deny Claude's actions from your wrist (Edit file? Run command?)
- **Dynamic questions** — answer `AskUserQuestion` prompts with all options displayed
- **Voice tasks** — dictate a task on watch, bridge runs `codex exec "<task>"`
- **iPhone companion** — pairing UI, connection status, terminal preview, permission approvals
- **Bridge server** — Node.js server on your Mac that connects Codex CLI to the watch via hooks + SSE

## Architecture

The system has three components:

### 1. Bridge Server (Mac)
A Node.js HTTP server (`skill/bridge/server.js`) that:
- Receives events from Codex CLI via [hooks.json hooks](https://developers.openai.com/codex/hooks) (`PreToolUse`, `PostToolUse`, `Stop`, etc.)
- Streams events to connected clients via Server-Sent Events (SSE)
- Handles pairing with a 6-digit code + session token
- Advertises itself on the local network via Bonjour/mDNS
- Streams tool and lifecycle events to watch/phone clients in real time

### 2. iPhone App
A SwiftUI iOS app that:
- Discovers the bridge via Bonjour (or localhost fallback)
- Pairs using the 6-digit code
- Shows connection status + terminal output
- Displays interactive permission prompts (Yes / Yes all / No)
- Relays events to the Apple Watch via WCSession

### 3. watchOS App
A SwiftUI watchOS app that:
- Connects directly to the bridge over Wi-Fi (Bonjour or manual IP entry)
- Shows live terminal output (Read, Edit, Bash, Grep operations)
- Displays permission prompts with all options as scrollable buttons
- Supports voice command input via watchOS dictation
- Haptic feedback for task completion, approvals, and errors

## Quick Start

### Prerequisites
- macOS with Node.js 18+
- Xcode 16+ with watchOS SDK
- Apple Watch on the same Wi-Fi as your Mac
- Codex CLI installed

### Apple Watch Wi-Fi Setup
1. Make sure your Apple Watch is connected to the **same Wi-Fi network** as the Mac running your Claude Code session
2. On your Apple Watch, go to **Settings > Wi-Fi > your network** and turn **Private Wi-Fi Address** to **Off** — this is required for Bonjour/mDNS discovery to work reliably on the local network

### 1. Install the bridge

```bash
cd skill/bridge
npm install
```

### 2. Install Codex hooks

This configures Codex CLI hooks to stream events to the bridge:

```bash
./skill/setup-hooks.sh
```

To remove hooks later: `./skill/setup-hooks.sh --remove`

### 3. Start the bridge server

```bash
cd skill/bridge
node server.js
```

You'll see:
```
╔═══════════════════════════════════════╗
║         CODEX WATCH BRIDGE            ║
╠═══════════════════════════════════════╣
║  Pairing Code:  648505                ║
║  IP Address:    192.168.1.4           ║
║  Port:          7860                  ║
╚═══════════════════════════════════════╝
```

### 4. Build the iOS + watchOS apps

```bash
cd ios/ClaudeWatch
xcodegen generate    # Generates the .xcodeproj
open ClaudeWatch.xcodeproj
```

In Xcode:
1. Set your **Development Team** on both targets (ClaudeWatch + ClaudeWatchWatch)
2. Select the **ClaudeWatch** scheme for the iPhone, or **ClaudeWatchWatch** for the watch
3. Build and run (Cmd+R)

### 5. Pair

**iPhone:** Enter the 6-digit pairing code from the bridge banner.

**Apple Watch:** The app auto-discovers the bridge via Bonjour. If that fails, enter the IP address shown in the bridge banner manually.

### 6. Use Codex normally

You can either:
- run Codex normally in a terminal (hook-based telemetry), or
- dictate a task from watch — bridge executes it as one-shot `codex exec "<task>"` and streams output back live.

## Project Structure

```
claude-watch/
├── skill/
│   ├── bridge/
│   │   ├── server.js          # Bridge server (HTTP + SSE + Bonjour)
│   │   └── package.json       # Node.js dependencies
│   ├── setup.sh               # Install bridge dependencies
│   ├── setup-hooks.sh         # Install/remove Claude Code hooks
│   └── SKILL.md               # Claude Code skill definition
│
├── ios/ClaudeWatch/
│   ├── project.yml            # XcodeGen project spec
│   │
│   ├── Shared/                # Shared between iOS + watchOS
│   │   ├── Models/
│   │   │   ├── SessionState.swift
│   │   │   ├── TerminalLine.swift
│   │   │   ├── ApprovalRequest.swift
│   │   │   ├── WatchMessage.swift
│   │   │   └── OutputRingBuffer.swift
│   │   ├── Connectivity/
│   │   │   └── WatchSessionManager.swift
│   │   └── Extensions/
│   │       ├── Color+Hex.swift
│   │       └── ClaudeMascot.swift     # Official Claude logo as SwiftUI Shape
│   │
│   ├── ClaudeWatch iOS/       # iPhone app
│   │   ├── App/ClaudeWatchApp.swift
│   │   ├── Views/
│   │   │   ├── PairingView.swift      # 6-digit code entry
│   │   │   ├── ConnectionStatusView.swift  # Terminal + status
│   │   │   └── SettingsView.swift
│   │   ├── Networking/
│   │   │   ├── BonjourDiscovery.swift # LAN bridge discovery
│   │   │   ├── BridgeClient.swift     # HTTP client
│   │   │   └── SSEClient.swift        # Server-Sent Events
│   │   └── Services/
│   │       ├── RelayService.swift     # Coordinates bridge <-> watch
│   │       └── NotificationService.swift
│   │
│   └── ClaudeWatch watchOS/   # Apple Watch app
│       ├── App/ClaudeWatchWatchApp.swift
│       ├── Views/
│       │   ├── OnboardingView.swift   # Pairing (Bonjour + manual IP)
│       │   ├── SessionView.swift      # Terminal output + mic FAB
│       │   ├── ApprovalView.swift     # Dynamic permission prompts
│       │   ├── VoiceInputView.swift   # Dictation input
│       │   └── StatusDashboard.swift
│       ├── Services/
│       │   ├── WatchViewState.swift   # Watch-specific state + SSE
│       │   ├── WatchBridgeClient.swift # Direct HTTP to bridge
│       │   ├── HapticManager.swift
│       │   └── SpeechService.swift
│       └── Complications/
│           └── ComplicationProvider.swift
│
└── .claude/skills/claude-watch/
    └── SKILL.md               # /claude-watch skill for Claude Code
```

## How It Works

### Event Flow (Mac -> Watch)

1. Codex runs a tool (for now this is primarily `Bash`)
2. The `PreToolUse` / `PostToolUse` hook fires and is forwarded to the bridge server
3. Bridge pushes the event to all connected SSE clients
4. The watch/phone receives the SSE event and renders it as a terminal line

### Current Codex limitations

Codex hooks currently provide lifecycle + tool events, but the Claude-style blocking
`PermissionRequest` flow does not exist in the same form. This fork supports:
- live telemetry/monitoring via hooks, and
- watch voice task execution via one-shot `codex exec`.

## Codex Hooks

The `setup-hooks.sh` script installs hooks in `~/.codex/hooks.json`:

| Hook Event | Purpose |
|-----------|---------|
| `SessionStart` | mark session activity |
| `UserPromptSubmit` | capture prompt lifecycle |
| `PreToolUse` | capture tool invocations |
| `PostToolUse` | capture tool output metadata |
| `Stop` | detect when Codex finishes responding |

## Configuration

### Bridge Server

| Env Var | Default | Description |
|---------|---------|-------------|
| `PORT` | 7860 | Starting port (tries 7860-7869) |

### Removing Hooks

```bash
./skill/setup-hooks.sh --remove
```

### Unpairing

- **iPhone:** Settings > Forget Mac
- **Watch:** Restart the app (credentials clear when bridge restarts)

## Requirements

| Component | Minimum Version |
|-----------|----------------|
| macOS | 13.0+ |
| Node.js | 18+ |
| Xcode | 16+ |
| iOS | 17.0 |
| watchOS | 10.0 |
| Codex CLI | latest |

## Troubleshooting

### Watch shows "Bridge not found"
- Ensure `node server.js` is running on your Mac
- Check that your watch is on the same Wi-Fi network
- Use the "Enter IP manually" option with the IP shown in the bridge banner

### Watch shows "unsupported architecture"
- Clean build folder in Xcode (Cmd+Shift+Option+K)
- Select the correct scheme: **ClaudeWatchWatch** (not ClaudeWatch)
- Deploy via paired iPhone destination if direct watch deployment fails

### iPhone shows "Connection failed"
- Check that the bridge is running (`curl http://127.0.0.1:7860/status`)
- The bridge must be on the same LAN as the iPhone

### Permission prompts don't appear on watch
- Verify hooks are installed: check `~/.codex/hooks.json` for entries
- Check bridge logs for "Hook: Codex ... received"
- Ensure the watch is connected to the bridge (green status dot)

### Bridge exits immediately
- Start Codex in a separate terminal — hooks will forward events automatically.

## License

MIT
