#!/usr/bin/env bats
load test_helper

setup() {
  export CACHE_DIR="$(mktemp -d /tmp/omarchy-cc-test.XXXXXX)"
  export HISTORY_FILE="$CACHE_DIR/history"
  export HISTORY_SIZE=100
  touch "$HISTORY_FILE"
  source_functions "$OMARCHY_CC_DIR/bin/omarchy-cc"
}

teardown() {
  [[ -d "${CACHE_DIR:-}" ]] && rm -rf "$CACHE_DIR" || true
}

@test "add_history writes TSV format" {
  add_history "volume up"
  local line
  line=$(cat "$HISTORY_FILE")
  # Should be: <timestamp>\t<command>
  [[ "$line" == *$'\t'"volume up" ]]
}

@test "add_history appends multiple entries" {
  add_history "volume up"
  add_history "set theme dark"
  local count
  count=$(wc -l < "$HISTORY_FILE")
  [ "$count" -eq 2 ]
}

@test "add_history trims when exceeding max size" {
  HISTORY_SIZE=3
  add_history "one"
  add_history "two"
  add_history "three"
  add_history "four"
  local count
  count=$(wc -l < "$HISTORY_FILE")
  [ "$count" -eq 3 ]
  # "one" should be gone
  ! grep -q "one" "$HISTORY_FILE"
}

@test "get_suggestions returns most frequent commands" {
  local now
  now=$(date +%s)
  # Add "volume up" 5 times, "set theme dark" once
  for i in {1..5}; do
    echo "$now	volume up" >> "$HISTORY_FILE"
  done
  echo "$now	set theme dark" >> "$HISTORY_FILE"

  local top
  top=$(get_suggestions 1)
  [ "$top" = "volume up" ]
}

@test "get_suggestions weights recent commands higher" {
  local now old
  now=$(date +%s)
  old=$((now - 100000))  # ~1 day ago

  # "old command" used 3 times long ago
  for i in {1..3}; do
    echo "$old	old command" >> "$HISTORY_FILE"
  done
  # "new command" used 2 times just now
  for i in {1..2}; do
    echo "$now	new command" >> "$HISTORY_FILE"
  done

  local top
  top=$(get_suggestions 1)
  # new command (2 × weight 10 = 20) should beat old command (3 × weight 1 = 3)
  [ "$top" = "new command" ]
}

@test "get_suggestions returns empty for empty history" {
  local result
  result=$(get_suggestions 5)
  [ -z "$result" ]
}
