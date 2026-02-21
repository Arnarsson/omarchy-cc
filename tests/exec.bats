#!/usr/bin/env bats
load test_helper

setup() {
  export CACHE_DIR="$(mktemp -d /tmp/omarchy-cc-test.XXXXXX)"
  mkdir -p "$CACHE_DIR"
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-exec"
}

teardown() {
  [[ -d "${CACHE_DIR:-}" ]] && rm -rf "$CACHE_DIR" || true
}

# ══════════════════════════════════════════════════════════════════════════════
# Safety classification: is_safe
# ══════════════════════════════════════════════════════════════════════════════

@test "safe: omarchy-theme-set catppuccin" {
  run is_safe "omarchy-theme-set catppuccin"
  [ "$status" -eq 0 ]
}

@test "safe: omarchy-theme-current" {
  run is_safe "omarchy-theme-current"
  [ "$status" -eq 0 ]
}

@test "safe: omarchy-font-list" {
  run is_safe "omarchy-font-list"
  [ "$status" -eq 0 ]
}

@test "safe: omarchy-toggle-nightlight" {
  run is_safe "omarchy-toggle-nightlight"
  [ "$status" -eq 0 ]
}

@test "safe: omarchy-launch-browser" {
  run is_safe "omarchy-launch-browser"
  [ "$status" -eq 0 ]
}

@test "safe: wpctl set-volume" {
  run is_safe "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
  [ "$status" -eq 0 ]
}

@test "safe: pactl set-default-sink" {
  run is_safe "pactl set-default-sink some-sink"
  [ "$status" -eq 0 ]
}

@test "safe: hyprctl dispatch fullscreen" {
  run is_safe "hyprctl dispatch fullscreen"
  [ "$status" -eq 0 ]
}

@test "safe: brightnessctl set 50%" {
  run is_safe "brightnessctl set 50%"
  [ "$status" -eq 0 ]
}

@test "safe: date" {
  run is_safe "date '+%H:%M'"
  [ "$status" -eq 0 ]
}

@test "safe: df -h" {
  run is_safe "df -h"
  [ "$status" -eq 0 ]
}

@test "safe: fastfetch" {
  run is_safe "fastfetch"
  [ "$status" -eq 0 ]
}

@test "safe: echo hello" {
  run is_safe "echo hello"
  [ "$status" -eq 0 ]
}

@test "safe: omarchy-cc-tmux" {
  run is_safe "omarchy-cc-tmux"
  [ "$status" -eq 0 ]
}

@test "safe: uwsm-app -- xdg-terminal-exec" {
  run is_safe "uwsm-app -- xdg-terminal-exec"
  [ "$status" -eq 0 ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Safety classification: is_risky
# ══════════════════════════════════════════════════════════════════════════════

@test "risky: omarchy-update" {
  run is_risky "omarchy-update"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-pkg-add htop" {
  run is_risky "omarchy-pkg-add htop"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-pkg-drop htop" {
  run is_risky "omarchy-pkg-drop htop"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-restart-waybar" {
  run is_risky "omarchy-restart-waybar"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-refresh-hyprland" {
  run is_risky "omarchy-refresh-hyprland"
  [ "$status" -eq 0 ]
}

@test "risky: sudo pacman -Syu" {
  run is_risky "sudo pacman -Syu"
  [ "$status" -eq 0 ]
}

@test "risky: rm -rf /tmp/stuff" {
  run is_risky "rm -rf /tmp/stuff"
  [ "$status" -eq 0 ]
}

@test "risky: systemctl suspend" {
  run is_risky "systemctl suspend"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-cmd-reboot" {
  run is_risky "omarchy-cmd-reboot"
  [ "$status" -eq 0 ]
}

@test "risky: omarchy-cmd-shutdown" {
  run is_risky "omarchy-cmd-shutdown"
  [ "$status" -eq 0 ]
}

@test "not risky: omarchy-theme-current" {
  run is_risky "omarchy-theme-current"
  [ "$status" -eq 1 ]
}

@test "not risky: date" {
  run is_risky "date"
  [ "$status" -eq 1 ]
}

@test "not risky: wpctl set-volume" {
  run is_risky "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
  [ "$status" -eq 1 ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Undo state capture
# ══════════════════════════════════════════════════════════════════════════════

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

@test "undo: brightness down → brightness up" {
  result=$(capture_undo_state "brightnessctl set 10%-")
  [ "$result" = "brightnessctl set 10%+" ]
}

@test "undo: toggle is self-inverse" {
  result=$(capture_undo_state "omarchy-toggle-nightlight")
  [ "$result" = "omarchy-toggle-nightlight" ]
}

@test "undo: mute toggle is self-inverse" {
  result=$(capture_undo_state "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
  [ "$result" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ]
}

@test "undo: no undo for date" {
  result=$(capture_undo_state "date")
  [ -z "$result" ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Interactive detection
# ══════════════════════════════════════════════════════════════════════════════

@test "interactive: omarchy-menu" {
  run is_interactive "omarchy-menu"
  [ "$status" -eq 0 ]
}

@test "interactive: omarchy-pkg-install" {
  run is_interactive "omarchy-pkg-install"
  [ "$status" -eq 0 ]
}

@test "interactive: omarchy-pkg-remove" {
  run is_interactive "omarchy-pkg-remove"
  [ "$status" -eq 0 ]
}

@test "interactive: omarchy-theme-set (no args = picker)" {
  run is_interactive "omarchy-theme-set"
  [ "$status" -eq 0 ]
}

@test "interactive: omarchy-font-set (no args = picker)" {
  run is_interactive "omarchy-font-set"
  [ "$status" -eq 0 ]
}

@test "interactive: gum choose" {
  run is_interactive "gum choose a b c"
  [ "$status" -eq 0 ]
}

@test "not interactive: date" {
  run is_interactive "date"
  [ "$status" -eq 1 ]
}

@test "not interactive: omarchy-theme-set catppuccin" {
  run is_interactive "omarchy-theme-set catppuccin"
  [ "$status" -eq 1 ]
}

@test "not interactive: df -h" {
  run is_interactive "df -h"
  [ "$status" -eq 1 ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Logging
# ══════════════════════════════════════════════════════════════════════════════

@test "log_entry writes valid JSON" {
  LOG_FILE="$CACHE_DIR/test.log"
  log_entry "pattern" "volume up" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" "0" "5" "done"
  # Verify it's valid JSON
  jq '.' "$LOG_FILE" >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "log_entry captures all fields" {
  LOG_FILE="$CACHE_DIR/test.log"
  log_entry "ollama" "dim screen" "brightnessctl set 10%-" "0" "1200" ""
  local entry
  entry=$(cat "$LOG_FILE")
  [[ "$(echo "$entry" | jq -r '.tier')" == "ollama" ]]
  [[ "$(echo "$entry" | jq -r '.input')" == "dim screen" ]]
  [[ "$(echo "$entry" | jq -r '.cmd')" == "brightnessctl set 10%-" ]]
  [[ "$(echo "$entry" | jq -r '.exit')" == "0" ]]
  [[ "$(echo "$entry" | jq -r '.ms')" == "1200" ]]
}
