# opencode-usage

OpenCode `/usage` skill — Claude API rate limit(5H/7D)과 계정 정보를 확인합니다.

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
mkdir -p ~/.config/opencode/skills/usage/scripts

curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/scripts/usage.sh \
  -o ~/.config/opencode/skills/usage/scripts/usage.sh
curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/SKILL.md \
  -o ~/.config/opencode/skills/usage/SKILL.md

chmod +x ~/.config/opencode/skills/usage/scripts/usage.sh
```

## 사전 요구사항

- **python3** 또는 **jq** (macOS에 python3 기본 포함 — 추가 설치 불필요)
- **OpenCode 인증**: `opencode auth login` (Anthropic OAuth)
- 또는 **Claude Code 인증**: `claude login` (macOS Keychain 사용)

## 사용법

OpenCode에서 `/usage` 입력.

## 토큰 조회 우선순위

1. `~/.local/share/opencode/auth.json` (OpenCode OAuth)
2. macOS Keychain `Claude Code-credentials` (Claude Code CLI)

## 표시 정보

| 항목 | 출처 |
|------|------|
| Account (이메일 / 플랜) | Anthropic `/api/oauth/profile` |
| 5H / 7D Rate Limit | Anthropic `/api/oauth/usage` |
