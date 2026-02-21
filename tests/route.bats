#!/usr/bin/env bats
load test_helper

setup() {
  export CACHE_DIR="$(mktemp -d /tmp/omarchy-cc-test.XXXXXX)"
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-route"
}

teardown() {
  [[ -d "${CACHE_DIR:-}" ]] && rm -rf "$CACHE_DIR" || true
}

# ══════════════════════════════════════════════════════════════════════════════
# Tier 1: Pattern matching
# ══════════════════════════════════════════════════════════════════════════════

# ── Theme ──

@test "pattern: 'set theme tokyo night'" {
  result=$(pattern_match "set theme tokyo night")
  [ "$result" = 'omarchy-theme-set "tokyo night"' ]
}

@test "pattern: 'change theme to catppuccin'" {
  result=$(pattern_match "change theme to catppuccin")
  [ "$result" = 'omarchy-theme-set "catppuccin"' ]
}

@test "pattern: 'what theme' → theme-current" {
  result=$(pattern_match "what theme")
  [ "$result" = "omarchy-theme-current" ]
}

@test "pattern: 'list theme' → theme-list" {
  result=$(pattern_match "list theme")
  [ "$result" = "omarchy-theme-list" ]
}

@test "pattern: 'switch theme' → theme-set (interactive)" {
  result=$(pattern_match "switch theme")
  [ "$result" = "omarchy-theme-set" ]
}

# ── Wallpaper ──

@test "pattern: 'next wallpaper'" {
  result=$(pattern_match "next wallpaper")
  [ "$result" = "omarchy-theme-bg-next" ]
}

@test "pattern: 'change background'" {
  result=$(pattern_match "change background")
  [ "$result" = "omarchy-theme-bg-next" ]
}

# ── Font ──

@test "pattern: 'set font jetbrains'" {
  result=$(pattern_match "set font jetbrains")
  [ "$result" = 'omarchy-font-set "jetbrains"' ]
}

@test "pattern: 'what font' → font-current" {
  result=$(pattern_match "what font")
  [ "$result" = "omarchy-font-current" ]
}

@test "pattern: 'list font' → font-list" {
  result=$(pattern_match "list font")
  [ "$result" = "omarchy-font-list" ]
}

# ── Volume ──

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

@test "pattern: 'unmute'" {
  result=$(pattern_match "unmute")
  [ "$result" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0" ]
}

# ── Brightness ──

@test "pattern: 'brightness up'" {
  result=$(pattern_match "brightness up")
  [ "$result" = "brightnessctl set 10%+" ]
}

@test "pattern: 'brightness down'" {
  result=$(pattern_match "brightness down")
  [ "$result" = "brightnessctl set 10%-" ]
}

@test "pattern: 'brightness 50' → set 50%" {
  result=$(pattern_match "brightness 50")
  [ "$result" = "brightnessctl set 50%" ]
}

# ── Screenshot ──

@test "pattern: 'screenshot'" {
  result=$(pattern_match "screenshot")
  [ "$result" = "omarchy-cmd-screenshot smart" ]
}

@test "pattern: 'screen record'" {
  result=$(pattern_match "screen record")
  [ "$result" = "omarchy-cmd-screenrecord" ]
}

# ── Window management ──

@test "pattern: 'fullscreen'" {
  result=$(pattern_match "fullscreen")
  [ "$result" = "hyprctl dispatch fullscreen" ]
}

@test "pattern: 'float'" {
  result=$(pattern_match "float")
  [ "$result" = "hyprctl dispatch togglefloating" ]
}

@test "pattern: 'center window'" {
  result=$(pattern_match "center window")
  [ "$result" = "hyprctl dispatch centerwindow" ]
}

@test "pattern: 'close window'" {
  result=$(pattern_match "close window")
  [ "$result" = "hyprctl dispatch killactive" ]
}

@test "pattern: 'minimize'" {
  result=$(pattern_match "minimize")
  [ "$result" = "hyprctl dispatch movetospecial" ]
}

@test "pattern: 'workspace 3'" {
  result=$(pattern_match "workspace 3")
  [ "$result" = "hyprctl dispatch workspace 3" ]
}

# ── System ──

@test "pattern: 'lock screen'" {
  result=$(pattern_match "lock screen")
  [ "$result" = "omarchy-lock-screen" ]
}

@test "pattern: 'toggle nightlight'" {
  result=$(pattern_match "toggle nightlight")
  [ "$result" = "omarchy-toggle-nightlight" ]
}

@test "pattern: 'toggle waybar'" {
  result=$(pattern_match "toggle waybar")
  [ "$result" = "omarchy-toggle-waybar" ]
}

# ── Info ──

@test "pattern: 'time'" {
  result=$(pattern_match "time")
  [ "$result" = "date '+%H:%M'" ]
}

@test "pattern: 'date'" {
  result=$(pattern_match "date")
  [ "$result" = "date '+%A, %B %d %Y'" ]
}

@test "pattern: 'uptime'" {
  result=$(pattern_match "uptime")
  [ "$result" = "uptime -p" ]
}

@test "pattern: 'battery'" {
  result=$(pattern_match "battery")
  [ "$result" = "omarchy-battery-remaining" ]
}

@test "pattern: 'version'" {
  result=$(pattern_match "version")
  [ "$result" = "omarchy-version" ]
}

@test "pattern: 'storage'" {
  result=$(pattern_match "storage")
  [[ "$result" == *"df -h"* ]]
}

@test "pattern: 'system info'" {
  result=$(pattern_match "system info")
  [ "$result" = "fastfetch" ]
}

# ── Power ──

@test "pattern: 'reboot'" {
  result=$(pattern_match "reboot")
  [ "$result" = "omarchy-cmd-reboot" ]
}

@test "pattern: 'shutdown'" {
  result=$(pattern_match "shutdown")
  [ "$result" = "omarchy-cmd-shutdown" ]
}

@test "pattern: 'suspend'" {
  result=$(pattern_match "suspend")
  [ "$result" = "systemctl suspend" ]
}

# ── Launch ──

@test "pattern: 'launch browser'" {
  result=$(pattern_match "launch browser")
  [ "$result" = "omarchy-launch-browser" ]
}

@test "pattern: 'launch editor'" {
  result=$(pattern_match "launch editor")
  [ "$result" = "omarchy-launch-editor" ]
}

@test "pattern: 'launch terminal'" {
  result=$(pattern_match "launch terminal")
  [ "$result" = "uwsm-app -- xdg-terminal-exec" ]
}

# ── Restart ──

@test "pattern: 'restart waybar'" {
  result=$(pattern_match "restart waybar")
  [ "$result" = "omarchy-restart-waybar" ]
}

@test "pattern: 'restart pipewire'" {
  result=$(pattern_match "restart pipewire")
  [ "$result" = "omarchy-restart-pipewire" ]
}

# ── Tmux ──

@test "pattern: 'tmux'" {
  result=$(pattern_match "tmux")
  [ "$result" = "omarchy-cc-tmux" ]
}

@test "pattern: 'kill session 3'" {
  result=$(pattern_match "kill session 3")
  [ "$result" = "omarchy-cc-tmux kill 3" ]
}

@test "pattern: 'kill detached'" {
  result=$(pattern_match "kill detached")
  [ "$result" = "omarchy-cc-tmux kill detached" ]
}

# ── Unknown ──

@test "pattern: unknown input returns failure" {
  run pattern_match "quantum flux capacitor engage"
  [ "$status" -eq 1 ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Tier 1.5: Keyword matching
# ══════════════════════════════════════════════════════════════════════════════

@test "keyword: 'what is the current theme'" {
  result=$(keyword_match "what is the current theme")
  [ "$result" = "omarchy-theme-current" ]
}

@test "keyword: 'show all fonts'" {
  result=$(keyword_match "show all fonts")
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

@test "keyword: 'open editor'" {
  result=$(keyword_match "open editor")
  [ "$result" = "omarchy-launch-editor" ]
}

@test "keyword: 'open terminal'" {
  result=$(keyword_match "open terminal")
  [ "$result" = "uwsm-app -- xdg-terminal-exec" ]
}

@test "keyword: 'volume up'" {
  result=$(keyword_match "volume up")
  [ "$result" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" ]
}

@test "keyword: 'mute'" {
  result=$(keyword_match "mute")
  [ "$result" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ]
}

@test "keyword: 'fullscreen'" {
  result=$(keyword_match "fullscreen")
  [ "$result" = "hyprctl dispatch fullscreen" ]
}

@test "keyword: 'battery'" {
  result=$(keyword_match "battery")
  [ "$result" = "omarchy-battery-remaining" ]
}

@test "keyword: 'lock screen'" {
  result=$(keyword_match "lock screen")
  [ "$result" = "omarchy-lock-screen" ]
}

@test "keyword: 'keybindings'" {
  result=$(keyword_match "keybindings")
  [ "$result" = "omarchy-menu-keybindings" ]
}

@test "keyword: 'storage'" {
  result=$(keyword_match "storage")
  [[ "$result" == *"df -h"* ]]
}

# ══════════════════════════════════════════════════════════════════════════════
# Command validation
# ══════════════════════════════════════════════════════════════════════════════

@test "validate: omarchy-theme-set is valid" {
  run validate_command "omarchy-theme-set catppuccin"
  [ "$status" -eq 0 ]
}

@test "validate: hyprctl dispatch is valid" {
  run validate_command "hyprctl dispatch fullscreen"
  [ "$status" -eq 0 ]
}

@test "validate: wpctl is valid" {
  run validate_command "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
  [ "$status" -eq 0 ]
}

@test "validate: date is valid" {
  run validate_command "date '+%H:%M'"
  [ "$status" -eq 0 ]
}

@test "validate: sudo pacman is valid" {
  run validate_command "sudo pacman -Syu"
  [ "$status" -eq 0 ]
}

@test "validate: gibberish is invalid" {
  run validate_command "asdfghjkl_not_a_command zxcvbnm"
  [ "$status" -eq 1 ]
}

# ══════════════════════════════════════════════════════════════════════════════
# Claude trigger detection
# ══════════════════════════════════════════════════════════════════════════════

@test "needs_claude: 'write a script to backup dots'" {
  run needs_claude "write a script to backup dots"
  [ "$status" -eq 0 ]
}

@test "needs_claude: 'explain how hyprland works'" {
  run needs_claude "explain how hyprland works"
  [ "$status" -eq 0 ]
}

@test "needs_claude: 'use claude to fix this'" {
  run needs_claude "use claude to fix this"
  [ "$status" -eq 0 ]
}

@test "needs_claude: 'how do i set up docker'" {
  run needs_claude "how do i set up docker"
  [ "$status" -eq 0 ]
}

@test "needs_claude: 'volume up' does not trigger claude" {
  run needs_claude "volume up"
  [ "$status" -eq 1 ]
}

@test "needs_claude: 'set theme dark' does not trigger claude" {
  run needs_claude "set theme dark"
  [ "$status" -eq 1 ]
}
