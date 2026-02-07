# opencode-usage

OpenCode `/usage-claudecode` skill — Claude API rate limit(5H/7D)과 계정 정보를 확인합니다.

```
+- Account ------------------------------+
| support@gpters.org / Max 20x           |
+- Claude Usage -------------------------+
| 5H Limit:  49%  (reset: 1h 19m)        |
| 7D Limit:  58%  (reset: 4d 20h)        |
+----------------------------------------+
```

## 설치

```bash
mkdir -p ~/.config/opencode/skills/usage-claudecode/scripts

curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/scripts/usage.sh \
  -o ~/.config/opencode/skills/usage-claudecode/scripts/usage.sh
curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/SKILL.md \
  -o ~/.config/opencode/skills/usage-claudecode/SKILL.md

chmod +x ~/.config/opencode/skills/usage-claudecode/scripts/usage.sh
```

## 사전 요구사항

- **macOS** (추가 설치 불필요 — python3/jq/osascript 자동 감지, Windows 미지원)
- **OpenCode 인증**: `opencode auth login` (Anthropic OAuth)
- 또는 **Claude Code 인증**: `claude login` (macOS Keychain 사용)

## 사용법

OpenCode에서 `/usage-claudecode` 입력.

## 토큰 조회 우선순위

1. `~/.local/share/opencode/auth.json` — 유효하면 바로 사용
2. auth.json 토큰 만료 시 → **refresh token으로 자동 갱신** (auth.json 업데이트)
3. refresh 실패 시 → macOS Keychain `Claude Code-credentials` fallback

OAuth access token은 8시간마다 만료됩니다.
이전에는 만료 시 수동으로 `claude login`을 해야 했지만, 이제 자동으로 갱신됩니다.

## 업데이트

이미 설치한 경우 스크립트만 다시 받으면 됩니다:

```bash
curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/scripts/usage.sh \
  -o ~/.config/opencode/skills/usage-claudecode/scripts/usage.sh
```

## 표시 정보

| 항목 | 출처 |
|------|------|
| Account (이메일 / 플랜) | Anthropic `/api/oauth/profile` |
| 5H / 7D Rate Limit | Anthropic `/api/oauth/usage` |
