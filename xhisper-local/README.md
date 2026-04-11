<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux. This vendored fork uses **local whisper.cpp transcription** + **AI formatting** support - no API keys required!

**Original project by [imaginalnika](https://github.com/imaginalnika/xhisper)** - This fork adds local Whisper transcription and AI formatting.

## Features

- 🎤 **Local transcription** using whisper.cpp models (no cloud API)
- 🧠 **AI-powered formatting** via local LLM (Ollama) for grammar, punctuation, and context-aware correction
- 🔧 **Smart modes**: Auto-detects commands, or manual modes for email/standard text
- 🚀 **GPU acceleration** with Vulkan support
- 💻 **Works offline** after initial model download
- ⌨️ **Types at cursor** in any application

## Installation

### Dependencies

<details>
<summary>Arch Linux / Manjaro</summary>
<pre><code>sudo pacman -S pipewire ffmpeg gcc vulkan-icd-loader ollama whisper.cpp</code></pre>
</details>

<details>
<summary>Debian / Ubuntu / Pop!_OS</summary>
<pre><code>sudo apt update
sudo apt install pipewire ffmpeg gcc libvulkan1
# Install Ollama from https://ollama.com
curl -fsSL https://ollama.com/install.sh | sh
# Install whisper.cpp / whisper-cli from your package source</code></pre>
</details>

<details>
<summary>Fedora / RHEL / AlmaLinux / Rocky</summary>
<pre><code>sudo dnf install -y pipewire pipewire-utils ffmpeg gcc vulkan-loader ollama whisper-cpp</code></pre>
</details>

**Note:** `wl-clipboard` (Wayland) or `xclip` (X11) required for non-ASCII but usually pre-installed.

### Setup

1. **Add user to input group** to access `/dev/uinput`:
```sh
sudo usermod -aG input $USER
```
Then **log out and log back in** (restart is safer) for the group change to take effect.

Check by running:
```sh
groups
```
You should see `input` in the output.

2. **Install whisper.cpp** with `whisper-cli` available in `PATH`.

3. **Provide a ggml Whisper model**:
- either set `model-path` in `~/.config/xhisper/xhisperrc`
- or use the packaged default model when installed through Nix

4. **Pull AI formatting model** (Ollama):
```sh
ollama pull gemma3:4b
```

5. Clone the repository and install:
```sh
git clone https://git.bryantnet.net/william/xhisper-local.git
cd xhisper-local && make
sudo make install
```

6. Configure:
```sh
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
nano ~/.config/xhisper/xhisperrc
```

7. Set up keyboard shortcut (e.g., in COSMIC Settings → Keyboard → Custom Shortcuts):
```sh
xhisper                    # Auto mode (default)
xhisper --mode=command     # For terminal commands
xhisper --mode=email       # For email bodies
xhisper --mode=standard    # Plain text formatting
```

**Recommended shortcut:** `Alt+Shift+D` (avoids conflicts with browsers/editors)

---

## Usage

Simply run `xhisper` twice (via your keybinding):
- **First run**: Starts recording (shows `(recording...)`)
- **Second run**: Stops, transcribes, and formats (shows `(transcribing...)` then `(formatting...)`)

The formatted transcription will be typed at your cursor position.

**View logs:**
```sh
xhisper --log
```

**Non-QWERTY layouts:**

For non-QWERTY layouts (e.g. Dvorak, International), set up an input switch key to QWERTY (e.g. rightalt). Then bind to:
```sh
xhisper --<your-input-switch-key>
```

**Available input switch keys:** `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`

---

## Configuration

Configuration is read from `~/.config/xhisper/xhisperrc`:

### Whisper Settings
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `model-path` | Path to a ggml model file | leave empty to use packaged default |
| `model-device` | Device to use | `gpu` or `cpu` |
| `model-language` | Language code | `en` for the packaged default model |
| `transcription-prompt` | Context for accuracy | optional |

**Model format:** whisper.cpp expects a `ggml-*.bin` model file, such as `ggml-base.en.bin`.

### AI Formatting Settings
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `post-process-model` | Ollama model for formatting | `gemma3:4b` |
| `post-process-mode` | Detection mode | `auto` |
| `post-process-timeout` | Max seconds for formatting | `10` |

**Available modes:**
- `auto` - Detects context (commands vs text) automatically
- `standard` - Grammar, punctuation, capitalization
- `command` - Linux command syntax correction (e.g., "pseudo" → "sudo")
- `email` - Email body formatting with proper paragraph breaks

### Other Settings
- `silence-threshold`: Volume threshold for silence detection (dB, default -50)
- `non-ascii-*-delay`: Timing for Unicode character pasting

---

## Recommended Setup (Tested)

**Hardware:** AMD or NVIDIA GPU with a working Vulkan stack
**OS:** Linux with PipeWire and `/dev/uinput` access

| Component | Model/Setting | Notes |
|-----------|---------------|-------|
| Whisper | `ggml-base.en.bin` | Fast and accurate |
| Device | `auto` | GPU first, CPU fallback |
| Formatter | `gemma3:4b` | Excellent grammar/punctuation |
| Mode | `auto` | Detects commands automatically |

This setup achieves ~1 second transcription + ~1 second formatting for short recordings.

---

## Troubleshooting

**Terminal Applications**: Clipboard paste uses Ctrl+V, which doesn't work in terminal emulators (they require Ctrl+Shift+V). Remap Ctrl+V to paste in your terminal's settings, or use `--mode=command` for pure command transcription.

**GPU not detected**: Ensure a working Vulkan stack is installed. Set `model-device : cpu` to force CPU mode.

**Formatting not working**: Ensure Ollama is running and the model is pulled (`ollama pull gemma3:4b`).

**Keyboard shortcut conflicts**: Avoid `Ctrl+Space` or `Alt+Space` as they conflict with browsers. Use `Alt+Shift+D` or `Ctrl+Alt+D` instead.

**First run is slow**: Model loading and shader compilation can take longer on the first GPU run. Ollama models are cached in `~/.ollama/models/`.

---

## Changes from upstream

This is a fork of [xhisper](https://github.com/imaginalnika/xhisper) by [imaginalnika](https://github.com/imaginalnika). The original project used the Groq API for transcription. This fork adds:

- **Local Whisper transcription** via `whisper.cpp` (no Groq API)
- **AI formatting** with local LLM support via Ollama
- **Smart mode detection** for commands vs text
- **Multiple formatting modes** (auto, standard, command, email)
- **GPU acceleration** for transcription via whisper.cpp and formatting via Ollama
- **Works completely offline** after model download

---

<p align="center">
  <em>Low complexity dictation for Linux with AI-powered formatting</em>
  <br><br>
  Forked from <a href="https://github.com/imaginalnika/xhisper">xhisper</a> by <a href="https://github.com/imaginalnika">imaginalnika</a>
</p>
