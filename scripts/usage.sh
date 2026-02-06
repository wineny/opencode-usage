#!/usr/bin/env bash
# usage.sh — Claude API usage (5H/7D rate limit) + account info

set -euo pipefail

AUTH_FILE="$HOME/.local/share/opencode/auth.json"
KEYCHAIN_SERVICE="Claude Code-credentials"

# ── JSON parser: python3 (macOS built-in) or jq ──────────────
json_get() {
  local json="$1" path="$2"
  if command -v python3 &>/dev/null; then
    python3 -c "
import json,sys
try:
  d=json.loads(sys.stdin.read())
  keys='$path'.split('.')
  for k in keys:
    if not isinstance(d,dict) or k not in d: sys.exit(0)
    d=d[k]
  if d is None: sys.exit(0)
  print(d)
except: pass
" <<< "$json"
  elif command -v jq &>/dev/null; then
    echo "$json" | jq -r ".$path // empty" 2>/dev/null
  else
    echo "python3 또는 jq가 필요합니다." >&2
    exit 1
  fi
}

json_has() {
  local json="$1" path="$2"
  local val=$(json_get "$json" "$path")
  [[ -n "$val" ]]
}

# ── OAuth token: try OpenCode auth.json first, then Keychain ──
TOKEN=""
if [[ -f "$AUTH_FILE" ]]; then
  TOKEN=$(json_get "$(cat "$AUTH_FILE")" "anthropic.access")
fi
if [[ -z "$TOKEN" ]]; then
  CRED_JSON=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null) || true
  if [[ -n "$CRED_JSON" ]]; then
    TOKEN=$(json_get "$CRED_JSON" "claudeAiOauth.accessToken")
  fi
fi
if [[ -z "$TOKEN" ]]; then
  echo "Claude 인증정보를 찾을 수 없습니다. opencode auth login 또는 claude login 실행 후 다시 시도하세요."
  exit 1
fi

# ── Parallel fetch: usage API + profile API ───────────────────
TMPDIR_USAGE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_USAGE"' EXIT

AUTH_HEADERS=(-H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20")

curl -s --max-time 10 https://api.anthropic.com/api/oauth/usage \
  "${AUTH_HEADERS[@]}" > "$TMPDIR_USAGE/usage.json" 2>/dev/null &
curl -s --max-time 10 https://api.anthropic.com/api/oauth/profile \
  "${AUTH_HEADERS[@]}" > "$TMPDIR_USAGE/profile.json" 2>/dev/null &
wait

# ── Parse usage ───────────────────────────────────────────────
API_RESPONSE=$(cat "$TMPDIR_USAGE/usage.json" 2>/dev/null)
API_OK=true
if ! json_has "$API_RESPONSE" "five_hour"; then
  API_OK=false
fi

relative_time() {
  local iso_ts="$1"
  [[ -z "$iso_ts" ]] && return
  local clean=$(echo "$iso_ts" | sed -E 's/\.[0-9]+//; s/\+00:00$/Z/')
  local epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$clean" "+%s" 2>/dev/null) || \
  epoch=$(date -d "$iso_ts" "+%s" 2>/dev/null) || return
  local diff=$((epoch - $(date "+%s")))
  if ((diff <= 0)); then echo "now"; return; fi
  local d=$((diff / 86400)) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  if ((d > 0)); then echo "${d}d ${h}h"
  elif ((h > 0)); then echo "${h}h ${m}m"
  else echo "${m}m"
  fi
}

if $API_OK; then
  FIVE_H_UTIL=$(json_get "$API_RESPONSE" "five_hour.utilization")
  FIVE_H_PCT=${FIVE_H_UTIL%.*}
  FIVE_H_RESET=$(relative_time "$(json_get "$API_RESPONSE" "five_hour.resets_at")")
  SEVEN_D_UTIL=$(json_get "$API_RESPONSE" "seven_day.utilization")
  SEVEN_D_PCT=${SEVEN_D_UTIL%.*}
  SEVEN_D_RESET=$(relative_time "$(json_get "$API_RESPONSE" "seven_day.resets_at")")
fi

# ── Parse profile ─────────────────────────────────────────────
PROFILE_RESPONSE=$(cat "$TMPDIR_USAGE/profile.json" 2>/dev/null)
ACCOUNT_EMAIL=""
PLAN_LABEL=""
if json_has "$PROFILE_RESPONSE" "account"; then
  ACCOUNT_EMAIL=$(json_get "$PROFILE_RESPONSE" "account.email")
  ORG_TYPE=$(json_get "$PROFILE_RESPONSE" "organization.organization_type")
  RATE_TIER=$(json_get "$PROFILE_RESPONSE" "organization.rate_limit_tier")
  TIER_SUFFIX=$(echo "$RATE_TIER" | grep -oE '[0-9]+x$' || true)
  case "$ORG_TYPE" in
    claude_max) PLAN_LABEL="Max${TIER_SUFFIX:+ $TIER_SUFFIX}" ;;
    claude_pro) PLAN_LABEL="Pro" ;;
    claude_team) PLAN_LABEL="Team" ;;
    *) PLAN_LABEL="$ORG_TYPE" ;;
  esac
fi

# ── Box output ────────────────────────────────────────────────
BOX_W=42

pad() {
  local label="$1" value="$2" w=$((BOX_W - 4))
  local content="${label}${value}"
  local len=${#content}
  local spaces=$((w - len))
  ((spaces < 0)) && spaces=0
  printf "| %s%*s |\n" "$content" "$spaces" ""
}

hline() {
  local ch="$1" left="$2" right="$3" label="${4:-}"
  local inner=$((BOX_W - 2))
  if [[ -n "$label" ]]; then
    local lbl=" $label "
    local lbl_len=${#lbl}
    local rest=$((inner - 1 - lbl_len))
    printf "%s%s%s%s%s\n" "$left" "$ch" "$lbl" "$(printf '%*s' "$rest" '' | tr ' ' "$ch")" "$right"
  else
    printf "%s%s%s\n" "$left" "$(printf '%*s' "$inner" '' | tr ' ' "$ch")" "$right"
  fi
}

echo ""

if [[ -n "$ACCOUNT_EMAIL" ]]; then
  hline "-" "+" "+" "Account"
  pad "$ACCOUNT_EMAIL" " / $PLAN_LABEL"
fi

if $API_OK; then
  hline "-" "+" "+" "Claude Usage"

  FIVE_LINE="5H Limit:  ${FIVE_H_PCT}%"
  [[ -n "$FIVE_H_RESET" ]] && FIVE_LINE="${FIVE_LINE}  (reset: ${FIVE_H_RESET})"
  SEVEN_LINE="7D Limit:  ${SEVEN_D_PCT}%"
  [[ -n "$SEVEN_D_RESET" ]] && SEVEN_LINE="${SEVEN_LINE}  (reset: ${SEVEN_D_RESET})"
  pad "$FIVE_LINE" ""
  pad "$SEVEN_LINE" ""

  hline "-" "+" "+"
else
  echo "API 호출 실패. 네트워크를 확인하세요."
fi
echo ""
