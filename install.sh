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

# ensure_keybinding NAME COMMAND BINDING
# Idempotently register a GNOME custom keyboard shortcut. Safe to re-run: if a
# shortcut with the same COMMAND already exists, its slot is updated in place
# instead of creating a duplicate.
ensure_keybinding() {
    local name="$1" command="$2" binding="$3"
    local base="org.gnome.settings-daemon.plugins.media-keys"
    local path_prefix="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom"
    local existing path existing_cmd found="" slot=0 new_list

    existing=$(gsettings get "$base" custom-keybindings 2>/dev/null || echo "@as []")

    # Reuse the existing slot if this command is already bound
    for path in $(echo "$existing" | grep -oE "${path_prefix}[0-9]+/"); do
        existing_cmd=$(gsettings get "$base.custom-keybinding:$path" command 2>/dev/null)
        if [[ "$existing_cmd" == "'$command'" ]]; then
            found="$path"
            break
        fi
    done

    # Otherwise claim the next free slot and append it to the list
    if [[ -z "$found" ]]; then
        while [[ "$existing" == *"custom$slot/"* ]]; do
            slot=$((slot + 1))
        done
        found="${path_prefix}$slot/"
        if [[ "$existing" == "@as []" ]]; then
            new_list="['$found']"
        else
            # Strip trailing ] and append the new path
            new_list="${existing%]*}, '$found']"
        fi
        gsettings set "$base" custom-keybindings "$new_list"
    fi

    gsettings set "$base.custom-keybinding:$found" name "$name"
    gsettings set "$base.custom-keybinding:$found" command "$command"
    gsettings set "$base.custom-keybinding:$found" binding "$binding"
}

echo -e "${YELLOW}Setting up keyboard shortcuts (Super+M, Super+C)...${NC}"
ensure_keybinding 'Voice Claude Toggle' "$BIN_DIR/voice-claude-toggle" '<Super>m'
ensure_keybinding 'Voice Claude Dictate' 'systemctl --user kill --signal=SIGUSR2 voice-claude.service' '<Super>c'
echo -e "${GREEN}Keyboard shortcuts configured: Super+M (toggle), Super+C (dictate)${NC}"

echo
echo -e "${GREEN}Installation complete!${NC}"
echo
echo -e "${GREEN}Voice Claude is now running. Try saying 'OK Claude' to test.${NC}"
echo
echo "Commands:"
echo "  Super+C                                 # Dictate now (skip the wake word)"
echo "  Super+M                                 # Toggle listening on/off"
echo "  systemctl --user status voice-claude   # Check status"
echo "  journalctl --user -u voice-claude -f   # View logs"
