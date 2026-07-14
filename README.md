# Voice to Claude

Hands-free voice input for Claude Code on Linux. Speak naturally and have your words typed directly into any focused window.

## Features

- **Wake Word Activation**: Say "OK Claude" to start dictating
- **Hotkey Dictation**: Press `Super+C` to start dictating without the wake word
- **Submit Command**: Say "Execute" to press Enter and submit
- **Fast Transcription**: ~1.8s latency using whisper.cpp with GPU acceleration
- **Smart Silence Detection**: Silero VAD neural network distinguishes speech from background noise
- **Punctuation Commands**: Say "period", "comma", "question mark" and they become symbols
- **Fully Local**: All processing happens on-device, no cloud required
- **Always Listening**: Runs as a systemd user service
- **System Tray Icon**: Visual state feedback (idle/listening/muted) with right-click menu

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Voice Claude Daemon                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  OpenWakeWord (always listening)                           │  │
│  │  - "OK Claude" → start LISTENING state                     │  │
│  │  - "Execute"   → press Enter, stay in IDLE                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼ wake word detected                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  VAD (voice activity detection) → Recording                │  │
│  │  → whisper.cpp transcription → ydotool text injection      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

1. Install system dependencies (see [INSTALL.md](INSTALL.md))
2. Build whisper.cpp and download a model
3. Run `./install.sh`
4. Say "OK Claude" and start talking!

## Usage

The daemon runs automatically after installation:

```
"OK Claude"  → Start listening, speak your message
Super+C      → Start listening now, without the wake word
[silence]    → Transcription starts automatically
"Execute"    → Press Enter to submit
```

> **Hotkey vs wake word**: `Super+C` jumps straight to recording (only when idle —
> it won't override a mute or interrupt an in-progress dictation). The "OK Claude"
> wake word still works in parallel.

### Manual Control

```bash
# Start/stop the daemon
systemctl --user start voice-claude
systemctl --user stop voice-claude

# View logs
journalctl --user -u voice-claude -f
```

### System Tray Icon

The daemon displays a tray icon that shows the current state at a glance:

| Icon | State | Meaning |
|------|-------|---------|
| 🎤 | Idle | Listening for "OK Claude" |
| 🎤⬆ | Listening | Recording your speech |
| 🔇 | Muted | Voice input disabled |

**Right-click menu options**:
- Mute/Unmute toggle
- View Logs (opens journalctl)
- Quit

### Privacy Toggle

Use `Super+M` to instantly toggle mute/unmute (no service restart needed).

You can also use the CLI scripts:

```bash
voice-claude-toggle   # Toggle mute/unmute
voice-claude-stop     # Stop the daemon entirely
voice-claude-start    # Start the daemon
```

> **Note**: This is better than system mute because:
> - Muted state = no audio processed (true privacy)
> - Starting the daemon auto-restores mic volume (fixes Ubuntu mute/unmute bug)

### Custom Vocabulary

Whisper often mishears project names, handles, and technical jargon. Two
config options address this (both optional; edit
`~/.config/voice-claude/config.yaml`, then restart the daemon):

```yaml
whisper:
  # Bias transcription toward domain vocabulary (probabilistic)
  prompt: "Vocabulary: kubectl, systemd, PipeWire, tmux."

  # Deterministically rewrite words Whisper consistently gets wrong
  replacements:
    cooba netties: kubernetes
    my handle: myhandle42
```

- **`prompt`** is passed to whisper.cpp as `--prompt`, making listed words more
  likely outputs. It helps most with multi-syllable terms; it can lose to
  phonetics when the misheard word is a common English word.
- **`replacements`** run as post-processing: whole-word, case-insensitive, and
  multi-word phrases are supported. A capitalized match keeps its capital
  unless the intended word contains non-letters (handles like `myhandle42`,
  tokens like `origin/dev`), which are inserted verbatim. The trade-off: a
  replaced word can never be dictated literally again.

## File Locations

| File | Purpose |
|------|---------|
| `~/.local/bin/voice-claude-daemon` | Wake word daemon |
| `~/.local/bin/voice-claude-toggle` | Privacy toggle script |
| `~/.local/lib/` | Whisper shared libraries |
| `~/.config/voice-claude/config.yaml` | Configuration |
| `~/.local/share/voice-claude/models/` | Wake word models |
| `~/.local/share/whisper/models/` | Whisper models |
| `~/.config/systemd/user/voice-claude.service` | Systemd service |

## Requirements

- Linux with PulseAudio/PipeWire
- Python 3.8+
- whisper.cpp (built with GPU support recommended)
- ydotool (for text injection)
- GNOME or other Wayland compositor

## Performance

| Model | Backend | Latency | Accuracy |
|-------|---------|---------|----------|
| tiny.en | GPU | ~0.4s | Lower |
| **small.en** | **GPU** | **~1.8s** | **Good (default)** |
| medium.en | GPU | ~5s | Best |

## Privacy

All processing is **100% local**:
- Wake word detection: OpenWakeWord (on-device neural network)
- Speech transcription: whisper.cpp (on-device)
- No audio leaves your machine

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - Fast C++ Whisper inference
- [OpenWakeWord](https://github.com/dscripka/openWakeWord) - Open source wake word detection
- [ydotool](https://github.com/ReimuNotMoe/ydotool) - Wayland-compatible input automation
