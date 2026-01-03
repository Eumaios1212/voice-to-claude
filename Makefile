# Voice Claude Makefile

.PHONY: install dev uninstall test lint clean help

# Default target
help:
	@echo "Voice Claude - Makefile targets"
	@echo ""
	@echo "  install    Install to ~/.local (production)"
	@echo "  dev        Symlink scripts for development"
	@echo "  uninstall  Remove all installed files"
	@echo "  test       Run manual test checklist"
	@echo "  lint       Run linters (shellcheck, pylint)"
	@echo "  clean      Remove generated files"
	@echo ""

# Production install
install:
	@./install.sh

# Development install (symlinks for easy editing)
dev:
	@echo "Creating development symlinks..."
	@mkdir -p ~/.local/bin
	@ln -sf $(PWD)/bin/voice-claude-daemon ~/.local/bin/voice-claude-daemon
	@echo "Symlink created. Edit files in bin/ directly."

# Uninstall
uninstall:
	@echo "Stopping service..."
	-systemctl --user stop voice-claude 2>/dev/null
	-systemctl --user disable voice-claude 2>/dev/null
	@echo "Removing files..."
	rm -f ~/.local/bin/voice-claude-daemon
	rm -rf ~/.local/share/voice-claude
	rm -rf ~/.config/voice-claude
	rm -f ~/.config/systemd/user/voice-claude.service
	systemctl --user daemon-reload
	@echo "Uninstall complete."

# Manual test checklist
test:
	@echo "Voice Claude Test Checklist"
	@echo "==========================="
	@echo ""
	@echo "1. Service Status"
	@systemctl --user status voice-claude --no-pager | head -5
	@echo ""
	@echo "2. Manual Tests (perform these yourself):"
	@echo "   [ ] Say 'OK Claude' - should show notification"
	@echo "   [ ] Speak a message - should transcribe after silence"
	@echo "   [ ] Say 'Execute' - should press Enter"
	@echo ""
	@echo "3. Debug mode:"
	@echo "   systemctl --user stop voice-claude"
	@echo "   voice-claude-daemon --debug"
	@echo ""

# Lint scripts
lint:
	@echo "Running pylint on daemon..."
	-pylint --disable=C0114,C0115,C0116 bin/voice-claude-daemon

# Clean generated files
clean:
	rm -f systemd/voice-claude.service
	rm -rf __pycache__
	rm -f *.pyc
	find . -name "*.wav" -delete
