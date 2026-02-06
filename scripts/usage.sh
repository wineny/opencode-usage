#!/usr/bin/env bash
# usage.sh — Claude API usage (5H/7D rate limit) + OpenCode session stats

set -euo pipefail

AUTH_FILE="$HOME/.local/share/opencode/auth.json"
KEYCHAIN_SERVICE="Claude Code-credentials"

# ── Dependency check ──────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "jq가 필요합니다. brew install jq 실행하세요."
  exit 1
fi

# ── OAuth token: try OpenCode auth.json first, then Keychain ──
TOKEN=""
if [[ -f "$AUTH_FILE" ]]; then
  TOKEN=$(jq -r '.anthropic.access // empty' "$AUTH_FILE" 2>/dev/null)
fi
if [[ -z "$TOKEN" ]]; then
  CRED_JSON=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null) || true
  if [[ -n "$CRED_JSON" ]]; then
    TOKEN=$(echo "$CRED_JSON" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  fi
fi
if [[ -z "$TOKEN" ]]; then
  echo "Claude 인증정보를 찾을 수 없습니다. opencode auth login 또는 claude login 실행 후 다시 시도하세요."
  exit 1
fi

# ── Anthropic APIs ─────────────────────────────────────────────
AUTH_HEADERS=(-H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20")

API_RESPONSE=$(curl -s --max-time 10 \
  https://api.anthropic.com/api/oauth/usage \
  "${AUTH_HEADERS[@]}" 2>/dev/null) || true

API_OK=true
if [[ -z "$API_RESPONSE" ]] || ! echo "$API_RESPONSE" | jq -e '.five_hour' &>/dev/null; then
  API_OK=false
fi

PROFILE_RESPONSE=$(curl -s --max-time 10 \
  https://api.anthropic.com/api/oauth/profile \
  "${AUTH_HEADERS[@]}" 2>/dev/null) || true

ACCOUNT_EMAIL=""
PLAN_LABEL=""
if echo "$PROFILE_RESPONSE" | jq -e '.account' &>/dev/null; then
  ACCOUNT_EMAIL=$(echo "$PROFILE_RESPONSE" | jq -r '.account.email // empty')
  ORG_TYPE=$(echo "$PROFILE_RESPONSE" | jq -r '.organization.organization_type // empty')
  RATE_TIER=$(echo "$PROFILE_RESPONSE" | jq -r '.organization.rate_limit_tier // empty')
  # "default_claude_max_20x" → "max 20x"
  TIER_SUFFIX=$(echo "$RATE_TIER" | grep -oE '[0-9]+x$' || true)
  case "$ORG_TYPE" in
    claude_max) PLAN_LABEL="Max${TIER_SUFFIX:+ $TIER_SUFFIX}" ;;
    claude_pro) PLAN_LABEL="Pro" ;;
    claude_team) PLAN_LABEL="Team" ;;
    *) PLAN_LABEL="$ORG_TYPE" ;;
  esac
fi

# ── Parse API response ────────────────────────────────────────
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
  FIVE_H_PCT=$(echo "$API_RESPONSE" | jq -r '.five_hour.utilization // 0 | floor')
  FIVE_H_RESET=$(relative_time "$(echo "$API_RESPONSE" | jq -r '.five_hour.resets_at // empty')")
  SEVEN_D_PCT=$(echo "$API_RESPONSE" | jq -r '.seven_day.utilization // 0 | floor')
  SEVEN_D_RESET=$(relative_time "$(echo "$API_RESPONSE" | jq -r '.seven_day.resets_at // empty')")
fi

# ── OpenCode stats ────────────────────────────────────────────
STATS_OUTPUT=$(opencode stats 2>/dev/null) || STATS_OUTPUT=""

SESSIONS=""
AVG_TOKENS=""

if [[ -n "$STATS_OUTPUT" ]]; then
  SESSIONS=$(echo "$STATS_OUTPUT" | grep -E "Sessions" | head -1 | grep -oE '[0-9,]+' | tr -d ',')
  AVG_TOKENS=$(echo "$STATS_OUTPUT" | grep -E "Avg Tokens/Session" | grep -oE '[0-9]+\.[0-9]+[KMG]')
fi

# ── Defaults ──────────────────────────────────────────────────
SESSIONS=${SESSIONS:-"-"}
AVG_TOKENS=${AVG_TOKENS:-"-"}

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

  hline "-" "+" "+" "Session Stats"
else
  echo "API 호출 실패. 네트워크를 확인하세요. 세션 통계만 표시합니다."
  echo ""
  hline "-" "+" "+" "Session Stats"
fi

pad "Avg Tokens:     " "${AVG_TOKENS}/session"
pad "Sessions:       " "$SESSIONS"
hline "-" "+" "+"
echo ""
