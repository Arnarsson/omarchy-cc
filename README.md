# Omarchy Command Center

Natural language command center for [Omarchy](https://omarchy.org/). Press a key, type what you want, and it happens.

```
> set theme tokyo night          # instant
> switch to sony headphones      # instant
> dim the screen a bit           # instant
> write a script to backup dots  # routes to Claude
```

## How it works

```
  Super+I
     │
     ▼
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Floating        │     │  Intent       │     │  Safety      │
│  Terminal (gum)  │ ──▶ │  Router       │ ──▶ │  Gate        │ ──▶ execute
│                  │     │              │     │              │
│  text or voice   │     │  1. patterns │     │  safe: auto  │
│                  │     │  2. keywords │     │  risky: ask  │
│                  │     │  3. ollama   │     │              │
│                  │     │  4. claude   │     │              │
└─────────────────┘     └──────────────┘     └──────────────┘
```

**Tier 1 — Pattern match** (~0ms): Static rules handle ~80% of commands instantly. Filler words are stripped ("can you please dim the screen" becomes "brightness down"), synonyms are normalized, and plurals are reduced.

**Tier 1.5 — Keyword scoring** (~0ms): Order-independent keyword matching catches anything patterns miss. "what's the current font" and "font current" both work.

**Tier 2 — Ollama** (~1-3s): Local LLM (qwen2.5-coder:7b) with a system prompt containing all omarchy commands, hyprctl dispatchers, and system context.

**Tier 3 — Claude CLI** (~5-15s): For complex, multi-step, or creative tasks. Triggered by "write a script", "explain", "help me", or "use claude".

## Install

Requires [Omarchy](https://omarchy.org/), [gum](https://github.com/charmbracelet/gum), and [Ollama](https://ollama.com/) with a model pulled.

```bash
git clone https://github.com/Arnarsson/omarchy-cc ~/.local/share/omarchy-cc

# Symlink scripts to PATH
for f in ~/.local/share/omarchy-cc/bin/*; do
  ln -sf "$f" ~/.local/bin/
done

# Symlink config
ln -sf ~/.local/share/omarchy-cc/config ~/.config/omarchy-cc

# Pull the Ollama model
ollama pull qwen2.5-coder:7b
```

Add to `~/.config/hypr/bindings.conf`:

```
bindd = SUPER, I, Command Center, exec, omarchy-cc-toggle
```

Add to `~/.config/hypr/hyprland.conf`:

```
windowrule = float on, match:title ^(Command Center)$
windowrule = size 700 500, match:title ^(Command Center)$
windowrule = center on, match:title ^(Command Center)$
windowrule = pin on, match:title ^(Command Center)$
windowrule = animation slide, match:title ^(Command Center)$
```

## Usage

Press **Super+I** to toggle. Type natural language:

| You type | It runs |
|----------|---------|
| `set theme catppuccin` | `omarchy-theme-set "catppuccin"` |
| `louder` | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` |
| `switch to sony headphones` | `pactl set-default-sink '<matched sink>'` |
| `next wallpaper` | `omarchy-theme-bg-next` |
| `dim the screen` | `brightnessctl set 10%-` |
| `fullscreen` | `hyprctl dispatch fullscreen` |
| `turn on the nightlight` | `omarchy-toggle-nightlight` |
| `take a screenshot` | `omarchy-cmd-screenshot smart` |
| `storage` | `df -h ...` |
| `lock screen` | `omarchy-lock-screen` |
| `restart waybar` | `omarchy-restart-waybar` |

### Meta commands

| Command | What it does |
|---------|-------------|
| `undo` | Reverse the last action |
| `again` | Repeat the last command |
| `last` | Show what you just ran |
| `history` or `/` | Fuzzy search past commands |
| `log` | Show activity log |
| `help` or `?` | Show help |
| `q` or `exit` | Close |

### Voice

Hold **Alt+X** to dictate (requires [voxtype](https://github.com/Arnarsson/voxtype)).

## Safety

Commands are classified as **safe** (auto-execute) or **risky** (confirm first).

**Safe:** themes, fonts, toggles, launches, volume, brightness, screenshots, window management, info queries.

**Risky:** package install/remove, system updates, restarts, reboot/shutdown, sudo, config writes.

## Configuration

`~/.config/omarchy-cc/config.toml`:

```toml
[general]
tts_enabled = false
ollama_model = "qwen2.5-coder:7b"
claude_enabled = true
history_size = 100

[safety]
auto_execute_safe = true
confirm_risky = true

[voice]
input_enabled = true
output_enabled = false
```

## Files

| File | Purpose |
|------|---------|
| `bin/omarchy-cc` | TUI loop (gum) |
| `bin/omarchy-cc-toggle` | Toggle window from keybinding |
| `bin/omarchy-cc-route` | Intent router (patterns + keywords + Ollama + Claude) |
| `bin/omarchy-cc-exec` | Safety gate + executor + logging |
| `bin/omarchy-cc-log` | Log viewer |
| `config/config.toml` | Settings |
| `config/safe-commands` | Auto-execute allowlist |

## License

MIT
