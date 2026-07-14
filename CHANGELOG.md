# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Hotkey dictation: `Super+C` starts a dictation without the "OK Claude" wake
  word (SIGUSR2 signal to the daemon; fires only from idle). `install.sh` now
  configures this shortcut alongside Super+M.
- Custom vocabulary support (`whisper.prompt`): optional initial prompt passed
  to whisper.cpp as `--prompt`, biasing transcription toward domain terms.
- Word replacements (`whisper.replacements`): deterministic post-processing
  that rewrites consistently-misheard words/phrases (whole-word,
  case-insensitive, capitalization-aware). Both features default off.

## [1.0.0] - 2026-01-03

### Added
- Wake word activation with "OK Claude" custom model
- Submit command with "Execute" custom model
- GPU-accelerated transcription via whisper.cpp (Vulkan/CUDA)
- Systemd user service with auto-start
- XDG-compliant file locations
- YAML configuration file
- System tray icon with visual state feedback (idle/listening/muted)
- Right-click menu: Mute/Unmute, View Logs, Quit
- Privacy toggle scripts (voice-claude-toggle, voice-claude-start, voice-claude-stop)
- Keyboard shortcut: Super+M to toggle mute (SIGUSR1 signal)
- Comprehensive documentation

### Technical Details
- Wake word detection: OpenWakeWord 0.4.0
- Speech transcription: whisper.cpp with small.en model
- Text injection: ydotool 0.1.8
- VAD: Silero VAD neural network (silero-vad-lite)
- Latency: ~1.8s on AMD RX 5700 XT
- Tray icon: AyatanaAppIndicator3 with GTK3

### Known Issues
- ALSA/JACK warnings in logs (cosmetic, not functional)
- Ubuntu mute/unmute can leave mic at 0% (use voice-claude-toggle instead)

## Development History

This project was developed in phases:

1. **Phase 1**: Wake word activation ("OK Claude" → speak → text)
2. **Phase 2**: Submit word ("Execute" → press Enter)
3. **Phase 3**: XDG migration, cleanup, Git repository setup
4. **Phase 4/5**: Privacy toggle (Super+M keyboard shortcut)
5. **Phase 6**: System tray icon with visual state feedback

See the [implementation plan](https://github.com/eumaios1212/voice-to-claude/wiki/Implementation-Plan) for detailed development notes.
