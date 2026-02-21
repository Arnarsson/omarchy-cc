#!/usr/bin/env bats
load test_helper

setup() {
  export CACHE_DIR="$(mktemp -d /tmp/omarchy-cc-test.XXXXXX)"
}

teardown() {
  [[ -d "${CACHE_DIR:-}" ]] && rm -rf "$CACHE_DIR" || true
}

@test "config parser reads all defaults when no file" {
  export XDG_CONFIG_HOME="$CACHE_DIR/nonexistent"
  eval "$("$OMARCHY_CC_DIR/bin/omarchy-cc-config")"
  [ "$CC_OLLAMA_MODEL" = "qwen2.5-coder:7b" ]
  [ "$CC_HISTORY_SIZE" = "100" ]
  [ "$CC_TTS_ENABLED" = "false" ]
  [ "$CC_CLAUDE_ENABLED" = "true" ]
  [ "$CC_AUTO_EXECUTE_SAFE" = "true" ]
  [ "$CC_CONFIRM_RISKY" = "true" ]
}

@test "config parser reads custom values" {
  export XDG_CONFIG_HOME="$CACHE_DIR"
  mkdir -p "$CACHE_DIR/omarchy-cc"
  cat > "$CACHE_DIR/omarchy-cc/config.toml" <<'EOF'
[general]
ollama_model = "qwen2.5-coder:32b"
history_size = 50
tts_enabled = true

[safety]
auto_execute_safe = false
EOF
  eval "$("$OMARCHY_CC_DIR/bin/omarchy-cc-config")"
  [ "$CC_OLLAMA_MODEL" = "qwen2.5-coder:32b" ]
  [ "$CC_HISTORY_SIZE" = "50" ]
  [ "$CC_TTS_ENABLED" = "true" ]
  [ "$CC_AUTO_EXECUTE_SAFE" = "false" ]
}

@test "config parser ignores comments and section headers" {
  export XDG_CONFIG_HOME="$CACHE_DIR"
  mkdir -p "$CACHE_DIR/omarchy-cc"
  cat > "$CACHE_DIR/omarchy-cc/config.toml" <<'EOF'
# This is a comment
[general]
ollama_model = "test-model"
# another comment
[safety]
confirm_risky = false
EOF
  eval "$("$OMARCHY_CC_DIR/bin/omarchy-cc-config")"
  [ "$CC_OLLAMA_MODEL" = "test-model" ]
  [ "$CC_CONFIRM_RISKY" = "false" ]
}

@test "config output is valid shell" {
  # Ensure the output can be eval'd without errors
  result=$("$OMARCHY_CC_DIR/bin/omarchy-cc-config" 2>&1)
  eval "$result"
  [ $? -eq 0 ]
}
