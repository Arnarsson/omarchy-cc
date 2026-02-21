#!/bin/bash
# Test helper for omarchy-cc bats tests.
# Sources functions from CC scripts without executing main().

export OMARCHY_CC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CONFIG_DIR="$OMARCHY_CC_DIR/config"

# Source functions from a script, stripping the final main "$@" call.
# Also neutralizes set -e so it doesn't leak into the test runner.
source_functions() {
  local script="$1"
  local tmp
  tmp=$(mktemp)
  sed -e 's/^main "\$@"$//' \
      -e 's/^set -euo pipefail$/set -uo pipefail/' \
      "$script" > "$tmp"
  source "$tmp"
  rm -f "$tmp"
  set +e
}
