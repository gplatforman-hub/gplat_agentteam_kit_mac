#!/bin/bash
# 내 작업 백업 (맥) — 내가 만든 것만 묶는다. .env·토큰·로그인 정보·설치 꾸러미는 절대 넣지 않는다.
set -u
KIT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-}"
if [ -z "$OUT" ]; then
    PARENT="$(dirname "$KIT")"
    if [ "$(basename "$PARENT")" = "01_KIT" ]; then OUT="$(dirname "$PARENT")/04_LEARNER_BACKUP"; else OUT="$KIT/backup"; fi
fi
mkdir -p "$OUT" || { echo "백업 폴더를 만들 수 없습니다: $OUT"; exit 1; }
STAMP=$(date +%Y%m%d_%H%M%S)
ZIP="$OUT/My_AI_Company_$STAMP.zip"
STAGE=$(mktemp -d -t wdbackup)
trap 'rm -rf "$STAGE"' EXIT
for item in workspace .claude/agents .claude/skills slack-server/personas.py slack-server/agent_channels.py README.md; do
    [ -e "$KIT/$item" ] || continue
    mkdir -p "$STAGE/$(dirname "$item")"
    cp -R "$KIT/$item" "$STAGE/$item"
done
cat > "$STAGE/RESTORE.txt" <<'EOF'
RESTORE MY AI COMPANY
1. Install a clean starter-kit on the new Mac (or PC).
2. Turn off the Slack server (자동시작_끄기).
3. Extract this ZIP.
4. Copy workspace and .claude into the installed starter-kit; allow overwrite.
5. Recreate slack-server/.env and sign in again. Secrets and login state are intentionally not backed up.
EOF
if [ -n "$(find "$STAGE" \( -name .env -o -name .agent_session.json -o -name .naver-state.json -o -name '*.pyc' \) -print -quit)" ]; then
    echo "백업 안전 검사 실패: 비밀 파일이 섞였습니다. 백업을 만들지 않습니다."; exit 1
fi
COUNT=$(find "$STAGE" -type f | wc -l | tr -d ' ')
[ "$COUNT" -gt 1 ] || { echo "백업할 내 파일이 없습니다."; exit 1; }
( cd "$STAGE" && zip -qr "$ZIP" . ) || { echo "ZIP 만들기 실패"; exit 1; }
echo ""
printf '\033[32m백업 완료.\033[0m\n'
echo "파일: $COUNT 개"
echo "ZIP: $ZIP"
echo "SHA-256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
open "$OUT" 2>/dev/null
