# Training Custom Wake Words

This project uses [OpenWakeWord](https://github.com/dscripka/openWakeWord) for wake word detection. Custom wake words can be trained using their Google Colab notebook.

## Pre-trained Models Included

| Model | Wake Word | Purpose |
|-------|-----------|---------|
| `ok_claude.onnx` | "OK Claude" | Activates listening mode |
| `execute.onnx` | "Execute" | Presses Enter to submit |

## Training Your Own Wake Word

### Using Google Colab (Recommended)

1. Open the [OpenWakeWord Training Notebook](https://colab.research.google.com/drive/1q1oe2zOyZp7UsB3jJiQ1IFn8z5YfjwEb)

2. Configure training parameters:
   ```python
   # Recommended settings (used for ok_claude and execute models)
   target_phrase = "your wake word"
   num_examples = 1000      # Synthetic training examples
   training_steps = 10000   # Training iterations
   ```

3. Run all cells and download the generated `.onnx` file

4. Copy to models directory:
   ```bash
   cp your_model.onnx ~/.local/share/voice-claude/models/
   ```

5. Update `config.yaml` to use your new model

### Training Tips

- **Phrase selection**: 2-3 syllables work best (e.g., "Hey Claude", "OK Claude")
- **Avoid common words**: Reduces false positives
- **Test thoroughly**: Run with `--debug` to see detection scores
- **Adjust threshold**: Lower = more sensitive, higher = fewer false positives

## Model Parameters Used

For the included models, we used:

```python
# ok_claude.onnx
target_phrase = "ok claude"
num_examples = 1000
training_steps = 10000
model_type = "verifier"  # Better accuracy, slightly higher latency

# execute.onnx
target_phrase = "execute"
num_examples = 1000
training_steps = 10000
model_type = "verifier"
```

## Testing Your Model

```bash
# Stop the daemon
systemctl --user stop voice-claude

# Run in debug mode
voice-claude-daemon --debug

# Watch the detection scores in the output
# Speak your wake word and note the score
# Adjust threshold in config.yaml accordingly
```

## Threshold Tuning

In `~/.config/voice-claude/config.yaml`:

```yaml
wake_words:
  ok_claude_threshold: 0.5  # Increase to reduce false positives
  execute_threshold: 0.5    # Decrease to improve detection
```

Recommended range: 0.3 - 0.7
