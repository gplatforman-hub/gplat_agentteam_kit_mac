#!/bin/bash
# ============================================================
#  gplatform AI 에이전트팀 (직장인판) 스타터킷 — 맥용 한 줄 설치 (bootstrap)
#
#  수강생은 「터미널」 앱을 열고 아래 한 줄만 붙여넣습니다 (⌘V → return).
#    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/gplatforman-hub/gplat_agentteam_kit_mac/main/install.sh)"
#
#  「curl … | bash」 가 아니라 「bash -c "$(curl …)"」 인 이유:
#    파이프로 넘기면 키보드 입력 자리를 다운로드가 차지해서, 로그인·열쇠 입력을 받을 수 없다.
#
#  하는 일
#    1) 깃허브에서 스타터킷(node_modules·비밀키 없음)을 받는다
#    2) ~/AgentOffice/01_KIT/starter-kit 에 표준 설치한다 (install_starterkit.sh)
#       — 같이 만들어지는 ~/AgentOffice/MyData/ 에 수강생이 보고서·회의록 양식(비식별 사본)을 미리 넣는다 (선택)
#    3) 환경점검(env_check.sh)을 이어서 돌린다 — Git·Node·Claude Code 는 없으면 설치,
#       Python 은 3.14 를 관리자 비밀번호 없이 따로 설치, 꾸러미 설치·확인
#
#  테스트·강사용 환경변수 (선택)
#    WD_KIT_ZIP=/path/kit.zip        깃허브 대신 로컬 ZIP 사용
#    WD_INSTALL_ROOT=~/Agent         설치 위치 변경
#    WD_NO_ENVCHECK=1                환경점검 생략
#
#  맥 기본 bash 3.2 에서 돌도록 썼다 (연관 배열·${v,,} 같은 새 문법을 쓰지 않는다).
# ============================================================

set -u

REPO="gplatforman-hub/gplat_agentteam_kit_mac"
BRANCH="main"
ZIP_URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.zip"

ROOT="${WD_INSTALL_ROOT:-$HOME/AgentOffice}"
case "$ROOT" in "~"*) ROOT="$HOME${ROOT#\~}" ;; esac
KIT="$ROOT/01_KIT/starter-kit"

M=$'\033[35m'; G=$'\033[32m'; R=$'\033[31m'; D=$'\033[90m'; Y=$'\033[33m'; N=$'\033[0m'
step() { printf '\n  %s▶ %s%s\n' "$M" "$1" "$N"; }
info() { printf '     %s%s%s\n' "$D" "$1" "$N"; }
fail() { printf '\n  %s❌ %s%s\n\n' "$R" "$1" "$N"; exit 1; }

if [ "$(uname -s)" != "Darwin" ]; then
    fail "이 설치 파일은 맥 전용입니다. 윈도우는 파워셸 한 줄 설치(install.ps1)를 쓰세요."
fi

STARTED=$(date +%s)
printf '\n  %sgplatform AI 에이전트팀 (직장인판) — 스타터킷 한 줄 설치 (맥)%s\n' "$M" "$N"
info "설치 위치: $KIT"

# ── 1. 작업 폴더 ─────────────────────────────────────────────
step '작업 폴더 준비'
STAMP=$(date +%Y%m%d-%H%M%S)
TMP="$ROOT/90_TEMP/bootstrap-$STAMP"
mkdir -p "$TMP" 2>/dev/null || fail "$ROOT 에 폴더를 만들 수 없습니다. 권한을 확인하세요."
info "$TMP"

# ── 2. 스타터킷 받기 ─────────────────────────────────────────
step '스타터킷 받기'
ZIP="$TMP/kit.zip"
if [ -n "${WD_KIT_ZIP:-}" ]; then
    [ -f "$WD_KIT_ZIP" ] || fail "WD_KIT_ZIP 파일이 없습니다: $WD_KIT_ZIP"
    cp "$WD_KIT_ZIP" "$ZIP"
    info "로컬 ZIP 사용: $WD_KIT_ZIP"
else
    info "$ZIP_URL"
    curl -fL --retry 2 --connect-timeout 15 -o "$ZIP" "$ZIP_URL" 2>/dev/null \
        || fail "다운로드에 실패했습니다. 인터넷 연결 또는 회사 방화벽(github.com)을 확인하세요."
fi
info "받은 크기: $(du -h "$ZIP" | cut -f1)"

# ── 3. 압축 풀기 ─────────────────────────────────────────────
step '압축 풀기'
EXT="$TMP/x"
mkdir -p "$EXT"
# ditto 는 맥 기본 도구다. 한글 파일 이름(NFD/NFC)을 Finder 와 같은 방식으로 푼다.
ditto -x -k "$ZIP" "$EXT" 2>/dev/null || unzip -q "$ZIP" -d "$EXT" \
    || fail "압축을 풀지 못했습니다. 파일이 손상됐을 수 있습니다. 다시 실행해 보세요."
INSTALLER=$(find "$EXT" -name install_starterkit.sh -type f | head -n 1)
[ -n "$INSTALLER" ] || fail "받은 파일 안에 install_starterkit.sh 가 없습니다. 원본이 바뀌었는지 강사에게 알려주세요."
SRC_KIT=$(dirname "$INSTALLER")
info "스타터킷 파일 $(find "$SRC_KIT" -type f | wc -l | tr -d ' ') 개 확인"

# ── 4. 표준 위치에 설치 ─────────────────────────────────────
step "$ROOT 표준 폴더 만들고 스타터킷 설치"
/bin/bash "$INSTALLER" --root "$ROOT" --no-open --skip-envcheck || fail "설치 스크립트가 실패했습니다."
[ -f "$KIT/환경점검.command" ] || fail "설치 후 $KIT 에 환경점검.command 가 없습니다."
info "설치된 파일 $(find "$KIT" -type f | wc -l | tr -d ' ') 개"

# ── 5. 정리 ──────────────────────────────────────────────────
rm -rf "$TMP" 2>/dev/null

ELAPSED=$(( $(date +%s) - STARTED ))
printf '\n  %s✅ 스타터킷 설치 완료 (%s 초)%s\n' "$G" "$ELAPSED" "$N"
info "위치: $KIT"
info "다음: 환경점검이 자동으로 이어집니다 → 끝나면 Claude 앱을 완전히 종료(⌘Q)했다 켜고 Code 탭에서 이 폴더를 엽니다"
info "내 양식(선택): $ROOT/MyData 의 Report·Minutes 에 보고서 3·회의록 3 (이름·숫자를 지운 사본)"

# ── 6. 환경점검 이어서 ───────────────────────────────────────
if [ -n "${WD_NO_ENVCHECK:-}" ]; then
    info '환경점검은 건너뜁니다 (WD_NO_ENVCHECK).'
else
    # 설치 중에는 슬랙 열쇠·메일을 묻지 않는다. 열쇠는 슬랙열쇠_넣기.command 로 따로 넣는다. (윈도우판 2026-11-02 과 같음)
    step '환경점검 시작 — 프로그램·파이썬 3.14·꾸러미를 묻지 않고 설치합니다. 사람이 할 일은 창이 뜨면 「설치」·로그인을 누르는 것뿐'
    info '설치가 도는 동안 브라우저에서 교안 「슬랙 ①②」(앱 만들기·열쇠 받기)를 진행하세요.'
    /bin/bash "$KIT/env_check.sh" --skip-slack
    printf '\n'
    info "다음: 슬랙 열쇠를 받았으면 Finder 에서 $KIT/슬랙열쇠_넣기.command 를 더블클릭합니다"
fi

printf '\n  %s이 창은 닫아도 됩니다.%s\n' "$D" "$N"
