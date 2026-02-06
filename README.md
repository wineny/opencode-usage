# opencode-usage

OpenCode `/usage` skill — Claude API rate limit(5H/7D)과 세션 통계를 확인합니다.

```
+- Account ------------------------------+
| support@gpters.org / Max 20x           |
+- Claude Usage -------------------------+
| 5H Limit:  37%  (reset: 1h 37m)        |
| 7D Limit:  56%  (reset: 4d 20h)        |
+- Session Stats ------------------------+
| Avg Tokens:     1.7M/session           |
| Sessions:       668                    |
+----------------------------------------+
```

## 설치

```bash
# 디렉토리 생성
mkdir -p ~/.config/opencode/skill/usage/scripts

# 파일 다운로드
curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/scripts/usage.sh \
  -o ~/.config/opencode/skill/usage/scripts/usage.sh
curl -fsSL https://raw.githubusercontent.com/wineny/opencode-usage/master/SKILL.md \
  -o ~/.config/opencode/skill/usage/SKILL.md

# 실행 권한
chmod +x ~/.config/opencode/skill/usage/scripts/usage.sh
```

## 사전 요구사항

- **jq**: `brew install jq`
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
| Avg Tokens, Sessions | `opencode stats` |
