# Troubleshooting Guide

## Common Issues

### 1. Wake word not detecting

**Symptoms**: Saying "OK Claude" doesn't trigger listening mode

**Solutions**:

```bash
# Check if service is running
systemctl --user status voice-claude

# Run in debug mode to see detection scores
systemctl --user stop voice-claude
voice-claude-daemon --debug
# Speak "OK Claude" and watch the scores
```

If scores are low (<0.3), try:
- Speaking more clearly
- Lowering the threshold in config.yaml
- Checking microphone levels

### 2. Text not appearing / ydotool errors

**Symptoms**: Transcription works but text doesn't appear in window

**Solutions**:

```bash
# Check if user is in input group
groups
# Should include 'input'

# Test ydotool manually
ydotool type "hello world"

# If permission denied, check udev rule
ls -la /dev/uinput
# Should show: crw-rw---- 1 root input ...

# Verify udev rule exists
cat /etc/udev/rules.d/99-uinput.rules
```

If issues persist, **log out and back in** (group changes require re-login).

### 3. Speech cut off early

**Symptoms**: Recording stops before you finish speaking

**Causes**:
- Mic volume too low
- VAD silence threshold too sensitive

**Solutions**:

```bash
# Check mic volume
amixer -c 2 get Mic  # Adjust card number as needed
# Should be 100%

# Set mic volume
amixer -c 2 set Mic 100%

# Adjust VAD settings in config.yaml
vad:
  silence_threshold: 300   # Lower = more sensitive to speech
  silence_duration: 2.0    # Longer = waits more for silence
```

### 4. Transcription too slow

**Symptoms**: Takes >5 seconds to transcribe

**Solutions**:

```bash
# Check if GPU is being used
# Run whisper-cli manually and watch output
~/.local/bin/whisper-cli -m ~/.local/share/whisper/models/ggml-small.en.bin -f test.wav

# Look for "Vulkan" or "CUDA" in output
# If only CPU, rebuild whisper.cpp with GPU support

# Or use smaller model (less accurate but faster)
# In config.yaml:
whisper:
  model: ~/.local/share/whisper/models/ggml-tiny.en.bin
```

### 5. False positives (wake word triggers incorrectly)

**Symptoms**: Daemon activates without saying wake word

**Solutions**:

```yaml
# Increase threshold in config.yaml
wake_words:
  ok_claude_threshold: 0.6  # Higher = fewer false positives
  execute_threshold: 0.6
  cooldown: 3.0             # Longer cooldown between detections
```

### 6. Service crashes on startup

**Symptoms**: `systemctl --user status voice-claude` shows failed

**Solutions**:

```bash
# Check logs
journalctl --user -u voice-claude -n 50

# Common causes:
# - Missing Python dependencies
# - Wrong venv path in shebang
# - Missing model files

# Verify venv works
~/.local/share/voice-claude/venv/bin/python3 -c "import openwakeword; print('OK')"

# Verify model paths
ls -la ~/.local/share/voice-claude/models/
ls -la ~/.local/share/whisper/models/
```

### 7. ALSA/JACK warnings in logs

**Symptoms**: Logs full of ALSA errors like "unable to open slave"

**Reality**: These are **normal** - PyAudio probes all available audio backends. As long as the service is "active (running)", these warnings can be ignored.

### 8. Ubuntu mute breaks audio

**Symptoms**: After muting/unmuting in Ubuntu, daemon can't hear

**Cause**: Ubuntu's mute sets ALSA capture volume to 0% and doesn't restore it

**Solution**: Use service stop/start instead of system mute:

```bash
# Stop listening (better than mute)
systemctl --user stop voice-claude

# Resume listening (auto-restores mic volume via ExecStartPre)
systemctl --user start voice-claude
```

## Debug Mode

For any issue, running in debug mode provides detailed output:

```bash
systemctl --user stop voice-claude
voice-claude-daemon --debug
```

This shows:
- Wake word detection scores
- VAD state (recording/silence)
- Transcription output
- ydotool commands

## Getting Help

1. Check logs: `journalctl --user -u voice-claude -f`
2. Run debug mode (above)
3. Open an issue with:
   - Debug output
   - System info (`uname -a`, `python3 --version`)
   - Audio setup (`arecord -l`)
