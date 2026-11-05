#!/bin/bash
# ============================================================
#  install_starterkit.sh — 맥용 설치 본체 (윈도우판 install_starterkit.ps1 과 같은 일)
#
#  - ~/AgentOffice 표준 구조를 만든다.
#  - MyData/Report·Minutes·Track·Skill 폴더를 만들어 수강생이 미리 비식별 양식을 넣을 자리를 준다.
#  - 현재 스타터킷을 01_KIT/starter-kit 으로 복사한다 (비밀키·로그인 상태·기록은 복사하지 않음).
#  - 기존 설치가 있으면 덮어쓰지 않는다 (내 직원·스킬·슬랙 열쇠를 지킨다).
#  - 끝나면 묻지 않고 환경점검(env_check.sh)으로 넘어간다.
#
#  옵션: --root <폴더>  --no-open  --skip-envcheck
# ============================================================

set -u
ROOT="$HOME/AgentOffice"
NO_OPEN=0
SKIP_ENV=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        --no-open) NO_OPEN=1; shift ;;
        --skip-envcheck) SKIP_ENV=1; shift ;;
        *) shift ;;
    esac
done

M=$'\033[35m'; G=$'\033[32m'; R=$'\033[31m'; D=$'\033[90m'; Y=$'\033[33m'; N=$'\033[0m'
step() { printf '\n  %s▶ %s%s\n' "$M" "$1" "$N"; }
info() { printf '     %s%s%s\n' "$D" "$1" "$N"; }
stop_msg() { printf '\n  %s❌ %s%s\n\n' "$R" "$1" "$N"; exit 1; }

SRC_KIT="$(cd "$(dirname "$0")" && pwd)"
TARGET_KIT="$ROOT/01_KIT/starter-kit"
MARKER="$TARGET_KIT/환경점검.command"
LOGFILE="$ROOT/설치결과.txt"

printf '\n  %sgplatform AI 에이전트팀 (직장인판) — 폴더 생성 및 설치 (맥)%s\n' "$M" "$N"
info "설치 위치: $ROOT"

[ -f "$SRC_KIT/env_check.sh" ] || stop_msg '스타터킷이 완전히 풀리지 않았습니다. ZIP 을 더블클릭해 모두 푼 다음 다시 실행하세요.'

step '표준 폴더 만들기'
FOLDERS="00_README 01_KIT 04_LEARNER_BACKUP 05_EXPORT/html 05_EXPORT/pdf 90_TEMP MyData/Report MyData/Minutes MyData/Track MyData/Skill"
for rel in $FOLDERS; do
    mkdir -p "$ROOT/$rel" 2>/dev/null || stop_msg "$ROOT 에 폴더를 만들 수 없습니다. 권한을 확인하세요."
done
info "$(echo $FOLDERS | wc -w | tr -d ' ')개 표준 폴더 확인"

GUIDE="$ROOT/MyData/여기에_넣으세요.txt"
if [ ! -f "$GUIDE" ]; then
cat > "$GUIDE" <<'EOF'
내 양식 폴더 — 수업 전에 미리 넣어 두세요 (비식별 사본만)

  Report/    보고서 — 내가 쓴 주간보고·업무보고 3개 (docx·pptx·pdf·hwp·txt)
  Minutes/   회의록 — 내가 정리한 회의록 3개
  Track/     직무 문서 — (선택) 제안서·블로그 글·안내문·기획서·비용표 중 3개
  Skill/     내 스킬 — (선택) 이미 쓰던 스킬 문서(SKILL.md). 있으면 이것이 우선입니다

[중요] 회사 원본을 그대로 넣지 마세요. 사본을 만들어 회사 이름·사람 이름·고객사·금액을
○○ 로 지운 뒤 넣습니다. 구성과 말투만 남아 있으면 충분합니다.
회사 규정상 사본도 가져올 수 없으면 빈 양식(제목과 항목 이름만)을 손으로 적어 넣으세요.

폴더 이름이 영문인 이유: 프로그램이 한글 경로에서 드물게 막히는 일을 없애기 위해서입니다.
직원(AI)은 이 폴더를 읽기만 하고 원본을 고치지 않습니다.
없는 것은 비워 두어도 수업은 진행됩니다. 부록 A(내 양식)를 할 때 채우면 됩니다.

[Skill 폴더] 클로드를 이미 써 오셨다면, 쓰시던 SKILL.md 를 여기에 넣어 주세요.
같은 일을 하는 스킬이 수업에도 있으면 쓰시던 것이 정본이 되고,
수업에서 만든 것은 보관 폴더로 물러납니다. 처음이시면 비워 두세요.
EOF
fi
info "MyData 안내문: $GUIDE"

step '가벼운 스타터킷 설치'
EXISTED=0
if [ -f "$MARKER" ]; then
    EXISTED=1
    printf '\n  %s⚠ 이미 설치돼 있습니다 — 내 직원·스킬·슬랙 열쇠를 지키려고 그대로 두고 이어서 진행합니다.%s\n' "$Y" "$N"
    info "$TARGET_KIT"
else
    mkdir -p "$TARGET_KIT"
    # rsync 는 맥 기본 도구다. 비밀키·로그인 상태·실행 기록은 옮기지 않는다.
    rsync -a \
        --exclude '__pycache__/' --exclude 'logs/' --exclude 'backup/' \
        --exclude '.naver-profile/' --exclude '.image-flow-profile/' --exclude 'node_modules/' \
        --exclude '.env' --exclude '.agent_session.json' --exclude '.naver-state.json' \
        --exclude '환경점검_결과.html' --exclude '*.pyc' --exclude '*.log' --exclude '*.bak*' \
        "$SRC_KIT/" "$TARGET_KIT/" || stop_msg '스타터킷 복사에 실패했습니다.'
    [ -f "$MARKER" ] || stop_msg '복사가 끝났지만 환경점검.command 를 찾지 못했습니다. 원본 ZIP 을 다시 받으세요.'

    # ZIP 은 빈 폴더를 담지 못한다 — 직원·스킬·inbox·memory 자리는 여기서 다시 판다
    for d in .claude/agents .claude/skills workspace/inbox workspace/memory workspace/결과물 workspace/기록 workspace/받은파일 slack-server/logs; do
        mkdir -p "$TARGET_KIT/$d"
    done
    # 더블클릭 파일은 실행 권한이 있어야 열린다. 압축을 푸는 방법에 따라 빠질 수 있어 여기서 다시 준다.
    chmod +x "$TARGET_KIT"/*.command "$TARGET_KIT"/*.sh "$TARGET_KIT"/slack-server/*.sh "$TARGET_KIT"/저녁블로그/*.command \
             "$TARGET_KIT"/저녁블로그/*.sh "$TARGET_KIT"/naver-calendar/*.sh 2>/dev/null
    # 브라우저로 받은 ZIP 이면 「확인되지 않은 개발자」 경고가 뜬다 — 이 킷 안의 표식만 지운다.
    xattr -dr com.apple.quarantine "$TARGET_KIT" 2>/dev/null

    COUNT=$(find "$TARGET_KIT" -type f | wc -l | tr -d ' ')
    SIZE=$(du -sh "$TARGET_KIT" | cut -f1)
    printf '  %s✅ 스타터킷 복사 성공%s\n' "$G" "$N"
    info "${COUNT}개 파일 / $SIZE"
fi

if [ -f "$TARGET_KIT/README.md" ] && [ ! -f "$ROOT/00_README/스타터킷_README.md" ]; then
    cp "$TARGET_KIT/README.md" "$ROOT/00_README/스타터킷_README.md"
fi

{
    echo "설치일시=$(date '+%Y-%m-%d %H:%M:%S')"
    echo "원본=$SRC_KIT"
    echo "설치위치=$TARGET_KIT"
    echo "제외=node_modules, logs, .env, login profiles"
    echo "다음단계=01_KIT/starter-kit/환경점검.command"
} > "$LOGFILE"

step '설치 결과'
if [ $EXISTED -eq 1 ]; then
    printf '  %s✅ 이미 설치된 스타터킷을 그대로 씁니다%s\n' "$G" "$N"
else
    printf '  %s✅ 표준 폴더와 스타터킷 준비됨%s\n' "$G" "$N"
fi
info "스타터킷: $TARGET_KIT"
info "기록: $LOGFILE"
info "내 양식(선택): $ROOT/MyData — Report·Minutes 에 보고서 3·회의록 3 (이름·숫자를 지운 사본)"
info "쓰던 스킬이 있으면: $ROOT/MyData/Skill 에 SKILL.md 를 넣으면 그것이 우선 적용됩니다"

[ $NO_OPEN -eq 1 ] || open "$ROOT" 2>/dev/null

if [ $SKIP_ENV -eq 0 ]; then
    step '이어서 환경점검·자동 설치를 시작합니다 (묻지 않습니다)'
    /bin/bash "$TARGET_KIT/env_check.sh" --skip-slack
fi

printf '\n  %s이 창은 닫아도 됩니다.%s\n' "$D" "$N"
