#!/bin/bash
#
# Voice Claude Installer
#
# Installs voice-claude to XDG-compliant locations and sets up systemd service.
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# XDG directories
BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/voice-claude"
CONFIG_DIR="$HOME/.config/voice-claude"
SYSTEMD_DIR="$HOME/.config/systemd/user"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Voice Claude Installer${NC}"
echo "========================"
echo

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
missing=()

command -v python3 >/dev/null 2>&1 || missing+=("python3")
command -v ydotool >/dev/null 2>&1 || missing+=("ydotool")
command -v ffmpeg >/dev/null 2>&1 || missing+=("ffmpeg")
command -v arecord >/dev/null 2>&1 || missing+=("arecord (alsa-utils)")
command -v notify-send >/dev/null 2>&1 || missing+=("notify-send (libnotify-bin)")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}Missing dependencies:${NC}"
    printf '  - %s\n' "${missing[@]}"
    echo
    echo "Install with: sudo apt install python3 ydotool ffmpeg alsa-utils libnotify-bin"
    exit 1
fi

# Check whisper-cli
if [[ ! -x "$BIN_DIR/whisper-cli" ]]; then
    echo -e "${RED}whisper-cli not found at $BIN_DIR/whisper-cli${NC}"
    echo "Please build whisper.cpp and copy whisper-cli to ~/.local/bin/"
    echo "See INSTALL.md for instructions."
    exit 1
fi

# Check whisper model
WHISPER_MODEL="$HOME/.local/share/whisper/models/ggml-small.en.bin"
if [[ ! -f "$WHISPER_MODEL" ]]; then
    echo -e "${RED}Whisper model not found at $WHISPER_MODEL${NC}"
    echo "Please download a model and copy it to ~/.local/share/whisper/models/"
    echo "See INSTALL.md for instructions."
    exit 1
fi

# Check input group
if ! groups | grep -q '\binput\b'; then
    echo -e "${YELLOW}Warning: User is not in 'input' group${NC}"
    echo "ydotool may not work. Run: sudo usermod -aG input \$USER"
    echo "Then log out and back in."
    echo
fi

echo -e "${GREEN}Dependencies OK${NC}"
echo

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$BIN_DIR"
mkdir -p "$DATA_DIR/models"
mkdir -p "$DATA_DIR/venv"
mkdir -p "$CONFIG_DIR"
mkdir -p "$SYSTEMD_DIR"

# Create Python venv
echo -e "${YELLOW}Creating Python virtual environment...${NC}"
if [[ ! -d "$DATA_DIR/venv/bin" ]]; then
    python3 -m venv "$DATA_DIR/venv"
fi

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
"$DATA_DIR/venv/bin/pip" install --quiet --upgrade pip
"$DATA_DIR/venv/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"

# Copy daemon script
echo -e "${YELLOW}Installing daemon...${NC}"
cp "$SCRIPT_DIR/bin/voice-claude-daemon" "$BIN_DIR/"
chmod +x "$BIN_DIR/voice-claude-daemon"

# Update daemon shebang to use installed venv
sed -i "1s|.*|#!$DATA_DIR/venv/bin/python3|" "$BIN_DIR/voice-claude-daemon"

# Copy toggle scripts (privacy controls)
echo -e "${YELLOW}Installing toggle scripts...${NC}"
cp "$SCRIPT_DIR/bin/voice-claude-start" "$BIN_DIR/"
cp "$SCRIPT_DIR/bin/voice-claude-stop" "$BIN_DIR/"
cp "$SCRIPT_DIR/bin/voice-claude-toggle" "$BIN_DIR/"
chmod +x "$BIN_DIR/voice-claude-start" "$BIN_DIR/voice-claude-stop" "$BIN_DIR/voice-claude-toggle"

# Copy wake word models
echo -e "${YELLOW}Installing wake word models...${NC}"
cp "$SCRIPT_DIR/models/"*.onnx "$DATA_DIR/models/"

# Create config if doesn't exist
if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
    echo -e "${YELLOW}Creating configuration file...${NC}"
    cp "$SCRIPT_DIR/config/config.example.yaml" "$CONFIG_DIR/config.yaml"
fi

# Create systemd service
echo -e "${YELLOW}Creating systemd service...${NC}"
VENV_PATH="$DATA_DIR/venv"
sed "s|VENV_PATH|$VENV_PATH|g" "$SCRIPT_DIR/systemd/voice-claude.service.template" > "$SYSTEMD_DIR/voice-claude.service"

# Reload and enable service
echo -e "${YELLOW}Enabling systemd service...${NC}"
systemctl --user daemon-reload
systemctl --user enable voice-claude
systemctl --user start voice-claude

# Set up keyboard shortcut (Super+M to toggle)
echo -e "${YELLOW}Setting up keyboard shortcut (Super+M)...${NC}"

# Get existing custom keybindings
EXISTING=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")

# Check if voice-claude shortcut already exists
if [[ "$EXISTING" != *"voice-claude"* ]]; then
    # Find next available slot (custom0, custom1, etc.)
    SLOT=0
    while [[ "$EXISTING" == *"custom$SLOT"* ]]; do
        ((SLOT++))
    done

    KEYBINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom$SLOT/"

    # Add to list of custom keybindings
    if [[ "$EXISTING" == "@as []" ]]; then
        NEW_LIST="['$KEYBINDING_PATH']"
    else
        # Remove trailing ] and add new entry
        NEW_LIST="${EXISTING%]*}, '$KEYBINDING_PATH']"
    fi

    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW_LIST"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYBINDING_PATH name 'Voice Claude Toggle'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYBINDING_PATH command "$BIN_DIR/voice-claude-toggle"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYBINDING_PATH binding '<Super>m'

    echo -e "${GREEN}Keyboard shortcut configured: Super+M${NC}"
else
    echo "Keyboard shortcut already configured"
fi

echo
echo -e "${GREEN}Installation complete!${NC}"
echo
echo -e "${GREEN}Voice Claude is now running. Try saying 'OK Claude' to test.${NC}"
echo
echo "Commands:"
echo "  Super+M                                 # Toggle listening on/off"
echo "  systemctl --user status voice-claude   # Check status"
echo "  journalctl --user -u voice-claude -f   # View logs"
