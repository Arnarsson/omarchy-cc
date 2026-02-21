# 10x Omarchy Command Center — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the Command Center from a working prototype into a fast, reliable, tested, and polished desktop command system.

**Architecture:** Keep the multi-tier routing (patterns → keywords → Ollama → Claude) but make each tier testable in isolation, add a proper test harness, fix UX pain points, and add tmux resource monitoring inspired by tmux-task-monitor.

**Tech Stack:** Bash, gum 0.17, bats-core (testing), jq, tmux, Python 3 + psutil (tmux monitor), Ollama, Claude CLI

---

## Overview — What "10x" Means

| Area | Now | After |
|------|-----|-------|
| **Tests** | Zero | Full test suite covering routing, execution, safety, preprocessing |
| **Reliability** | Commands randomly fail silently | Every failure surfaces with clear feedback |
| **Speed** | Context gathering blocks every LLM call (~300ms) | Lazy context: only gather what's needed |
| **Router** | 975-line monolith | Modular functions, each independently testable |
| **tmux** | Basic list/kill table | Resource monitor with CPU/mem per session (tmux-task-monitor style) |
| **UX** | 5s blocking copy prompt after every command | Non-blocking keybindings, persistent status line |
| **Config** | grep+sed per key on every read | Single parse at startup |
| **History** | Flat text file | Frecency-scored (frequency × recency) |
| **Feedback** | Plain text | Compact one-line status with timing info |
| **Errors** | Mixed set -e / set +e | Consistent: never crash the TUI, always show error |

---

## Task 1: Add Test Framework (bats-core)

**Files:**
- Create: `tests/test_helper.bash`
- Create: `tests/route.bats`
- Create: `tests/exec.bats`
- Create: `tests/preprocess.bats`
- Create: `Makefile` (test runner)

**Why:** Zero tests means zero confidence. Every subsequent change needs a safety net.

**Step 1: Install bats-core**

```bash
# Check if bats is available
which bats || yay -S --noconfirm bats
```

**Step 2: Create test helper that sources route functions in isolation**

Create `tests/test_helper.bash`:
```bash
#!/bin/bash
# Source just the functions from omarchy-cc-route without running main()
# We extract functions by sourcing with a guard

export OMARCHY_CC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CONFIG_DIR="$OMARCHY_CC_DIR/config"
export CACHE_DIR="$(mktemp -d)"
export PATH="$OMARCHY_CC_DIR/bin:$PATH"

# Source route functions by extracting them
source_functions() {
  local script="$1"
  # Create a version that doesn't call main
  local tmp
  tmp=$(mktemp)
  sed 's/^main "\$@"$//' "$script" > "$tmp"
  source "$tmp"
  rm "$tmp"
}
```

**Step 3: Write preprocessing tests**

Create `tests/preprocess.bats`:
```bash
#!/usr/bin/env bats
load test_helper

setup() {
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-route"
}

@test "normalize lowercases input" {
  result=$(normalize "SET THEME Tokyo Night")
  [ "$result" = "set theme tokyo night" ]
}

@test "strip_filler removes 'can you please'" {
  result=$(strip_filler "can you please set the theme")
  [ "$result" = "set theme" ]
}

@test "strip_filler removes 'would you'" {
  result=$(strip_filler "would you dim the screen")
  [ "$result" = "dim screen" ]
}

@test "normalize_synonyms: louder → volume up" {
  result=$(normalize_synonyms "louder")
  [ "$result" = "volume up" ]
}

@test "normalize_synonyms: dim → brightness down" {
  result=$(normalize_synonyms "dim")
  [ "$result" = "brightness down" ]
}

@test "normalize_synonyms: maximize → fullscreen" {
  result=$(normalize_synonyms "maximize")
  [ "$result" = "fullscreen" ]
}

@test "normalize_synonyms: turn on → toggle" {
  result=$(normalize_synonyms "turn on nightlight")
  [ "$result" = "toggle nightlight" ]
}

@test "full preprocess pipeline: 'can you please make it a bit louder' → 'volume up'" {
  result=$(preprocess "can you please make it a bit louder")
  [ "$result" = "volume up" ]
}

@test "full preprocess pipeline: 'would you dim the screen a little' → 'brightness down'" {
  result=$(preprocess "would you dim the screen a little")
  [ "$result" = "brightness down" ]
}
```

**Step 4: Write pattern matching tests**

Create `tests/route.bats`:
```bash
#!/usr/bin/env bats
load test_helper

setup() {
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-route"
}

# --- Pattern matching ---

@test "pattern: 'set theme tokyo night'" {
  result=$(pattern_match "set theme tokyo night")
  [ "$result" = 'omarchy-theme-set "tokyo night"' ]
}

@test "pattern: 'volume up'" {
  result=$(pattern_match "volume up")
  [ "$result" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" ]
}

@test "pattern: 'volume down'" {
  result=$(pattern_match "volume down")
  [ "$result" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" ]
}

@test "pattern: 'mute'" {
  result=$(pattern_match "mute")
  [ "$result" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ]
}

@test "pattern: 'brightness up'" {
  result=$(pattern_match "brightness up")
  [ "$result" = "brightnessctl set 10%+" ]
}

@test "pattern: 'screenshot'" {
  result=$(pattern_match "screenshot")
  [ "$result" = "omarchy-cmd-screenshot smart" ]
}

@test "pattern: 'next wallpaper'" {
  result=$(pattern_match "next wallpaper")
  [ "$result" = "omarchy-theme-bg-next" ]
}

@test "pattern: 'fullscreen'" {
  result=$(pattern_match "fullscreen")
  [ "$result" = "hyprctl dispatch fullscreen" ]
}

@test "pattern: 'lock screen'" {
  result=$(pattern_match "lock screen")
  [ "$result" = "omarchy-lock-screen" ]
}

@test "pattern: 'storage'" {
  result=$(pattern_match "storage")
  [[ "$result" == *"df -h"* ]]
}

@test "pattern: 'tmux'" {
  result=$(pattern_match "tmux")
  [ "$result" = "omarchy-cc-tmux" ]
}

@test "pattern: unknown returns failure" {
  run pattern_match "quantum flux capacitor"
  [ "$status" -eq 1 ]
}

# --- Keyword matching ---

@test "keyword: 'what is the current theme'" {
  result=$(keyword_match "what is the current theme")
  [ "$result" = "omarchy-theme-current" ]
}

@test "keyword: 'show me all fonts'" {
  result=$(keyword_match "show me all fonts")
  [ "$result" = "omarchy-font-list" ]
}

@test "keyword: 'toggle the night light'" {
  result=$(keyword_match "toggle the night light")
  [ "$result" = "omarchy-toggle-nightlight" ]
}

@test "keyword: 'open browser'" {
  result=$(keyword_match "open browser")
  [ "$result" = "omarchy-launch-browser" ]
}
```

**Step 5: Write safety classification tests**

Create `tests/exec.bats`:
```bash
#!/usr/bin/env bats
load test_helper

setup() {
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-exec"
}

# --- Safety classification ---

@test "safe: omarchy-theme-set" {
  run is_safe "omarchy-theme-set catppuccin"
  [ "$status" -eq 0 ]
}

@test "safe: wpctl" {
  run is_safe "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
  [ "$status" -eq 0 ]
}

@test "safe: hyprctl dispatch" {
  run is_safe "hyprctl dispatch fullscreen"
  [ "$status" -eq 0 ]
}

@test "safe: date" {
  run is_safe "date '+%H:%M'"
  [ "$status" -eq 0 ]
}

@test "safe: df" {
  run is_safe "df -h"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-update" {
  run is_risky "omarchy-update"
  [ "$status" -eq 0 ]
}

@test "risky: sudo" {
  run is_risky "sudo pacman -Syu"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-restart-waybar" {
  run is_risky "omarchy-restart-waybar"
  [ "$status" -eq 0 ]
}

@test "risky: rm" {
  run is_risky "rm -rf /tmp/stuff"
  [ "$status" -eq 0 ]
}

@test "not risky: omarchy-theme-current" {
  run is_risky "omarchy-theme-current"
  [ "$status" -eq 1 ]
}

# --- Undo state ---

@test "undo: volume up → volume down" {
  result=$(capture_undo_state "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")
  [ "$result" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" ]
}

@test "undo: volume down → volume up" {
  result=$(capture_undo_state "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
  [ "$result" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" ]
}

@test "undo: brightness up → brightness down" {
  result=$(capture_undo_state "brightnessctl set 10%+")
  [ "$result" = "brightnessctl set 10%-" ]
}

@test "undo: toggle is self-inverse" {
  result=$(capture_undo_state "omarchy-toggle-nightlight")
  [ "$result" = "omarchy-toggle-nightlight" ]
}

# --- Interactive detection ---

@test "interactive: omarchy-menu" {
  run is_interactive "omarchy-menu"
  [ "$status" -eq 0 ]
}

@test "interactive: omarchy-pkg-install" {
  run is_interactive "omarchy-pkg-install"
  [ "$status" -eq 0 ]
}

@test "not interactive: date" {
  run is_interactive "date"
  [ "$status" -eq 1 ]
}
```

**Step 6: Create Makefile**

Create `Makefile`:
```makefile
.PHONY: test test-route test-exec test-preprocess

test:
	bats tests/

test-preprocess:
	bats tests/preprocess.bats

test-route:
	bats tests/route.bats

test-exec:
	bats tests/exec.bats
```

**Step 7: Run tests, verify they pass**

```bash
cd ~/.local/share/omarchy-cc && make test
```

**Step 8: Commit**

```bash
git add tests/ Makefile
git commit -m "feat: add bats test suite for routing, execution, and preprocessing"
```

---

## Task 2: Fix the Copy UX (Remove 5s Blocking Prompt)

**Files:**
- Modify: `bin/omarchy-cc` (lines 226-234 — copy action bar)

**Problem:** After every command, there's a `read -rsn1 -t 5` that blocks the TUI for 5 seconds waiting for `c` keypress. This makes the CC feel sluggish.

**Fix:** Remove the blocking copy prompt entirely. Instead:
1. Always save last output to a file
2. `copy` / `cp` command already works — that's enough
3. Add a subtle hint in the prompt placeholder instead

**Step 1: Write test confirming copy_pane works**

Add to `tests/route.bats` or new `tests/cc.bats`:
```bash
@test "copy_pane copies session log when not in tmux" {
  unset TMUX
  echo "test output" > "$CACHE_DIR/session-output"
  # Mock wl-copy
  wl-copy() { cat > "$CACHE_DIR/clipboard"; }
  export -f wl-copy
  copy_pane
  [ "$(cat "$CACHE_DIR/clipboard")" = "test output" ]
}
```

**Step 2: Remove the blocking copy bar from process_input()**

Replace lines 226-234 in `omarchy-cc`:
```bash
  # OLD: blocking 5s copy prompt
  echo ""
  gum style --foreground 8 --faint "  [c] copy all"
  local key
  read -rsn1 -t 5 key 2>/dev/null || key=""
  if [[ "$key" == "c" || "$key" == "C" ]]; then
    copy_pane
  fi
```

With just:
```bash
  # Output saved for "copy" command — no blocking prompt
```

**Step 3: Update the gum input placeholder to hint at copy**

Change the placeholder from `"What do you want to do?"` to `"Type a command (copy to clipboard)"`.

**Step 4: Run tests, verify**

```bash
make test
```

**Step 5: Commit**

```bash
git add bin/omarchy-cc
git commit -m "fix: remove blocking 5s copy prompt, use 'copy' command instead"
```

---

## Task 3: Faster Config Parsing

**Files:**
- Create: `bin/omarchy-cc-config` (shared config parser)
- Modify: `bin/omarchy-cc` (use new parser)
- Modify: `bin/omarchy-cc-route` (use new parser)
- Modify: `bin/omarchy-cc-exec` (use new parser)
- Create: `tests/config.bats`

**Problem:** Every script runs `grep + sed + tr + xargs` per config key. Three scripts × multiple keys = 15+ subprocesses at startup just to read config.

**Fix:** Single script that parses config.toml once and exports all values.

**Step 1: Create `bin/omarchy-cc-config`**

```bash
#!/bin/bash
# Parse omarchy-cc config and export values.
# Usage: eval "$(omarchy-cc-config)"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-cc/config.toml"

# Defaults
CC_TTS_ENABLED=false
CC_OLLAMA_MODEL="qwen2.5-coder:7b"
CC_CLAUDE_ENABLED=true
CC_HISTORY_SIZE=100
CC_AUTO_EXECUTE_SAFE=true
CC_CONFIRM_RISKY=true
CC_VOICE_INPUT=true
CC_VOICE_OUTPUT=false

if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs | tr -d '"')
    [[ -z "$key" || "$key" == \#* || "$key" == \[* ]] && continue
    case "$key" in
      tts_enabled)        CC_TTS_ENABLED="$value" ;;
      ollama_model)       CC_OLLAMA_MODEL="$value" ;;
      claude_enabled)     CC_CLAUDE_ENABLED="$value" ;;
      history_size)       CC_HISTORY_SIZE="$value" ;;
      auto_execute_safe)  CC_AUTO_EXECUTE_SAFE="$value" ;;
      confirm_risky)      CC_CONFIRM_RISKY="$value" ;;
      input_enabled)      CC_VOICE_INPUT="$value" ;;
      output_enabled)     CC_VOICE_OUTPUT="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# Export all
for var in CC_TTS_ENABLED CC_OLLAMA_MODEL CC_CLAUDE_ENABLED CC_HISTORY_SIZE \
           CC_AUTO_EXECUTE_SAFE CC_CONFIRM_RISKY CC_VOICE_INPUT CC_VOICE_OUTPUT; do
  echo "export $var=\"${!var}\""
done
```

**Step 2: Write tests**

`tests/config.bats`:
```bash
@test "config parser reads ollama_model" {
  export XDG_CONFIG_HOME="$CACHE_DIR"
  mkdir -p "$CACHE_DIR/omarchy-cc"
  cat > "$CACHE_DIR/omarchy-cc/config.toml" <<'EOF'
[general]
ollama_model = "qwen2.5-coder:32b"
EOF
  eval "$("$OMARCHY_CC_DIR/bin/omarchy-cc-config")"
  [ "$CC_OLLAMA_MODEL" = "qwen2.5-coder:32b" ]
}

@test "config parser uses defaults when no file" {
  export XDG_CONFIG_HOME="$CACHE_DIR/nonexistent"
  eval "$("$OMARCHY_CC_DIR/bin/omarchy-cc-config")"
  [ "$CC_OLLAMA_MODEL" = "qwen2.5-coder:7b" ]
  [ "$CC_HISTORY_SIZE" = "100" ]
}
```

**Step 3: Update all three scripts to use `eval "$(omarchy-cc-config)"`**

Replace `read_config()` calls in each script with the shared config.

**Step 4: Run tests, verify**

**Step 5: Commit**

```bash
git add bin/omarchy-cc-config tests/config.bats bin/omarchy-cc bin/omarchy-cc-route bin/omarchy-cc-exec
git commit -m "refactor: single-pass config parser replaces per-key grep+sed"
```

---

## Task 4: Lazy Context Gathering

**Files:**
- Modify: `bin/omarchy-cc-route` (lines 720-746 — `gather_context()`)

**Problem:** `gather_context()` calls `omarchy-theme-current`, `pactl`, `hyprctl activewindow`, `hyprctl activeworkspace`, `hyprctl monitors`, and `omarchy-font-current` — 6 subprocesses totaling ~300ms. This runs on EVERY Ollama/Claude call, even when the context isn't relevant.

**Fix:** Only gather context fields that the user's input actually needs.

**Step 1: Write test**

```bash
@test "gather_context includes theme when input mentions theme" {
  # Mock commands
  omarchy-theme-current() { echo "Tokyo Night"; }
  export -f omarchy-theme-current
  result=$(gather_context_for "what theme am i using")
  [[ "$result" == *"Tokyo Night"* ]]
}

@test "gather_context skips audio when input is about brightness" {
  result=$(gather_context_for "brightness up")
  [[ "$result" != *"audio"* ]]
}
```

**Step 2: Replace `gather_context()` with `gather_context_for()`**

```bash
gather_context_for() {
  local input="$1"
  local ctx=""

  # Always cheap
  ctx+="System: Arch Linux, Hyprland (Wayland)"$'\n'

  # Only gather what's relevant
  if [[ "$input" == *theme* || "$input" == *wallpaper* || "$input" == *background* ]]; then
    ctx+="Current theme: $(omarchy-theme-current 2>/dev/null || echo unknown)"$'\n'
  fi

  if [[ "$input" == *audio* || "$input" == *sound* || "$input" == *speaker* || "$input" == *headphone* || "$input" == *volume* ]]; then
    local sink_name sink_desc
    sink_name=$(pactl get-default-sink 2>/dev/null || echo "")
    if [[ -n "$sink_name" ]]; then
      sink_desc=$(pactl -f json list sinks 2>/dev/null | jq -r --arg n "$sink_name" '.[] | select(.name == $n) | .description' 2>/dev/null || echo "$sink_name")
      ctx+="Current audio output: $sink_desc"$'\n'
    fi
  fi

  if [[ "$input" == *window* || "$input" == *workspace* || "$input" == *focus* || "$input" == *move* ]]; then
    local active_class
    active_class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null || echo "")
    [[ -n "$active_class" ]] && ctx+="Active window: $active_class"$'\n'

    local ws_id
    ws_id=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || echo "")
    [[ -n "$ws_id" ]] && ctx+="Current workspace: $ws_id"$'\n'
  fi

  if [[ "$input" == *font* ]]; then
    ctx+="Current font: $(omarchy-font-current 2>/dev/null || echo unknown)"$'\n'
  fi

  if [[ "$input" == *monitor* || "$input" == *display* || "$input" == *screen* ]]; then
    local mon_count
    mon_count=$(hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo "1")
    ctx+="Monitors: $mon_count"$'\n'
  fi

  echo "$ctx"
}
```

**Step 3: Update `ollama_route()` and `claude_route()` to use new function**

**Step 4: Run tests, verify**

**Step 5: Commit**

```bash
git commit -m "perf: lazy context gathering — only query what the input needs"
```

---

## Task 5: Enhanced tmux Manager with Resource Monitoring

**Files:**
- Modify: `bin/omarchy-cc-tmux`
- Create: `bin/omarchy-cc-tmux-monitor` (Python — inspired by tmux-task-monitor)
- Modify: `bin/omarchy-cc-route` (add monitoring patterns)
- Create: `tests/tmux.bats`

**Why:** The user linked tmux-task-monitor. Current tmux manager just lists sessions. We want CPU/memory per session.

**Step 1: Write tests for tmux list parsing**

`tests/tmux.bats`:
```bash
@test "tmux list formats session correctly" {
  # Skip if no tmux
  command -v tmux || skip "tmux not installed"
  result=$("$OMARCHY_CC_DIR/bin/omarchy-cc-tmux" list 2>&1)
  # Should either show sessions or "No active tmux sessions."
  [[ "$result" == *"SESSION"* ]] || [[ "$result" == *"No active"* ]]
}
```

**Step 2: Enhance `omarchy-cc-tmux` with resource info**

Add CPU/memory columns using `ps` to sum process stats per session:

```bash
# Get total CPU% and RSS for all processes in a tmux session
session_resources() {
  local session="$1"
  local pids
  pids=$(tmux list-panes -t "$session" -F '#{pane_pid}' 2>/dev/null)

  local total_cpu=0 total_mem=0
  for pid in $pids; do
    # Get this process and all descendants
    local stats
    stats=$(ps --ppid "$pid" -o %cpu=,%mem= --no-headers 2>/dev/null || true)
    # Also include the pane process itself
    stats+=$'\n'$(ps -p "$pid" -o %cpu=,%mem= --no-headers 2>/dev/null || true)

    while read -r cpu mem; do
      [[ -z "$cpu" ]] && continue
      total_cpu=$(echo "$total_cpu + $cpu" | bc 2>/dev/null || echo "$total_cpu")
      total_mem=$(echo "$total_mem + $mem" | bc 2>/dev/null || echo "$total_mem")
    done <<< "$stats"
  done

  printf "%.1f %.1f" "$total_cpu" "$total_mem"
}
```

Update the table output:
```
  SESSION    WINDOWS   CPU%   MEM%   UPTIME       STATUS
  -------    -------   ----   ----   ------       ------
  main       3         2.4    1.2    2d 10h       attached
  dev        1         45.2   8.7    6h 42m       detached
  build      2         0.0    0.3    15m          detached
```

**Step 3: Create Python-based live monitor (optional, for `tmux monitor` command)**

`bin/omarchy-cc-tmux-monitor`:
```python
#!/usr/bin/env python3
"""Live tmux session resource monitor (inspired by tmux-task-monitor).
Displays CPU/memory usage per session with auto-refresh.
Press q to quit, k to kill selected session."""

import curses
import subprocess
import json
import time
import sys

def get_sessions():
    """Get tmux sessions with resource info."""
    try:
        raw = subprocess.check_output(
            ['tmux', 'list-sessions', '-F',
             '#{session_name}|#{session_created}|#{session_windows}|#{session_attached}'],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

    sessions = []
    now = time.time()
    for line in raw.split('\n'):
        if not line:
            continue
        name, created, windows, attached = line.split('|')
        elapsed = int(now - int(created))

        # Get resource usage
        cpu, mem = get_session_resources(name)

        sessions.append({
            'name': name,
            'windows': int(windows),
            'attached': attached == '1',
            'elapsed': elapsed,
            'cpu': cpu,
            'mem': mem,
        })
    return sessions

def get_session_resources(session):
    """Sum CPU% and MEM% for all processes in a tmux session."""
    try:
        panes = subprocess.check_output(
            ['tmux', 'list-panes', '-t', session, '-F', '#{pane_pid}'],
            text=True, stderr=subprocess.DEVNULL
        ).strip().split('\n')
    except subprocess.CalledProcessError:
        return 0.0, 0.0

    total_cpu = 0.0
    total_mem = 0.0
    for pid in panes:
        if not pid:
            continue
        try:
            ps_out = subprocess.check_output(
                ['ps', '--ppid', pid, '-p', pid, '-o', '%cpu=,%mem=', '--no-headers'],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            for line in ps_out.split('\n'):
                parts = line.split()
                if len(parts) >= 2:
                    total_cpu += float(parts[0])
                    total_mem += float(parts[1])
        except (subprocess.CalledProcessError, ValueError):
            pass
    return round(total_cpu, 1), round(total_mem, 1)

def format_duration(seconds):
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m"
    elif seconds < 86400:
        h, m = divmod(seconds, 3600)
        return f"{h}h {m // 60}m"
    else:
        d, rem = divmod(seconds, 86400)
        return f"{d}d {rem // 3600}h"

def main(stdscr):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_GREEN, -1)
    curses.init_pair(2, curses.COLOR_YELLOW, -1)
    curses.init_pair(3, curses.COLOR_RED, -1)
    curses.init_pair(4, curses.COLOR_CYAN, -1)
    stdscr.timeout(2000)  # Refresh every 2s

    selected = 0

    while True:
        stdscr.clear()
        sessions = get_sessions()
        h, w = stdscr.getmaxyx()

        # Header
        title = " tmux session monitor "
        stdscr.addstr(0, 0, title, curses.A_BOLD | curses.color_pair(4))
        stdscr.addstr(0, len(title) + 2, "q:quit  k:kill  r:refresh", curses.A_DIM)

        # Column headers
        header = f"  {'SESSION':<15} {'WIN':>4} {'CPU%':>6} {'MEM%':>6} {'UPTIME':>10} {'STATUS':>10}"
        stdscr.addstr(2, 0, header, curses.A_BOLD)
        stdscr.addstr(3, 0, "─" * min(w - 1, 70))

        if not sessions:
            stdscr.addstr(5, 2, "No active tmux sessions.", curses.A_DIM)
        else:
            for i, s in enumerate(sessions):
                if i + 4 >= h - 2:
                    break

                status = "attached" if s['attached'] else "detached"
                uptime = format_duration(s['elapsed'])

                # Color based on CPU usage
                if s['cpu'] > 50:
                    color = curses.color_pair(3)  # Red
                elif s['cpu'] > 10:
                    color = curses.color_pair(2)  # Yellow
                else:
                    color = curses.color_pair(1)  # Green

                line = f"  {s['name']:<15} {s['windows']:>4} {s['cpu']:>5.1f}% {s['mem']:>5.1f}% {uptime:>10} {status:>10}"

                attr = curses.A_REVERSE if i == selected else 0
                stdscr.addstr(i + 4, 0, line, attr | color)

        # Footer
        stdscr.addstr(h - 1, 0, f" {len(sessions)} session(s) ", curses.A_DIM)

        stdscr.refresh()

        key = stdscr.getch()
        if key == ord('q') or key == 27:  # q or Escape
            break
        elif key == curses.KEY_UP and selected > 0:
            selected -= 1
        elif key == curses.KEY_DOWN and selected < len(sessions) - 1:
            selected += 1
        elif key == ord('k') and sessions:
            name = sessions[selected]['name']
            subprocess.run(['tmux', 'kill-session', '-t', name],
                         stderr=subprocess.DEVNULL)
        elif key == ord('r'):
            pass  # Just refresh

if __name__ == '__main__':
    if '--no-curses' in sys.argv:
        # Non-interactive mode for CC integration
        sessions = get_sessions()
        if not sessions:
            print("No active tmux sessions.")
        else:
            print(f"  {'SESSION':<15} {'WIN':>4} {'CPU%':>6} {'MEM%':>6} {'UPTIME':>10} {'STATUS':>10}")
            print(f"  {'─'*15} {'─'*4} {'─'*6} {'─'*6} {'─'*10} {'─'*10}")
            for s in sessions:
                status = "attached" if s['attached'] else "detached"
                uptime = format_duration(s['elapsed'])
                print(f"  {s['name']:<15} {s['windows']:>4} {s['cpu']:>5.1f}% {s['mem']:>5.1f}% {uptime:>10} {status:>10}")
    else:
        curses.wrapper(main)
```

**Step 4: Update omarchy-cc-tmux to show resources**

Replace the `list)` case with a call to the Python monitor in `--no-curses` mode when available, falling back to the current bash implementation.

**Step 5: Add routing patterns**

In `omarchy-cc-route`, add:
```bash
"tmux monitor"|"monitor session"*|"session monitor"*)
  echo "omarchy-cc-tmux-monitor" ;;
```

**Step 6: Add to safe-commands**

Add `omarchy-cc-tmux-monitor` to the safe-commands file.

**Step 7: Run tests, verify**

**Step 8: Commit**

```bash
git add bin/omarchy-cc-tmux bin/omarchy-cc-tmux-monitor bin/omarchy-cc-route config/safe-commands tests/tmux.bats
git commit -m "feat: tmux resource monitor with CPU/mem per session"
```

---

## Task 6: Frecency History

**Files:**
- Modify: `bin/omarchy-cc` (history functions)
- Create: `tests/history.bats`

**Problem:** History is a flat text file with dedup only on last entry. "set theme tokyo night" used 50 times ranks the same as a command used once.

**Fix:** Score = frequency × recency. Most-used recent commands float to top.

**Step 1: Write tests**

```bash
@test "frecency: frequent command scores higher" {
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc"
  # Add same command 5 times
  for i in {1..5}; do add_history "volume up"; done
  add_history "set theme catppuccin"

  # Top suggestion should be "volume up"
  result=$(get_suggestions 1)
  [ "$result" = "volume up" ]
}
```

**Step 2: Switch history format to TSV with timestamps**

Format: `<timestamp>\t<command>`

```bash
# ~/.cache/omarchy-cc/history format:
# 1708520400	volume up
# 1708520410	set theme tokyo night
# 1708520420	volume up
```

**Step 3: Implement frecency scoring**

```bash
get_suggestions() {
  local count="${1:-5}"
  local now
  now=$(date +%s)

  awk -F'\t' -v now="$now" '{
    cmd = $2
    ts = $1
    age = now - ts
    # Frecency: recent commands score exponentially higher
    if (age < 300) weight = 10      # < 5 min
    else if (age < 3600) weight = 5  # < 1 hour
    else if (age < 86400) weight = 2 # < 1 day
    else weight = 1

    score[cmd] += weight
  }
  END {
    for (cmd in score) print score[cmd] "\t" cmd
  }' "$HISTORY_FILE" | sort -rn | head -n "$count" | cut -f2-
}
```

**Step 4: Update `show_history()` and `add_history()` to use new format**

**Step 5: Run tests, verify**

**Step 6: Commit**

```bash
git commit -m "feat: frecency-scored history — most-used recent commands surface first"
```

---

## Task 7: Compact Feedback Line

**Files:**
- Modify: `bin/omarchy-cc` (process_input display)
- Modify: `bin/omarchy-cc-exec` (output formatting)

**Problem:** Current feedback takes 3+ lines per command:
```
→ Setting theme to tokyo night
  omarchy-theme-set "tokyo night"

✓ Done
```

**Fix:** Compact single-line feedback with timing:

```
→ Setting theme to tokyo night ─ omarchy-theme-set "tokyo night" (12ms) ✓
```

**Step 1: Move timing display to omarchy-cc-exec output**

Have `omarchy-cc-exec` output a structured status line that `omarchy-cc` can parse:
```
CC_STATUS:exit=0:ms=12:output_lines=0
```

**Step 2: Update `process_input()` to render compact feedback**

```bash
# Show: → Description ─ command
# Then output (if any)
# Then: ✓ (12ms) or ✗ failed (12ms)
```

**Step 3: Run tests, verify**

**Step 4: Commit**

```bash
git commit -m "feat: compact single-line feedback with timing"
```

---

## Task 8: Error Handling Consistency

**Files:**
- Modify: `bin/omarchy-cc` (error display)
- Modify: `bin/omarchy-cc-route` (remove `set -e`)
- Modify: `bin/omarchy-cc-exec` (remove `set -e`)
- Create: `tests/errors.bats`

**Problem:** Mixed `set -euo pipefail` vs `set -uo pipefail`. `omarchy-cc-route` still has `set -e` (line 10) which can cause silent crashes when any subcommand fails.

**Fix:** Remove `set -e` from all CC scripts. Handle errors explicitly.

**Step 1: Write tests for error cases**

```bash
@test "route: nonexistent ollama model returns graceful failure" {
  OLLAMA_MODEL="nonexistent-model-xyz"
  run ollama_route "do something weird" ""
  # Should fail gracefully, not crash
  [ "$status" -ne 0 ] || [[ "$output" == *"echo"* ]]
}

@test "exec: command failure shows error message" {
  result=$(execute "false" "test" "test command" 2>&1)
  [[ "$result" == *"Failed"* ]]
}
```

**Step 2: Change `set -euo pipefail` to `set -uo pipefail` in route and exec**

**Step 3: Add explicit error handling in ollama_route() and claude_route()**

```bash
ollama_route() {
  local input="$1" context="$2"
  command -v ollama &>/dev/null || { echo "ollama not installed" >&2; return 1; }

  # Check if ollama is actually running
  if ! curl -s --max-time 1 http://localhost:11434/api/version &>/dev/null; then
    echo "ollama not running" >&2
    return 1
  fi

  # ... rest of function
}
```

**Step 4: Run tests, verify**

**Step 5: Commit**

```bash
git commit -m "fix: consistent error handling — remove set -e, handle errors explicitly"
```

---

## Task 9: Smarter Ollama Integration

**Files:**
- Modify: `bin/omarchy-cc-route` (Ollama prompt and response validation)
- Create: `tests/ollama.bats`

**Problem:** The Ollama system prompt is huge (~80 lines) and sent on every call. Response validation is weak — just checks if the first word looks like a command.

**Fix:**
1. Cache the system prompt in a temp file (regenerate if context changes)
2. Better response validation — check that outputted commands actually exist
3. Add a timeout so broken Ollama doesn't hang the CC

**Step 1: Add command existence validation**

```bash
validate_command() {
  local cmd="$1"
  local first_word="${cmd%% *}"

  # Check if it's a known command
  case "$first_word" in
    omarchy-*|hyprctl|wpctl|pactl|brightnessctl|systemctl|date|uptime|df|free)
      return 0 ;;
    echo|cat|ls|ps|kill|pkill|uwsm-app|notify-send|curl|wget)
      return 0 ;;
    sudo|pacman|yay)
      return 0 ;;
  esac

  # Check if it's in PATH
  command -v "$first_word" &>/dev/null
}
```

**Step 2: Add timeout to ollama call**

```bash
result=$(timeout 10 ollama run "$OLLAMA_MODEL" --nowordwrap "..." 2>/dev/null | ...)
```

**Step 3: Write tests**

```bash
@test "validate_command: omarchy-theme-set is valid" {
  run validate_command "omarchy-theme-set catppuccin"
  [ "$status" -eq 0 ]
}

@test "validate_command: random gibberish is invalid" {
  run validate_command "asdfghjkl zxcvbnm"
  [ "$status" -ne 0 ]
}
```

**Step 4: Run tests, verify**

**Step 5: Commit**

```bash
git commit -m "feat: validate Ollama responses, add 10s timeout"
```

---

## Task 10: Add `omarchy-cc-test` Integration Test Runner

**Files:**
- Create: `bin/omarchy-cc-test`
- Update: `Makefile`

**Why:** Beyond unit tests, we need integration tests that run actual CC commands end-to-end.

**Step 1: Create integration test script**

```bash
#!/bin/bash
# Integration tests for omarchy-cc.
# Runs actual routing and execution (safe commands only).

set -uo pipefail

PASS=0
FAIL=0

assert_route() {
  local input="$1" expected="$2"
  local actual
  actual=$(omarchy-cc-route "$input" 2>/dev/null | tail -1)
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ '$input' → '$expected'"
    ((PASS++))
  else
    echo "  ✗ '$input'"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_route_contains() {
  local input="$1" expected="$2"
  local actual
  actual=$(omarchy-cc-route "$input" 2>/dev/null | tail -1)
  if [[ "$actual" == *"$expected"* ]]; then
    echo "  ✓ '$input' contains '$expected'"
    ((PASS++))
  else
    echo "  ✗ '$input'"
    echo "    expected to contain: $expected"
    echo "    actual: $actual"
    ((FAIL++))
  fi
}

echo "═══ Routing Integration Tests ═══"
echo ""

echo "── Theme ──"
assert_route "set theme tokyo night" 'omarchy-theme-set "tokyo night"'
assert_route "what theme am i using" "omarchy-theme-current"
assert_route "list themes" "omarchy-theme-list"
assert_route "next wallpaper" "omarchy-theme-bg-next"

echo ""
echo "── Volume ──"
assert_route "volume up" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
assert_route "volume down" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
assert_route "mute" "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

echo ""
echo "── Brightness ──"
assert_route "brightness up" "brightnessctl set 10%+"
assert_route "brightness down" "brightnessctl set 10%-"

echo ""
echo "── Window Management ──"
assert_route "fullscreen" "hyprctl dispatch fullscreen"
assert_route "close window" "hyprctl dispatch killactive"
assert_route "center window" "hyprctl dispatch centerwindow"

echo ""
echo "── System ──"
assert_route "lock screen" "omarchy-lock-screen"
assert_route "screenshot" "omarchy-cmd-screenshot smart"
assert_route_contains "storage" "df -h"
assert_route "what time is it" "date '+%H:%M'"
assert_route "uptime" "uptime -p"
assert_route "version" "omarchy-version"

echo ""
echo "── NLP Pipeline ──"
assert_route "can you please set the theme to catppuccin" 'omarchy-theme-set "catppuccin"'
assert_route "would you make it louder" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
assert_route "dim the screen a little bit" "brightnessctl set 10%-"
assert_route "turn on the night light" "omarchy-toggle-nightlight"

echo ""
echo "── tmux ──"
assert_route "tmux" "omarchy-cc-tmux"
assert_route "kill session 3" "omarchy-cc-tmux kill 3"
assert_route "kill detached sessions" "omarchy-cc-tmux kill detached"

echo ""
echo "═══════════════════════════════════"
echo "  Passed: $PASS  Failed: $FAIL"
echo "═══════════════════════════════════"

[[ $FAIL -eq 0 ]]
```

**Step 2: Update Makefile**

```makefile
test-integration:
	bash bin/omarchy-cc-test

test-all: test test-integration
```

**Step 3: Run, fix any failures**

**Step 4: Commit**

```bash
git add bin/omarchy-cc-test Makefile
git commit -m "feat: add integration test runner for end-to-end routing verification"
```

---

## Execution Order

| # | Task | Depends On | Priority |
|---|------|-----------|----------|
| 1 | Test framework (bats) | — | **Critical** |
| 2 | Fix copy UX | — | High |
| 3 | Config parser | — | Medium |
| 4 | Lazy context | Tests | High |
| 5 | tmux resource monitor | — | High |
| 6 | Frecency history | Tests | Medium |
| 7 | Compact feedback | — | Medium |
| 8 | Error handling | Tests | High |
| 9 | Smarter Ollama | Tests | Medium |
| 10 | Integration tests | Tasks 1-9 | **Critical** |

**Recommended flow:** 1 → 8 → 2 → 4 → 5 → 3 → 7 → 6 → 9 → 10

---

## Verification

After all tasks:

1. `make test` — All bats tests pass
2. `make test-integration` — All routing integration tests pass
3. `omarchy-cc-route "set theme tokyo night"` → `omarchy-theme-set "tokyo night"` (instant)
4. `omarchy-cc-route "can you please make it louder"` → `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` (instant)
5. `omarchy-cc-route "storage"` → `df -h ...` (instant)
6. `omarchy-cc-tmux` → Shows sessions with CPU/MEM columns
7. `omarchy-cc-tmux-monitor` → Live curses display with session resources
8. Press Super+I → CC opens, no 5s blocking prompt after commands
9. Type `history` → Frecency-sorted suggestions
10. Type a nonexistent command → Graceful error, no crash
11. Kill ollama, type something that needs LLM → Timeout + clear error message
