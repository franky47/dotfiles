#!/bin/bash

set -euo pipefail

URL=${OPENUSAGE_URL:-http://127.0.0.1:6736}
NOW=${OPENUSAGE_NOW:-$(date +%s)}

usage() {
  cat <<'EOF'
Usage: usage.sh [target]        one line per limit
       usage.sh check <target>  exit 0 while under the pace line,
                                1 once caught up, spent, stale or reset (under 5% used)
       usage.sh gate <target>   exit 0 under a 10% pace line or more than 5 pts under it,
                                1 otherwise (within 5 pts, over, spent, stale, reset due)

Both exit 2 on errors.

A target is a provider (claude), a model (opus, gpt-5, fable),
an account (codex@ab12cd34) or one limit (claude/weekly).
EOF
}

die() {
  printf 'usage.sh: %s\n' "$1" >&2
  exit 2
}

fetch_limits() {
  local json
  json=$(curl -sf -m 5 "$URL/v1/limits") || die "OpenUsage is not running (start it with: open -a OpenUsage)"
  jq -e '.providers | type == "object"' <<<"$json" >/dev/null 2>&1 || die "unreadable response from OpenUsage"
  echo "$json"
}

resolve_provider_and_scope() {
  local target
  target=$(tr '[:upper:]' '[:lower:]' <<<"$1")
  case $target in
    */*) echo "${target%%/*} ${target#*/}" ;;
    claude | *@*) echo "$target all" ;;
    *fable*) echo "claude fable" ;;
    claude* | *opus* | *sonnet* | *haiku*) echo "claude shared" ;;
    gpt* | codex* | o[0-9]*) echo "codex all" ;;
    *) echo "$target all" ;;
  esac
}

require_target() {
  local json=$1 target=$2 provider=$3 scope=$4 known
  known=$(jq -r '.providers | keys_unsorted | map(sub("@.*"; ""), select(contains("@"))) | unique[] | ascii_downcase' <<<"$json")
  grep -qxF -- "$provider" <<<"$known" ||
    die "unknown provider or model: $provider (known: ${known//$'\n'/, })"
  case $scope in
    all | shared) ;;
    *) jq -e --arg p "$provider" --arg s "$scope" '
         any(.providers | to_entries[] | select(.key | ascii_downcase | . == $p or sub("@.*"; "") == $p)
             | .value.resources | keys[]; ascii_downcase == $s)' <<<"$json" >/dev/null ||
      die "no $target limit on this plan" ;;
  esac
}

limits() {
  local target=$1 mode=$2 json provider='' scope=all status=0
  json=$(fetch_limits)
  if [ -n "$target" ]; then
    read -r provider scope <<<"$(resolve_provider_and_scope "$target")"
    require_target "$json" "$target" "$provider" "$scope"
  fi
  jq -r --arg provider "$provider" --arg scope "$scope" --arg mode "$mode" --arg target "$target" \
    --argjson now "$NOW" '
    def iso: sub("\\.[0-9]+Z$"; "Z");
    def ts: iso | fromdateiso8601;
    def duration: (. / 60 | floor) as $m
      | if $m >= 1440 then "\($m / 1440 | floor)d \($m % 1440 / 60 | floor)h"
        elif $m >= 60 then "\($m / 60 | floor)h \($m % 60)m"
        else "\($m)m" end;
    def matches($id): $provider == "" or ($id | ascii_downcase | . == $provider or sub("@.*"; "") == $provider);
    def in_scope($key):
      ($key | ascii_downcase) as $k
      | $scope == "all" or (if $scope == "shared" then $k != "fable" else $k == $scope end);
    def capped($r; $left):
      ($r.used / $r.limit * 100 | round) as $used
      | (if $r.unit == "percent" then 1 elif $r.unit | test("^[a-z]{3}$") then 0.01 else 0.1 end) as $step
      | ($r.windowSeconds // 0) as $window
      | "\($used)% used" as $head
      | "resets in \($left | duration) at \($r.resetsAt | iso)" as $resets
      | if $left == null then {line: $head}
        elif $left <= 0 then {line: "\($head), reset due", blocked: true}
        elif (($r.limit - $r.used) / $step | round) <= 0 then {line: "\($head), spent, \($resets)", blocked: true}
        elif $window == 0 then {line: "\($head), \($resets)"}
        else ([$window - $left, 0] | max / $window * 100) as $pace
          | ($pace - $r.used / $r.limit * 100) as $gap
          | ($gap | fabs | round | if . == 0 then "<1" else . end) as $pts
          | { line: "\($head), pace \($pace | round)% (\(if $gap > 0 then "\($pts) pts under" elif $gap < 0 then "\($pts) pts over" else "on pace" end)), \($resets)",
              gap: $gap, pace: $pace, used: ($r.used / $r.limit) }
        end;
    def limit($r):
      ($r.resetsAt // null | if . then ts - $now else null end) as $left
      | if ($r.limit // 0) > 0 then capped($r; $left) else {line: "\($r.used) \($r.unit) used"} end;
    def go:
      if .blocked or .stale then false
      elif $mode == "check" then .gap > 0 and .used >= 0.05
      else .pace < 10 or .gap > 5 end;
    [ .providers | to_entries[] | select(matches(.key))
        | .key as $p | .value.stale as $stale
        | .value.resources | to_entries[] | select(.value.kind == "consumption" and in_scope(.key))
        | .key as $k | limit(.value) + {stale: $stale}
        | .line = "\($p)/\($k): \(.line)\(if $stale then " [stale]" else "" end)" ] as $limits
    | ($limits[] | .line),
      if $mode == "show" then empty
      else [$limits[] | select(.gap or .blocked) | go] as $decisions
        | if $decisions == [] then "usage.sh: no pace line for \($target)\n" | halt_error(2)
          elif $decisions | all then empty
          else "" | halt_error(1) end
      end
  ' <<<"$json" || status=$?
  [ "$status" -le 2 ] || die "unreadable response from OpenUsage"
  return "$status"
}

decide() {
  local mode=$1
  shift
  [ $# -gt 0 ] || die "$mode needs a provider or model"
  [ $# -eq 1 ] || die "unexpected argument: $2"
  limits "$1" "$mode"
}

case ${1:-} in
  -h | --help) usage ;;
  check | gate) decide "$@" ;;
  *) limits "${1:-}" show ;;
esac
