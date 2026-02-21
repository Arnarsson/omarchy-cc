#!/usr/bin/env bats
load test_helper

setup() {
  export CACHE_DIR="$(mktemp -d /tmp/omarchy-cc-test.XXXXXX)"
}

teardown() {
  [[ -d "${CACHE_DIR:-}" ]] && rm -rf "$CACHE_DIR" || true
}

@test "tmux list shows header with CPU/MEM columns" {
  command -v tmux || skip "tmux not installed"
  result=$("$OMARCHY_CC_DIR/bin/omarchy-cc-tmux" list 2>&1)
  # Should show either sessions with CPU%/MEM% or "No active"
  [[ "$result" == *"CPU%"* ]] || [[ "$result" == *"No active"* ]]
}

@test "tmux list shows MEM% column" {
  command -v tmux || skip "tmux not installed"
  result=$("$OMARCHY_CC_DIR/bin/omarchy-cc-tmux" list 2>&1)
  [[ "$result" == *"MEM%"* ]] || [[ "$result" == *"No active"* ]]
}

@test "tmux kill nonexistent session gives error" {
  result=$("$OMARCHY_CC_DIR/bin/omarchy-cc-tmux" kill "nonexistent_session_xyz_999" 2>&1)
  [[ "$result" == *"not found"* ]]
}

@test "tmux unknown action gives error" {
  run "$OMARCHY_CC_DIR/bin/omarchy-cc-tmux" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown action"* ]]
}

@test "route: 'tmux monitor' routes to monitor command" {
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-route"
  result=$(pattern_match "tmux monitor")
  [ "$result" = "omarchy-cc-tmux monitor" ]
}

@test "route: 'monitor sessions' routes to monitor command" {
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc-route"
  result=$(pattern_match "monitor sessions")
  [ "$result" = "omarchy-cc-tmux monitor" ]
}
