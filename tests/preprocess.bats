#!/usr/bin/env bats
load test_helper

setup() {
  export CACHE_DIR="$(mktemp -d /tmp/omarchy-cc-test.XXXXXX)"
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-route"
}

teardown() {
  [[ -d "${CACHE_DIR:-}" ]] && rm -rf "$CACHE_DIR" || true
}

# ── normalize ──

@test "normalize: lowercases input" {
  result=$(normalize "SET THEME Tokyo Night")
  [ "$result" = "set theme tokyo night" ]
}

@test "normalize: expands what's → what" {
  result=$(normalize "what's the theme")
  [ "$result" = "what the theme" ]
}

@test "normalize: expands don't → do not" {
  result=$(normalize "don't do that")
  [ "$result" = "do not do that" ]
}

@test "normalize: trims whitespace" {
  result=$(normalize "  hello   world  ")
  [ "$result" = "hello world" ]
}

@test "normalize: collapses multiple spaces" {
  result=$(normalize "set    theme    dark")
  [ "$result" = "set theme dark" ]
}

# ── strip_filler ──

@test "strip_filler: removes 'can you please'" {
  result=$(strip_filler "can you please set the theme")
  [ "$result" = "set theme" ]
}

@test "strip_filler: removes 'would you'" {
  result=$(strip_filler "would you dim the screen")
  [ "$result" = "dim screen" ]
}

@test "strip_filler: removes 'a little bit'" {
  result=$(strip_filler "make it a little bit louder")
  [ "$result" = "make louder" ]
}

@test "strip_filler: removes 'just'" {
  result=$(strip_filler "just mute it")
  [ "$result" = "mute" ]
}

@test "strip_filler: removes 'please'" {
  result=$(strip_filler "please turn on nightlight")
  [ "$result" = "turn on nightlight" ]
}

@test "strip_filler: removes 'i want to'" {
  result=$(strip_filler "i want to change the theme")
  [ "$result" = "change theme" ]
}

@test "strip_filler: preserves meaningful words" {
  result=$(strip_filler "set theme catppuccin")
  [ "$result" = "set theme catppuccin" ]
}

# ── normalize_synonyms ──

@test "synonyms: louder → volume up" {
  result=$(normalize_synonyms "louder")
  [ "$result" = "volume up" ]
}

@test "synonyms: quieter → volume down" {
  result=$(normalize_synonyms "quieter")
  [ "$result" = "volume down" ]
}

@test "synonyms: dim → brightness down" {
  result=$(normalize_synonyms "dim")
  [ "$result" = "brightness down" ]
}

@test "synonyms: brighter → brightness up" {
  result=$(normalize_synonyms "brighter")
  [ "$result" = "brightness up" ]
}

@test "synonyms: maximize → fullscreen" {
  result=$(normalize_synonyms "maximize")
  [ "$result" = "fullscreen" ]
}

@test "synonyms: turn on → toggle" {
  result=$(normalize_synonyms "turn on nightlight")
  [ "$result" = "toggle nightlight" ]
}

@test "synonyms: turn off → toggle" {
  result=$(normalize_synonyms "turn off nightlight")
  [ "$result" = "toggle nightlight" ]
}

@test "synonyms: silence → mute" {
  result=$(normalize_synonyms "silence")
  [ "$result" = "mute" ]
}

@test "synonyms: kill → close" {
  result=$(normalize_synonyms "kill window")
  [ "$result" = "close window" ]
}

@test "synonyms: themes → theme (plural reduction)" {
  result=$(normalize_synonyms "list themes")
  [ "$result" = "list theme" ]
}

@test "synonyms: show → list" {
  result=$(normalize_synonyms "show fonts")
  [ "$result" = "list font" ]
}

# ── Full pipeline ──

@test "pipeline: 'can you please make it a bit louder' → 'volume up'" {
  result=$(preprocess "can you please make it a bit louder")
  [ "$result" = "volume up" ]
}

@test "pipeline: 'would you dim the screen a little' → 'brightness down'" {
  result=$(preprocess "would you dim the screen a little")
  [ "$result" = "brightness down" ]
}

@test "pipeline: 'just turn on the night light' → 'toggle night light'" {
  result=$(preprocess "just turn on the night light")
  [ "$result" = "toggle night light" ]
}

@test "pipeline: 'show me all the themes please' → 'list theme'" {
  result=$(preprocess "show me all the themes please")
  [ "$result" = "list theme" ]
}

@test "pipeline: 'can you maximize this window' → 'fullscreen window'" {
  result=$(preprocess "can you maximize this window")
  [ "$result" = "fullscreen window" ]
}
