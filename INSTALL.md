# Installation Guide

## System Requirements

- **OS**: Linux (tested on Ubuntu 24.04)
- **Desktop**: GNOME/Wayland (ydotool works on X11 too)
- **Audio**: PulseAudio or PipeWire
- **Python**: 3.8 or later
- **GPU**: Optional but recommended (Vulkan for AMD, CUDA for NVIDIA)

## Step 1: Install System Dependencies

```bash
# Core dependencies
sudo apt install -y \
    build-essential \
    cmake \
    git \
    python3-venv \
    python3-dev \
    portaudio19-dev \
    ffmpeg \
    alsa-utils

# GTK/AppIndicator for system tray icon
sudo apt install -y \
    gir1.2-ayatanaappindicator3-0.1 \
    python3-gi \
    python3-gi-cairo

# ydotool for text injection
sudo apt install -y ydotool

# Add user to input group (required for ydotool)
sudo usermod -aG input $USER

# Create udev rule for uinput access
sudo tee /etc/udev/rules.d/99-uinput.rules << 'EOF'
KERNEL=="uinput", MODE="0660", GROUP="input"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# IMPORTANT: Log out and back in for group changes to take effect
```

## Step 2: Build whisper.cpp

```bash
cd ~/repos  # or your preferred location

# Clone whisper.cpp
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp

# Build with Vulkan (AMD GPU) - recommended
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j$(nproc)

# OR build with CUDA (NVIDIA GPU)
# cmake -B build -DGGML_CUDA=ON
# cmake --build build --config Release -j$(nproc)

# OR build CPU-only
# cmake -B build
# cmake --build build --config Release -j$(nproc)
```

## Step 3: Install Whisper Libraries and Binary

```bash
cd whisper.cpp

# Copy shared libraries to ~/.local/lib (required for whisper-cli)
mkdir -p ~/.local/lib
cp -P build/src/libwhisper.so* ~/.local/lib/
cp -P build/ggml/src/libggml*.so* ~/.local/lib/
cp -P build/ggml/src/ggml-vulkan/libggml-vulkan.so* ~/.local/lib/  # if using Vulkan

# Copy the CLI binary
cp build/bin/whisper-cli ~/.local/bin/
chmod +x ~/.local/bin/whisper-cli
```

## Step 4: Download Whisper Model

```bash
# Download small.en model (466 MB, recommended balance of speed/accuracy)
./models/download-ggml-model.sh small.en

# Copy to XDG location
mkdir -p ~/.local/share/whisper/models
cp models/ggml-small.en.bin ~/.local/share/whisper/models/
```

## Step 5: Install Voice Claude

```bash
# Clone this repository
git clone https://github.com/eumaios1212/voice-to-claude
cd voice-to-claude

# Run the installer
./install.sh
```

## Verification

```bash
# Check service status
systemctl --user status voice-claude

# Look for the tray icon (microphone icon in system tray)

# Test wake word
# Say "OK Claude" - tray icon should change to "listening" state

# Test transcription
# Speak a message after the wake word - text appears in focused window

# Test execute
# Say "Execute" - should press Enter

# Test mute toggle
# Press Super+M or right-click tray icon → Mute

# View logs
journalctl --user -u voice-claude -f
```

## Troubleshooting

### ydotool "permission denied"

Make sure you're in the `input` group and have logged out/in:

```bash
groups  # Should include 'input'
```

### No audio detected

Check your microphone:

```bash
# List audio devices
arecord -l

# Test recording
arecord -d 3 -f S16_LE -r 16000 test.wav
aplay test.wav
```

### Wake word not detecting

Run the daemon in debug mode:

```bash
systemctl --user stop voice-claude
voice-claude-daemon --debug
```

### Tray icon not showing

Make sure the AppIndicator extension is enabled in GNOME:

```bash
# Check if package is installed
dpkg -l | grep ayatana

# On GNOME, you may need the AppIndicator extension
gnome-extensions enable ubuntu-appindicators@ubuntu.com
```

### GPU not being used

Check if Vulkan is available:

```bash
vulkaninfo | head -20
```

For whisper.cpp GPU issues, see their [GitHub issues](https://github.com/ggerganov/whisper.cpp/issues).

## Uninstall

```bash
# Stop and disable service
systemctl --user stop voice-claude
systemctl --user disable voice-claude

# Remove files
rm -rf ~/.local/bin/voice-claude*
rm -rf ~/.local/bin/whisper-cli
rm -rf ~/.local/share/voice-claude
rm -rf ~/.local/share/whisper
rm -rf ~/.config/voice-claude
rm ~/.config/systemd/user/voice-claude.service

# Reload systemd
systemctl --user daemon-reload
```
