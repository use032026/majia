#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/trip-delta-session-test.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

xcrun swiftc -module-cache-path "$test_dir/modules" \
  "$app_root/packages/stmini_flutter/ios/Classes/Web/STOnlineWebCore.swift" \
  "$app_root/test/native/session_bridge_test.swift" \
  -o "$test_dir/session_bridge_test"
"$test_dir/session_bridge_test"
