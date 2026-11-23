#!/bin/bash

set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
CLI="$TEST_DIR/../usage.sh"

export OPENUSAGE_URL="file://$TEST_DIR/fixtures"
export OPENUSAGE_NOW=1795197600

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_exit() {
  local code=$1 expected=$2
  shift 2
  local actual status=0
  actual=$(bash "$CLI" "$@" 2>&1) || status=$?
  [ "$status" = "$code" ] || fail "expected exit $code, got $status for: $*"$'\n'"$actual"
  [ "$actual" = "$expected" ] || fail "for: $*"$'\n'"expected:"$'\n'"$expected"$'\n'"actual:"$'\n'"$actual"
}

assert_output() { assert_exit 0 "$@"; }

assert_fails() {
  local pattern=$1
  shift
  local actual status=0
  actual=$(bash "$CLI" "$@" 2>&1) || status=$?
  [ "$status" = 2 ] || fail "expected exit 2, got $status for: $*"$'\n'"$actual"
  grep -q -- "$pattern" <<<"$actual" || fail "for: $* expected '$pattern' in: $actual"
}

CLAUDE_WEEKLY='claude/weekly: 33% used, pace 51% (18 pts under), resets in 3d 10h at 2026-11-24T04:00:00Z'
CLAUDE_FABLE='claude/fable: 38% used, pace 51% (13 pts under), resets in 3d 10h at 2026-11-24T04:00:00Z'
CODEX_WEEKLY='codex/weekly: 60% used, pace 57% (3 pts over), resets in 3d 0h at 2026-11-23T18:00:00Z'
CODEX_ACCOUNT='codex@ab12cd34/weekly: 10% used, pace 57% (47 pts under), resets in 3d 0h at 2026-11-23T18:00:00Z'
CODEX="$CODEX_WEEKLY"$'\n'"$CODEX_ACCOUNT"
COPILOT='copilot/premiumCredits: 62% used, pace 66% (4 pts under), resets in 10d 6h at 2026-12-01T00:00:00Z [stale]
copilot/overage: 2 usd used [stale]'
ZAI='zai/weekly: 100% used, spent, resets in 1d 6h at 2026-11-22T00:00:00Z
zai/session: 0% used, pace 80% (80 pts under), resets in 1h 0m at 2026-11-20T19:00:00Z'
CURSOR='cursor/early: 4% used, pace 3% (1 pts over), resets in 6d 18h at 2026-11-27T12:57:36Z
cursor/nearly: 100% used, spent, resets in 3d 0h at 2026-11-23T18:00:00Z
cursor/overdue: 40% used, reset due
cursor/extra: 12.5 usd used
cursor/zeroLimit: 3 usd used
cursor/noWindow: 50% used, resets in 3d 0h at 2026-11-23T18:00:00Z
cursor/euro: 100% used, pace 57% (43 pts over), resets in 3d 0h at 2026-11-23T18:00:00Z
cursor/onPace: 50% used, pace 50% (on pace), resets in 3d 12h at 2026-11-24T06:00:00Z
cursor/fresh: 0% used, pace 0% (<1 pts under), resets in 6d 23h at 2026-11-27T17:50:00Z
cursor/five: 5% used, pace 57% (52 pts under), resets in 3d 0h at 2026-11-23T18:00:00Z
cursor/margin: 45% used, pace 50% (5 pts under), resets in 3d 12h at 2026-11-24T06:00:00Z
cursor/room: 44% used, pace 50% (6 pts under), resets in 3d 12h at 2026-11-24T06:00:00Z
cursor/ten: 8% used, pace 10% (2 pts under), resets in 6d 7h at 2026-11-27T01:12:00Z
cursor/burst: 15% used, pace 3% (12 pts over), resets in 6d 18h at 2026-11-27T12:57:36Z
cursor/noReset: 30% used
cursor/nearCap: 97% used, resets in 3d 0h at 2026-11-23T18:00:00Z
cursor/low: 3% used, pace 57% (54 pts under), resets in 3d 0h at 2026-11-23T18:00:00Z
cursor/idle: 0% used
cursor/float: 9% used, pace 14% (5 pts under), resets in 6d 0h at 2026-11-26T18:28:48Z
cursor/spend: 2% used'

assert_output "$CLAUDE_WEEKLY"$'\n'"$CLAUDE_FABLE" claude
assert_output "$CODEX" codex
assert_output "$COPILOT" copilot
assert_output "$ZAI" zai
assert_output "$CURSOR" cursor
assert_output "$CLAUDE_WEEKLY"$'\n'"$CLAUDE_FABLE"$'\n'"$CODEX"$'\n'"$COPILOT"$'\n'"$ZAI"$'\n'"$CURSOR"

assert_output "$CLAUDE_FABLE" fable
assert_output "$CLAUDE_FABLE" claude-fable-5-2
assert_output "$CLAUDE_WEEKLY" opus
assert_output "$CLAUDE_WEEKLY" claude-sonnet-5-5
assert_output "$CLAUDE_WEEKLY" sonnet
assert_output "$CLAUDE_WEEKLY" claude-mythos-1
assert_output "$CLAUDE_WEEKLY" Haiku
assert_output "$CODEX" gpt-5.5-codex
assert_output "$CODEX" o3
assert_output "$CODEX_ACCOUNT" codex@ab12cd34
assert_output "$CODEX_ACCOUNT" CODEX@AB12CD34
assert_output "$CLAUDE_WEEKLY" claude/weekly
assert_output "$CODEX_ACCOUNT" codex@ab12cd34/weekly

assert_exit 0 "$CLAUDE_FABLE" check fable
assert_exit 0 "$CLAUDE_WEEKLY"$'\n'"$CLAUDE_FABLE" check claude
assert_exit 1 "$COPILOT" check copilot
assert_exit 1 "$CODEX" check codex
assert_exit 1 "$ZAI" check zai
assert_exit 1 "$CURSOR" check cursor
assert_exit 0 "$CODEX_ACCOUNT" check codex@ab12cd34/weekly
assert_exit 0 'cursor/five: 5% used, pace 57% (52 pts under), resets in 3d 0h at 2026-11-23T18:00:00Z' check cursor/five
assert_exit 1 'cursor/fresh: 0% used, pace 0% (<1 pts under), resets in 6d 23h at 2026-11-27T17:50:00Z' check cursor/fresh
assert_exit 1 'zai/session: 0% used, pace 80% (80 pts under), resets in 1h 0m at 2026-11-20T19:00:00Z' check zai/session
assert_exit 1 'cursor/onPace: 50% used, pace 50% (on pace), resets in 3d 12h at 2026-11-24T06:00:00Z' check cursor/onPace
OPENUSAGE_NOW=1795492800 assert_exit 1 'claude/fable: 38% used, reset due [stale]' check fable
OPENUSAGE_NOW=1795496400 assert_exit 1 'claude/fable: 38% used, reset due [stale]' check fable
assert_exit 1 'cursor/low: 3% used, pace 57% (54 pts under), resets in 3d 0h at 2026-11-23T18:00:00Z' check cursor/low
assert_exit 0 'cursor/nearCap: 97% used, resets in 3d 0h at 2026-11-23T18:00:00Z' check cursor/nearCap
assert_exit 1 'cursor/idle: 0% used' check cursor/idle
assert_exit 0 'cursor/spend: 2% used' check cursor/spend

assert_exit 0 "$CLAUDE_FABLE" gate fable
assert_exit 0 "$CLAUDE_WEEKLY"$'\n'"$CLAUDE_FABLE" gate claude
assert_exit 0 "$CODEX_ACCOUNT" gate codex@ab12cd34
assert_exit 1 "$CODEX" gate codex
assert_exit 1 "$COPILOT" gate copilot
assert_exit 1 "$ZAI" gate zai
assert_exit 0 'zai/session: 0% used, pace 80% (80 pts under), resets in 1h 0m at 2026-11-20T19:00:00Z' gate zai/session
assert_exit 0 'cursor/five: 5% used, pace 57% (52 pts under), resets in 3d 0h at 2026-11-23T18:00:00Z' gate cursor/five
assert_exit 0 'cursor/fresh: 0% used, pace 0% (<1 pts under), resets in 6d 23h at 2026-11-27T17:50:00Z' gate cursor/fresh
assert_exit 0 'cursor/early: 4% used, pace 3% (1 pts over), resets in 6d 18h at 2026-11-27T12:57:36Z' gate cursor/early
assert_exit 1 'cursor/ten: 8% used, pace 10% (2 pts under), resets in 6d 7h at 2026-11-27T01:12:00Z' gate cursor/ten
assert_exit 0 'cursor/burst: 15% used, pace 3% (12 pts over), resets in 6d 18h at 2026-11-27T12:57:36Z' gate cursor/burst
assert_exit 1 'cursor/margin: 45% used, pace 50% (5 pts under), resets in 3d 12h at 2026-11-24T06:00:00Z' gate cursor/margin
assert_exit 1 'cursor/float: 9% used, pace 14% (5 pts under), resets in 6d 0h at 2026-11-26T18:28:48Z' gate cursor/float
assert_exit 1 'copilot/overage: 2 usd used [stale]' gate copilot/overage
assert_exit 0 'cursor/room: 44% used, pace 50% (6 pts under), resets in 3d 12h at 2026-11-24T06:00:00Z' gate cursor/room
assert_exit 1 'cursor/overdue: 40% used, reset due' gate cursor/overdue
assert_exit 1 'cursor/nearly: 100% used, spent, resets in 3d 0h at 2026-11-23T18:00:00Z' gate cursor/nearly
assert_exit 0 'cursor/noWindow: 50% used, resets in 3d 0h at 2026-11-23T18:00:00Z' gate cursor/noWindow
assert_exit 0 'cursor/noReset: 30% used' gate cursor/noReset
assert_exit 1 'cursor/nearCap: 97% used, resets in 3d 0h at 2026-11-23T18:00:00Z' gate cursor/nearCap
OPENUSAGE_NOW=1795800000 assert_exit 1 'copilot/premiumCredits: 62% used, pace 89% (27 pts under), resets in 3d 6h at 2026-12-01T00:00:00Z [stale]
copilot/overage: 2 usd used [stale]' gate copilot

assert_fails 'unknown provider or model: nope' nope
assert_fails 'claude, codex, codex@ab12cd34, copilot, cursor, zai' nope
assert_fails 'check needs a provider or model' check
assert_fails 'gate needs a provider or model' gate
assert_fails 'gate needs a provider or model' gate ''
assert_fails 'unexpected argument: bogus' claude bogus
assert_fails 'no claude/all limit' gate claude/all
assert_fails 'no claude/shared limit' check claude/shared
assert_fails 'no claude/rateLimitResets limit' claude/rateLimitResets
assert_fails 'unexpected argument: now' gate fable now
assert_fails 'no pace line for cursor/extra' gate cursor/extra
assert_fails 'unexpected argument: 2026-11-24T04:00:00Z' check fable 2026-11-24T04:00:00Z
assert_fails 'unexpected argument: --until' check fable --until 2026-11-24T04:00:00Z
assert_fails 'no claude/premiumCredits limit' claude/premiumCredits
assert_fails 'no pace line for cursor/extra' check cursor/extra
OPENUSAGE_URL="file://$TEST_DIR/fixtures/no-fable" assert_fails 'no fable limit' fable
OPENUSAGE_URL="file://$TEST_DIR/fixtures/accounts" assert_exit 0 "$CLAUDE_FABLE" check claude/fable
OPENUSAGE_URL="file://$TEST_DIR/fixtures/accounts" assert_exit 1 "$CLAUDE_FABLE"$'\n''claude@9f8e7d6c/fable: 2% used, pace 51% (49 pts under), resets in 3d 10h at 2026-11-24T04:00:00Z' check fable
OPENUSAGE_URL="file://$TEST_DIR/fixtures/accounts" assert_fails 'no claude/sonnet limit' claude/sonnet
OPENUSAGE_URL="file://$TEST_DIR/fixtures/garbage" assert_fails 'unreadable response from OpenUsage' claude
OPENUSAGE_URL="file://$TEST_DIR/fixtures/bad-date" assert_fails 'unreadable response from OpenUsage' check claude
OPENUSAGE_URL=http://127.0.0.1:9 assert_fails 'OpenUsage is not running' claude
grep -q 'Usage:' <<<"$(bash "$CLI" --help)" || fail '--help shows usage'

echo PASS
