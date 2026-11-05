#!/bin/bash
# ============================================================
#  env_check.sh — 「에이전트팀 만들기 과정」 출발선 자동 점검 + 자동 설치 (맥)
#  윈도우판 env_check.ps1 과 같은 순서·같은 항목. 다른 점만 적는다.
#
#  무엇을 하나 ("묻지 않고 설치한다")
#    1) Git — 맥은 「Xcode 명령어 도구」 에 들어 있다. 없으면 설치 창을 띄운다 (사람은 「설치」 만 누름)
#    2) Node.js 22 — 공식 배포 파일을 ~/.local/node22 에 푼다 (관리자 비밀번호 필요 없음)
#    3) Claude Code — 공식 설치 스크립트 (claude.ai/install.sh, ~/.local/bin/claude)
#    4) Python 3.14 — uv 로 ~/AgentOffice/.venv 에 따로 설치한다 (관리자 비밀번호 필요 없음,
#       맥에 원래 있는 python3 은 건드리지 않음). ~/.local/bin/py 를 만들어
#       윈도우와 같은 명령(py -3 …)이 맥에서도 그대로 돈다 — 교안·카드·안전장치가 전부 py -3 를 쓴다.
#    5) 파이썬 꾸러미 설치·확인, Claude Code 로그인
#    6) 슬랙 열쇠 3개 + 내 이름 → slack-server/.env, 실제 연결 시험, 서버 첫 기동, 로그인 자동 실행 등록
#    7) 결과 체크리스트를 터미널과 HTML(환경점검_결과.html)로 보여준다
#
#  실행:  환경점검.command 더블클릭  ← 이게 전부입니다
#  옵션 (강사·테스트용)
#    --skip-install  --skip-login  --skip-slack  --no-server-test  --no-browser  --no-pause  --yes
#    --slack-only (슬랙열쇠_넣기.command)   --mail-only (메일_연결.command)   --mail
#    --pretend node,git,claude-login   테스트용 — 그 항목을 "없는 것"으로 가정
#
#  🔒 .env 의 열쇠 값을 화면에 찍지 않습니다. 붙여넣을 때도 화면에 보이지 않습니다.
#  🔒 로그인은 항상 사람이 직접 합니다. 비밀번호를 대신 입력하지 않습니다.
#  맥 기본 bash 3.2 에서 돌도록 썼다.
# ============================================================

set -u

SKIP_INSTALL=0; SKIP_LOGIN=0; SKIP_SLACK=0; NO_SERVER_TEST=0; NO_BROWSER=0; NO_PAUSE=0; YES=0
SLACK_ONLY=0; MAIL_ONLY=0; MAIL=0; PRETEND=""
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-install) SKIP_INSTALL=1 ;;
        --skip-login) SKIP_LOGIN=1 ;;
        --skip-slack) SKIP_SLACK=1 ;;
        --no-server-test) NO_SERVER_TEST=1 ;;
        --no-browser) NO_BROWSER=1 ;;
        --no-pause) NO_PAUSE=1 ;;
        --yes) YES=1 ;;
        --slack-only) SLACK_ONLY=1 ;;
        --mail-only) MAIL_ONLY=1 ;;
        --mail) MAIL=1 ;;
        --pretend) PRETEND=",$2,"; shift ;;
    esac
    shift
done

KIT="$(cd "$(dirname "$0")" && pwd)"
COURSE="$(dirname "$KIT")"
if [ "$(basename "$COURSE")" = "01_KIT" ]; then ROOT="$(dirname "$COURSE")"; else ROOT="$HOME/AgentOffice"; fi
VENV="$ROOT/.venv"
PYEXE="$VENV/bin/python"
LOCALBIN="$HOME/.local/bin"
REPORT="$KIT/환경점검_결과.html"
STARTED=$(date +%s)
export PATH="$LOCALBIN:$HOME/.local/node22/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

M=$'\033[35m'; G=$'\033[32m'; R=$'\033[31m'; D=$'\033[90m'; Y=$'\033[33m'; C=$'\033[36m'; W=$'\033[1m'; N=$'\033[0m'
OKM='✅'; NOM='❌'; WRN='⚠'

# ── 1. 도우미 ────────────────────────────────────────────────
step() { printf '\n  %s▶ %s%s\n' "$M" "$1" "$N"; }
info() { printf '     %s%s%s\n' "$D" "$1" "$N"; }
warn() { printf '     %s%s %s%s\n' "$Y" "$WRN" "$1" "$N"; }
has() { command -v "$1" >/dev/null 2>&1; }
first_line() { printf '%s' "$1" | head -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
trim_q() { printf '%s' "$1" | sed "s/^[[:space:]\"']*//;s/[[:space:]\"']*\$//"; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

ask() {   # ask "질문" → 답을 REPLY 에. 키보드(/dev/tty)에서 읽는다
    REPLY=""
    printf '  ? %s ' "$1"
    IFS= read -r REPLY </dev/tty || REPLY=""
}
ask_secret() {   # 화면에 보이지 않게 받는다
    REPLY=""
    printf '  ? %s ' "$1"
    IFS= read -r -s REPLY </dev/tty || REPLY=""
    printf '\n'
}
ask_yesno() {   # ask_yesno "질문" 기본(1=예,0=아니오)
    [ $YES -eq 1 ] && return 0
    local hint='[y/N]'; [ "$2" = "1" ] && hint='[Y/n]'
    ask "$1 $hint"
    if [ -z "$REPLY" ]; then [ "$2" = "1" ]; return $?; fi
    case "$(lower "$REPLY")" in y*) return 0 ;; *) return 1 ;; esac
}
ver_ge() {   # ver_ge 2.1.50 2.1.46 → 참이면 0
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)" = "$2" ]
}
open_url() { if [ $NO_BROWSER -eq 1 ]; then info "(브라우저 생략) $1"; else open "$1" 2>/dev/null || warn "열 수 없음: $1"; fi; }
run_to() {   # run_to 초 명령… → 출력은 OUT, 종료코드 반환 (멈추면 시간 초과로 끊는다)
    local secs=$1; shift
    local tmp; tmp=$(mktemp -t wdenv)
    ( "$@" >"$tmp" 2>&1 ) & local pid=$!
    local i=0
    while kill -0 $pid 2>/dev/null; do
        sleep 1; i=$((i+1))
        if [ $i -ge $secs ]; then kill $pid 2>/dev/null; OUT="(시간 초과)"; rm -f "$tmp"; return 124; fi
    done
    wait $pid; local code=$?
    OUT=$(cat "$tmp"); rm -f "$tmp"
    return $code
}

# ── 2. 결과 저장소 (bash 3.2 — 같은 순서의 배열 여러 개) ───────
R_ID=(); R_NAME=(); R_GROUP=(); R_OK=(); R_DETAIL=(); R_FIX=(); R_URL=()
set_result() {   # set_result id 이름 그룹 ok(1/0) 설명 [고치기] [주소]
    local id="$1" name="$2" group="$3" ok="$4" detail="$5" fix="${6:-}" url="${7:-}"
    case "$PRETEND" in *",$id,"*) ok=0; detail="(테스트) 없는 것으로 가정 — $detail" ;; esac
    local i k=-1
    for i in "${!R_ID[@]}"; do [ "${R_ID[$i]}" = "$id" ] && k=$i; done
    [ $k -lt 0 ] && k=${#R_ID[@]}
    R_ID[$k]="$id"; R_NAME[$k]="$name"; R_GROUP[$k]="$group"; R_OK[$k]="$ok"; R_DETAIL[$k]="$detail"; R_FIX[$k]="$fix"; R_URL[$k]="$url"
    local mark="$NOM" color="$R"
    [ "$group" = "선택" ] && { mark="$WRN"; color="$Y"; }
    [ "$ok" = "1" ] && { mark="$OKM"; color="$G"; }
    printf '  %s%s  %s%s\n' "$color" "$mark" "$name" "$N"
    [ -n "$detail" ] && printf '        %s└ %s%s\n' "$D" "$detail" "$N"
    return 0
}
is_ok() { local i; for i in "${!R_ID[@]}"; do [ "${R_ID[$i]}" = "$1" ] && [ "${R_OK[$i]}" = "1" ] && return 0; done; return 1; }
detail_of() { local i; for i in "${!R_ID[@]}"; do [ "${R_ID[$i]}" = "$1" ] && { printf '%s' "${R_DETAIL[$i]}"; return; }; done; }

# ── 3. 개별 검사 ─────────────────────────────────────────────
check_internet() {
    local h
    for h in claude.ai nodejs.org www.google.com; do
        if curl -s -o /dev/null --max-time 5 "https://$h"; then set_result internet '인터넷 연결' '기본' 1 "$h 연결됨"; return; fi
    done
    set_result internet '인터넷 연결' '기본' 0 'Wi-Fi 를 확인하세요 — 설치와 로그인 모두 인터넷이 필요합니다'
}

check_disk() {
    local gb; gb=$(df -g "$KIT" 2>/dev/null | awk 'NR==2{print $4}')
    if [ -z "$gb" ]; then set_result disk '디스크 여유 3GB 이상' '기본' 1 '확인 불가 — 건너뜁니다'; return; fi
    local ok=0; [ "$gb" -ge 3 ] && ok=1
    set_result disk '디스크 여유 3GB 이상' '기본' $ok "여유 ${gb}GB (설치 약 1.5GB)"
}

check_macos() {
    local v; v=$(sw_vers -productVersion 2>/dev/null)
    local major=${v%%.*}; local ok=0
    [ -n "$major" ] && [ "$major" -ge 13 ] && ok=1
    local d="macOS $v ($(uname -m))"; [ $ok -eq 0 ] && d="$d → macOS 13(벤투라) 이상이 필요합니다"
    set_result macos 'macOS 13 이상' '기본' $ok "$d"
}

check_git() {
    # /usr/bin/git 은 도구가 없어도 「있는 척」 하는 껍데기다. 명령어 도구 폴더가 있는지부터 본다.
    if ! xcode-select -p >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/git ] && [ ! -x /usr/local/bin/git ]; then
        set_result git 'Git (Xcode 명령어 도구)' '필수' 0 '설치 안 됨' 'xcode-select --install'
        return
    fi
    local out; out=$(git --version 2>/dev/null)
    if printf '%s' "$out" | grep -q 'git version'; then set_result git 'Git (Xcode 명령어 도구)' '필수' 1 "$out"
    else set_result git 'Git (Xcode 명령어 도구)' '필수' 0 '설치 안 됨' 'xcode-select --install'; fi
}

check_node() {
    if ! has node; then set_result node 'Node.js 22 이상' '필수' 0 '설치 안 됨' '환경점검을 다시 실행' 'https://nodejs.org/ko/download'; return; fi
    local out; out=$(node -v 2>/dev/null); local maj; maj=$(printf '%s' "$out" | sed -E 's/^v([0-9]+).*/\1/')
    local ok=0; [ -n "$maj" ] && [ "$maj" -ge 22 ] 2>/dev/null && ok=1
    local d="$out"; [ $ok -eq 0 ] && d="$out → 22 이상 필요 (환경점검이 ~/.local/node22 에 새로 깝니다)"
    set_result node 'Node.js 22 이상' '필수' $ok "$d" '환경점검을 다시 실행' 'https://nodejs.org/ko/download'
}

check_npm() {
    local out; out=$(npm -v 2>/dev/null)
    if [ -n "$out" ]; then set_result npm 'npm (Claude Code 예비 설치용)' '필수' 1 "npm $out"
    else set_result npm 'npm (Claude Code 예비 설치용)' '필수' 0 'Node.js 를 깔면 같이 들어옵니다'; fi
}

check_python() {
    # 수업 표준은 Python 3.14. 맥에 원래 있는 python3(3.9 등)은 쓰지 않고, ~/AgentOffice/.venv 의 3.14 만 쓴다.
    if [ -x "$PYEXE" ] && "$PYEXE" -V 2>&1 | grep -q 'Python 3\.14'; then
        set_result python 'Python 3.14 (수업 표준)' '필수' 1 "$("$PYEXE" -V 2>&1) ($VENV)"
        return
    fi
    local d='설치 안 됨'
    if [ -x "$PYEXE" ]; then d="$("$PYEXE" -V 2>&1) → 3.14 로 새로 만듭니다"
    elif has python3; then d="$(python3 -V 2>&1) 만 있음 (맥 기본) → 수업용 3.14 를 따로 깝니다"; fi
    set_result python 'Python 3.14 (수업 표준)' '필수' 0 "$d" '환경점검을 다시 실행'
}

check_pip() {
    if ! is_ok python; then set_result pip 'pip (파이썬 꾸러미 설치 도구)' '필수' 0 'Python 먼저'; return; fi
    local out; out=$("$PYEXE" -m pip --version 2>/dev/null)
    if [ -n "$out" ]; then set_result pip 'pip (파이썬 꾸러미 설치 도구)' '필수' 1 "$(first_line "$out" | cut -c1-60)"
    else set_result pip 'pip (파이썬 꾸러미 설치 도구)' '필수' 0 'pip 이 없습니다 → 환경점검을 다시 실행'; fi
}

check_pylauncher() {
    # 윈도우의 py 실행기 자리. 안전장치(hooks)·카드·교안이 전부 「py -3 …」 로 부른다.
    local w="$LOCALBIN/py"
    if [ -x "$w" ] && "$w" -3 -V 2>&1 | grep -q 'Python 3\.14'; then
        set_result pylauncher 'py 명령 (윈도우와 같은 py -3 → 3.14)' '필수' 1 "$w"
    else
        set_result pylauncher 'py 명령 (윈도우와 같은 py -3 → 3.14)' '필수' 0 '아직 없음 → 환경점검을 다시 실행'
    fi
}

claude_path() {
    local c
    for c in "$(command -v claude 2>/dev/null)" "$LOCALBIN/claude" "$HOME/.claude/local/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.local/node22/bin/claude"; do
        [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    done
    return 1
}

check_claude() {
    local exe; exe=$(claude_path)
    if [ -n "$exe" ]; then
        run_to 40 "$exe" --version; local d; d=$(first_line "$OUT"); [ -z "$d" ] && d="$exe"
        set_result claude 'Claude Code 설치' '필수' 1 "$d"
    else
        set_result claude 'Claude Code 설치' '필수' 0 '설치 안 됨' 'curl -fsSL https://claude.ai/install.sh | bash' 'https://code.claude.com/docs/en/setup'
    fi
}

check_claude_version() {
    # claude.ai 커넥터(구글 캘린더·지메일·드라이브)가 터미널에 도구로 넘어오는 것은 2.1.46 판부터다.
    if ! is_ok claude; then set_result claude-ver 'Claude Code 최신판 (구글 커넥터 지원, 2.1.46 이상)' '필수' 0 'Claude Code 먼저 설치'; return; fi
    run_to 40 "$(claude_path)" --version
    local v; v=$(printf '%s' "$OUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    if [ -z "$v" ]; then set_result claude-ver 'Claude Code 최신판 (구글 커넥터 지원, 2.1.46 이상)' '필수' 0 "판을 읽지 못함: $(first_line "$OUT")" 'claude update'; return; fi
    if ver_ge "$v" 2.1.46; then set_result claude-ver 'Claude Code 최신판 (구글 커넥터 지원, 2.1.46 이상)' '필수' 1 "v$v"
    else set_result claude-ver 'Claude Code 최신판 (구글 커넥터 지원, 2.1.46 이상)' '필수' 0 "v$v — 2.1.46 이상이어야 구글 커넥터가 붙습니다" 'claude update'; fi
}

claude_logged_in() {
    is_ok claude || return 1
    run_to 40 "$(claude_path)" auth status
    printf '%s' "$OUT" | grep -qE '"loggedIn"[[:space:]]*:[[:space:]]*true'
}

check_claude_login() {
    if ! is_ok claude; then set_result claude-login 'Claude Code 로그인 (claude.ai 유료 계정)' '필수' 0 'Claude Code 먼저 설치' '' 'https://claude.ai/'; return; fi
    if claude_logged_in; then
        local d='로그인됨'
        local sub; sub=$(printf '%s' "$OUT" | grep -oE '"subscriptionType"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')
        [ -n "$sub" ] && d="로그인됨 ($sub)"
        set_result claude-login 'Claude Code 로그인 (claude.ai 유료 계정)' '필수' 1 "$d"
    else
        set_result claude-login 'Claude Code 로그인 (claude.ai 유료 계정)' '필수' 0 '로그인 안 됨' 'claude auth login' 'https://claude.ai/'
    fi
}

check_pypackages() {
    local nm='파이썬 꾸러미 5개 (slack-bolt·slack-sdk·aiohttp·python-dotenv·claude-agent-sdk)'
    if ! is_ok python; then set_result pypkg "$nm" '필수' 0 'Python 먼저'; set_result playwright 'playwright 패키지 (블로그·이미지 스킬용)' '선택' 0 'Python 먼저'; return; fi
    local out
    out=$("$PYEXE" - <<'EOF' 2>/dev/null
import importlib.util as u
mods = ["slack_bolt","slack_sdk","aiohttp","dotenv","claude_agent_sdk","playwright"]
print(" ".join(m + "=" + ("O" if u.find_spec(m) else "X") for m in mods))
EOF
)
    if [ -z "$out" ]; then set_result pypkg "$nm" '필수' 0 '확인 실패'; set_result playwright 'playwright 패키지 (블로그·이미지 스킬용)' '선택' 0 '확인 실패'; return; fi
    local missing="" m
    for m in slack_bolt slack_sdk aiohttp dotenv claude_agent_sdk; do
        printf '%s' "$out" | grep -q "$m=O" || missing="$missing $m"
    done
    if [ -z "$missing" ]; then set_result pypkg "$nm" '필수' 1 '5개 모두 설치됨'
    else set_result pypkg "$nm" '필수' 0 "빠짐:$missing" 'py -3 -m pip install -r slack-server/requirements.txt'; fi
    if printf '%s' "$out" | grep -q 'playwright=O'; then set_result playwright 'playwright 패키지 (블로그·이미지 스킬용)' '선택' 1 '설치됨'
    else set_result playwright 'playwright 패키지 (블로그·이미지 스킬용)' '선택' 0 'pip install playwright' 'py -3 -m pip install playwright'; fi
}

check_folders() {
    local d
    for d in .claude/agents .claude/skills workspace/inbox workspace/memory workspace/결과물; do mkdir -p "$KIT/$d" 2>/dev/null; done
    local missing=""
    for d in .claude/agents .claude/skills workspace/inbox workspace/memory slack-server/server.py 점검.py; do
        [ -e "$KIT/$d" ] || missing="$missing $d"
    done
    if [ -z "$missing" ]; then set_result folders '스타터킷 폴더 구조' '필수' 1 "정상 — $KIT"
    else set_result folders '스타터킷 폴더 구조' '필수' 0 "없음:$missing — 스타터킷을 다시 설치하세요"; fi
}

count_files() { find "$1" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' '; }
check_mydata() {
    local base="$ROOT/MyData"
    if [ "$(basename "$COURSE")" != "01_KIT" ] || [ ! -d "$base" ]; then
        set_result mydata '내 양식 (보고서 3·회의록 3, 비식별)' '선택' 0 'MyData 폴더 없음 — 표준 설치가 아니면 건너뜁니다'; return
    fi
    local r m t s; r=$(count_files "$base/Report"); m=$(count_files "$base/Minutes"); t=$(count_files "$base/Track"); s=$(count_files "$base/Skill")
    local ok=0; [ "$r" -ge 3 ] && [ "$m" -ge 3 ] && ok=1
    local d="보고서(Report) ${r}개 · 회의록(Minutes) ${m}개 · 직무 문서(Track) ${t}개 · 내 스킬(Skill) ${s}개 — $base"
    [ "$s" -gt 0 ] && d="$d / 쓰던 스킬이 있으니 부록 카드 A-3 을 A-4 보다 먼저 돌리세요"
    set_result mydata '내 양식 (보고서 3·회의록 3, 비식별)' '선택' $ok "$d" "$base 에 비식별 사본을 넣으세요 (선택 · 부록 A)"
}

env_get() {   # env_get 파일 키 → 값 (앞뒤 공백 유지 — 검사에 쓴다)
    [ -f "$1" ] || return 1
    LC_ALL=C sed $'1s/^\xEF\xBB\xBF//' "$1" | grep -E "^[[:space:]]*$2[[:space:]]*=" | tail -n 1 | sed -E "s/^[[:space:]]*$2[[:space:]]*=//"
}

check_slack_env() {
    # 🔒 값은 화면에 찍지 않는다. 키 이름과 앞머리(xoxb-/xapp-)만 본다.
    local envf="$KIT/slack-server/.env"
    local nm='슬랙 열쇠 3개 (.env — 봇·앱·멤버 ID)'
    local fix='교안 슬랙 ①② 쪽대로 열쇠를 받아 두고 슬랙열쇠_넣기.command 를 실행해 붙여넣습니다'
    if [ ! -f "$envf" ]; then
        local stray; stray=$(ls -a "$KIT/slack-server" 2>/dev/null | grep -E '^\.env\..+' | grep -v '^\.env\.example$' | head -n 1)
        local d='.env 파일이 아직 없습니다'; [ -n "$stray" ] && d=".env 대신 $stray 로 저장돼 있습니다 — 이름을 .env 로 바꾸세요"
        set_result slack "$nm" '필수' 0 "$d" "$fix" 'https://api.slack.com/apps'; return
    fi
    local problems="" key head raw v other
    for pair in SLACK_BOT_TOKEN:xoxb- SLACK_APP_TOKEN:xapp-; do
        key=${pair%%:*}; head=${pair#*:}
        raw=$(env_get "$envf" "$key"); v=$(printf '%s' "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$v" ]; then problems="$problems / $key 비어 있음"; continue; fi
        case "$v" in \"*|\'*|*\"|*\') problems="$problems / $key 따옴표 지우세요"; continue ;; esac
        [ "$raw" != "$v" ] && { problems="$problems / $key 앞뒤 공백 지우세요"; continue; }
        case "$v" in
            "$head"*) ;;
            *) other='xoxb-'; [ "$head" = 'xoxb-' ] && other='xapp-'
               case "$v" in "$other"*) problems="$problems / $key 자리에 $other 가 들어갔습니다 (둘이 바뀜)" ;; *) problems="$problems / $key 는 $head 로 시작해야 합니다" ;; esac ;;
        esac
    done
    local own; own=$(trim_q "$(env_get "$envf" OWNER_USER_ID)")
    if [ -z "$own" ]; then problems="$problems / OWNER_USER_ID(내 멤버 ID) 비어 있음"
    elif ! printf '%s' "$own" | grep -qE '^[UW][A-Z0-9]{8,}$'; then problems="$problems / OWNER_USER_ID 는 U 로 시작하는 멤버 ID 여야 합니다"; fi
    if [ -z "$problems" ]; then set_result slack "$nm" '필수' 1 '열쇠 3개 모양 정상 (값은 확인하지 않습니다)' "$fix" 'https://api.slack.com/apps'
    else set_result slack "$nm" '필수' 0 "${problems# / }" "$fix" 'https://api.slack.com/apps'; fi
}

check_vscode() {
    if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ] || has code; then
        set_result vscode 'VS Code' '선택' 1 '설치됨'
    else set_result vscode 'VS Code' '선택' 0 '없어도 실습됩니다' 'code.visualstudio.com' 'https://code.visualstudio.com/'; fi
}

check_chrome() {
    if [ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ]; then
        set_result chrome 'Google Chrome (네이버 블로그 임시저장용)' '선택' 1 '설치됨'
    else set_result chrome 'Google Chrome (네이버 블로그 임시저장용)' '선택' 0 '네이버 블로그 임시저장이 실제 Chrome 을 씁니다' 'google.com/chrome' 'https://www.google.com/chrome/'; fi
}

check_naver_login() {
    if [ -f "$KIT/naver-blog/.naver-state.json" ]; then set_result naver-login '네이버 블로그 로그인 (블로그 스킬)' '선택' 1 '세션 파일 있음 (.naver-state.json)'
    else set_result naver-login '네이버 블로그 로그인 (블로그 스킬)' '선택' 0 '아직 로그인 안 함' 'py -3 naver-blog/naver_draft.py login --blog-id 내아이디' 'https://blog.naver.com/'; fi
}

check_sleep() {
    # 맥이 잠들면 슬랙 서버도 멈춘다. 자동 실행은 caffeinate 로 「전원 연결 중에는 안 잠들게」 감싸 두지만,
    # 덮개를 닫으면 잠든다(외부 모니터 연결 제외). 설정을 읽어 알려만 준다.
    local s; s=$(pmset -g custom 2>/dev/null | awk '/AC Power/{f=1} f && $1=="sleep"{print $2; exit}')
    if [ -z "$s" ]; then set_result sleep '잠자기 설정 (슬랙 서버가 멈추지 않게)' '선택' 1 '확인 못 함 — 넘어갑니다'; return; fi
    if [ "$s" = "0" ]; then set_result sleep '잠자기 설정 (슬랙 서버가 멈추지 않게)' '선택' 1 '정상 — 전원 연결 중 잠자기 안 함'
    else set_result sleep '잠자기 설정 (슬랙 서버가 멈추지 않게)' '선택' 1 "전원 연결 중 ${s}분 뒤 잠자기 — 서버가 켜져 있는 동안은 caffeinate 가 막아 줍니다. 덮개는 닫지 마세요"; fi
}

# ── 4. 고치기 (설치·로그인) — 묻지 않고 바로 한다 ────────────
ensure_path_profile() {
    # 새 터미널 창에서도 claude · py 를 부를 수 있게 ~/.zprofile 에 한 번만 적는다.
    local f="$HOME/.zprofile"
    if ! grep -q 'gplatform 스타터킷' "$f" 2>/dev/null; then
        {
            echo ''
            echo '# gplatform 스타터킷 — claude · py · node 를 어느 창에서든 부르기'
            echo 'export PATH="$HOME/.local/bin:$HOME/.local/node22/bin:$PATH"'
        } >> "$f"
        info "~/.zprofile 에 PATH 한 줄을 넣었습니다 (새 터미널 창부터 적용)"
    fi
    if [ "$(basename "${SHELL:-}")" = "bash" ] && ! grep -q 'gplatform 스타터킷' "$HOME/.bash_profile" 2>/dev/null; then
        printf '\n# gplatform 스타터킷\nexport PATH="$HOME/.local/bin:$HOME/.local/node22/bin:$PATH"\n' >> "$HOME/.bash_profile"
    fi
}

fix_git() {
    is_ok git && return
    [ $SKIP_INSTALL -eq 1 ] && { info '(--skip-install) Git 설치 생략'; return; }
    step 'Git 설치 — 「명령어 도구 설치」 창이 뜹니다. 「설치」 를 누르고 약관에 동의하세요 (5~15분)'
    xcode-select --install >/dev/null 2>&1
    info '설치가 끝나는 걸 자동으로 감지합니다 (최대 30분). 이 창은 닫지 마세요.'
    local i=0
    while ! xcode-select -p >/dev/null 2>&1; do
        sleep 10; i=$((i+1)); printf '%s.%s' "$D" "$N"
        [ $i -ge 180 ] && break
    done
    printf '\n'
    check_git
    is_ok git || warn '명령어 도구가 아직 없습니다. 설치 창을 끝낸 뒤 환경점검.command 를 다시 실행하세요.'
}

fix_node() {
    is_ok node && { check_npm; return; }
    [ $SKIP_INSTALL -eq 1 ] && { info '(--skip-install) Node.js 설치 생략'; return; }
    step 'Node.js 22 설치 — 공식 파일을 ~/.local/node22 에 풉니다 (관리자 비밀번호 필요 없음)'
    local arch; case "$(uname -m)" in arm64) arch=arm64 ;; *) arch=x64 ;; esac
    local base='https://nodejs.org/dist/latest-v22.x'
    local name; name=$(curl -fsSL "$base/SHASUMS256.txt" 2>/dev/null | awk -v a="darwin-$arch.tar.gz" '$2 ~ a"$" {print $2}' | head -n 1)
    local sum; sum=$(curl -fsSL "$base/SHASUMS256.txt" 2>/dev/null | awk -v n="$name" '$2==n {print $1}')
    if [ -z "$name" ] || [ -z "$sum" ]; then warn 'Node.js 배포 목록을 받지 못했습니다. 인터넷을 확인하고 다시 실행하세요.'; return; fi
    local tmp; tmp=$(mktemp -d -t wdnode)
    info "$name 받는 중…"
    if ! curl -fL --retry 2 -o "$tmp/$name" "$base/$name" 2>/dev/null; then warn 'Node.js 다운로드 실패'; rm -rf "$tmp"; return; fi
    if [ "$(shasum -a 256 "$tmp/$name" | awk '{print $1}')" != "$sum" ]; then warn 'Node.js 파일 검증(SHA-256)이 맞지 않아 설치하지 않습니다.'; rm -rf "$tmp"; return; fi
    tar -xzf "$tmp/$name" -C "$tmp" || { warn '압축 풀기 실패'; rm -rf "$tmp"; return; }
    mkdir -p "$HOME/.local"
    [ -d "$HOME/.local/node22" ] && mv "$HOME/.local/node22" "$HOME/.local/node22.old-$(date +%Y%m%d%H%M%S)"
    mv "$tmp/${name%.tar.gz}" "$HOME/.local/node22"
    rm -rf "$tmp"
    hash -r
    check_node; check_npm
}

fix_claude() {
    is_ok claude && return
    [ $SKIP_INSTALL -eq 1 ] && { info '(--skip-install) Claude Code 설치 생략'; return; }
    step 'Claude Code 설치 — 공식 설치 스크립트 (묻지 않습니다)'
    curl -fsSL https://claude.ai/install.sh | bash
    hash -r; check_claude
    is_ok claude && return
    if has npm; then
        info '공식 스크립트가 막혀 npm 으로 다시 시도합니다'
        npm install -g @anthropic-ai/claude-code
        hash -r; check_claude
    fi
    is_ok claude || warn '자동 설치가 전부 막혔습니다. 회사 보안 정책이면 개인 노트북으로 진행하세요.'
}

fix_claude_version() {
    { is_ok claude-ver || ! is_ok claude; } && return
    [ $SKIP_INSTALL -eq 1 ] && { info '(--skip-install) Claude Code 업데이트 생략'; return; }
    step 'Claude Code 를 최신판으로 올립니다 (묻지 않음, 1분 안팎)'
    run_to 240 "$(claude_path)" update
    check_claude_version
    is_ok claude-ver || warn 'Claude Code 를 올리지 못했습니다. 터미널에서 claude update 를 직접 실행해 보세요.'
}

fix_claude_login() {
    { is_ok claude-login || ! is_ok claude; } && return
    [ $SKIP_LOGIN -eq 1 ] && { info '(--skip-login) 로그인 생략'; return; }
    step 'Claude Code 로그인 — 브라우저가 열립니다'
    info '브라우저에서 claude.ai 계정(유료 구독)으로 로그인하세요. 코드가 나오면 이 창에 붙여넣습니다(⌘V → return).'
    "$(claude_path)" auth login </dev/tty
    check_claude_login
    is_ok claude-login || warn '로그인이 확인되지 않았습니다. 로그인 후 환경점검.command 를 다시 실행하세요.'
}

write_py_wrapper() {
    mkdir -p "$LOCALBIN"
    cat > "$LOCALBIN/py" <<EOF
#!/bin/sh
# gplatform 스타터킷(맥) — 윈도우의 py 실행기와 같은 명령을 쓰게 해 주는 작은 파일 (env_check.sh 가 만듦)
#   py -3 xxx.py / py -3.14 xxx.py / py xxx.py  →  수업용 파이썬 3.14 ($VENV)
case "\$1" in -3|-3.*) shift ;; esac
exec "$PYEXE" "\$@"
EOF
    chmod +x "$LOCALBIN/py"
}

fix_python() {
    [ $SKIP_INSTALL -eq 1 ] && { info '(--skip-install) Python 설치 생략'; return; }
    if is_ok python; then write_py_wrapper; check_pip; check_pylauncher; return; fi
    step 'Python 3.14 설치 — uv 로 ~/AgentOffice/.venv 에 따로 깝니다 (관리자 비밀번호 필요 없음)'
    if ! has uv && [ ! -x "$LOCALBIN/uv" ]; then
        info 'uv(파이썬 설치 도구) 받는 중…'
        curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$LOCALBIN" UV_NO_MODIFY_PATH=1 INSTALLER_NO_MODIFY_PATH=1 sh
        hash -r
    fi
    local uv; uv=$(command -v uv 2>/dev/null); [ -z "$uv" ] && uv="$LOCALBIN/uv"
    if [ ! -x "$uv" ]; then warn 'uv 를 설치하지 못했습니다. 인터넷을 확인하고 다시 실행하세요.'; return; fi
    "$uv" python install 3.14 || { warn 'Python 3.14 를 받지 못했습니다.'; return; }
    if [ -d "$VENV" ]; then mv "$VENV" "$VENV.old-$(date +%Y%m%d%H%M%S)"; fi
    "$uv" venv --seed --python 3.14 "$VENV" || { warn '수업용 파이썬 폴더(.venv)를 만들지 못했습니다.'; return; }
    write_py_wrapper
    check_python; check_pip; check_pylauncher
    is_ok python && info "py -3 = $PYEXE (새 터미널 창에서도 py -3 로 부릅니다)"
}

fix_pypackages() {
    is_ok python || return
    [ $SKIP_INSTALL -eq 1 ] && { info '(--skip-install) 꾸러미 설치 생략'; return; }
    local req="$KIT/slack-server/requirements.txt"
    [ -f "$req" ] || { warn "requirements.txt 가 없습니다: $req"; return; }
    step '파이썬 꾸러미 설치 — 매번 확인해서 빠진 것만 채웁니다 (묻지 않습니다)'
    "$PYEXE" -m pip install --disable-pip-version-check -r "$req" playwright pandas openpyxl matplotlib python-docx pypdf
    check_pypackages
    if ! is_ok pypkg; then
        warn '꾸러미가 아직 빠져 있습니다. 한 번 더 시도합니다.'
        "$PYEXE" -m pip install --disable-pip-version-check --upgrade pip
        "$PYEXE" -m pip install --disable-pip-version-check -r "$req" playwright pandas openpyxl matplotlib python-docx pypdf
        check_pypackages
    fi
    is_ok pypkg || warn '꾸러미 설치가 끝나지 않았습니다. 인터넷을 확인하고 환경점검.command 를 다시 실행하세요.'
}

read_token() {   # read_token 이름 앞머리 → 값을 TOKEN 에 (s 면 빈 값)
    TOKEN=""
    local other
    while true; do
        ask_secret "$1 — $2 로 시작하는 값을 붙여넣고 return (⌘V · 화면에 안 보이면 정상 · 나중에 하려면 s)"
        local v; v=$(trim_q "$REPLY")
        [ "$(lower "$v")" = "s" ] && return 1
        if [ -z "$v" ]; then warn '비어 있습니다. 다시 붙여넣으세요 (⌘V)'; continue; fi
        case "$v" in
            "$2"*) info "받음: $(printf '%s' "$v" | cut -c1-8)… (${#v}자)"; TOKEN="$v"; return 0 ;;
        esac
        other='xoxb-'; [ "$2" = 'xoxb-' ] && other='xapp-'
        case "$v" in "$other"*) warn "$other 로 시작하는 값입니다 — 다른 열쇠를 붙여넣으셨어요. $2 열쇠를 넣어주세요." ;;
                     *) warn "$2 로 시작해야 합니다. 앞뒤가 잘렸는지 확인하세요." ;; esac
    done
}

fix_slack() {   # fix_slack [force]
    { is_ok slack && [ "${1:-}" != "force" ]; } && return
    { [ $SKIP_SLACK -eq 1 ] || [ $SKIP_LOGIN -eq 1 ]; } && { info '(--skip-slack) 슬랙 열쇠 입력 생략'; return; }
    local envf="$KIT/slack-server/.env"
    step '슬랙 열쇠 넣기 — 교안 슬랙 ①② 쪽에서 받아 둔 값을 교안과 같은 순서로 붙여넣습니다'
    info '붙여넣기는 ⌘V. 값은 화면에 보이지 않고 .env 파일에만 저장됩니다.'
    info '아직 못 받았으면 s 를 치고 return — 나중에 슬랙열쇠_넣기.command 를 실행하면 이 자리부터 다시 묻습니다.'
    read_token '① 앱 토큰 SLACK_APP_TOKEN' 'xapp-' || { info '슬랙은 나중에. 교안 슬랙 ①② 쪽대로 받아 오세요.'; return; }
    local appt="$TOKEN"
    read_token '② 봇 토큰 SLACK_BOT_TOKEN' 'xoxb-' || { info '슬랙은 나중에.'; return; }
    local bot="$TOKEN"
    local owner
    while true; do
        ask '③ 내 멤버 ID OWNER_USER_ID — U 로 시작하는 값 (슬랙 앱 → 내 프로필 → ⋯ 더보기 → 멤버 ID 복사)'
        owner=$(trim_q "$REPLY")
        printf '%s' "$owner" | grep -qE '^[UW][A-Z0-9]{8,}$' && break
        warn 'U 로 시작하는 9자 이상 영문·숫자여야 합니다 (이메일·이름이 아니라 "멤버 ID 복사" 값)'
    done
    local oname=""
    while true; do
        ask '④ 내 이름 OWNER_NAME — 직원들이 나를 부를 이름 (한글, 예: 홍길동)'
        oname=$(trim_q "$REPLY")
        if [ -z "$oname" ]; then
            warn '이름이 없으면 직원이 나를 "대표님" 이라고만 부릅니다. 그래도 되면 한 번 더 return.'
            ask '④ 내 이름 (그냥 return 치면 건너뜁니다)'; oname=$(trim_q "$REPLY")
            [ -z "$oname" ] && break
        fi
        # 한글이 들어 있는지 = ASCII 가 아닌 글자가 있는지 (맥 grep 은 한글 범위 [가-힣] 이 지역 설정에 따라 흔들린다)
        printf '%s' "$oname" | LC_ALL=C grep -q '[^ -~]' && break
        warn '한글 이름으로 적어 주세요. 영문 이름은 직원이 한글로 옮기다 틀립니다.'
    done
    umask 077
    {
        echo "# 슬랙 열쇠 — 환경점검이 $(date '+%Y-%m-%d %H:%M') 에 저장. 비밀번호와 같습니다. 남에게 주지 마세요."
        echo "SLACK_BOT_TOKEN=$bot"
        echo "SLACK_APP_TOKEN=$appt"
        echo "OWNER_USER_ID=$owner"
        [ -n "$oname" ] && echo "OWNER_NAME=$oname"
    } > "$envf" || { warn '.env 저장 실패'; return; }
    umask 022
    bot=""; appt=""; TOKEN=""
    info ".env 저장됨: $envf"
    check_slack_env
}

test_slack_live() {
    is_ok slack || return
    if ! is_ok pypkg; then set_result slack-live '슬랙 열쇠가 실제로 통한다' '필수' 0 '파이썬 꾸러미 먼저'; return; fi
    local chk="$KIT/slack-server/slack_check.py"
    [ -f "$chk" ] || { set_result slack-live '슬랙 열쇠가 실제로 통한다' '필수' 0 'slack_check.py 가 없습니다 — 스타터킷 다시 설치'; return; }
    step '슬랙에 실제로 물어봅니다 (열쇠 값은 화면에 나오지 않습니다)'
    run_to 60 "$PYEXE" -X utf8 "$chk"; local code=$?
    printf '%s\n' "$OUT" | sed '/^[[:space:]]*$/d' | while IFS= read -r l; do info "$l"; done
    local d; d=$(printf '%s\n' "$OUT" | sed '/^[[:space:]]*$/d' | tail -n 1); [ -z "$d" ] && d='응답 없음'
    local ok=0; [ $code -eq 0 ] && ok=1
    set_result slack-live '슬랙 열쇠가 실제로 통한다' '필수' $ok "$d" '틀린 열쇠를 다시 받아 슬랙열쇠_넣기.command 를 다시 실행'
}

test_server() {
    [ $NO_SERVER_TEST -eq 1 ] && return
    if ! is_ok slack-live; then set_result server '슬랙 서버 첫 기동 (준비 완료)' '필수' 0 '열쇠 확인 먼저'; return; fi
    local srv="$KIT/slack-server"
    # 자동 실행으로 이미 떠 있으면 두 벌이 되므로 잠깐 내린다 (끝나면 enable_autostart 가 다시 올린다)
    launchctl bootout "gui/$(id -u)/kr.gplatform.starterkit.server" >/dev/null 2>&1
    step '슬랙 서버를 한 번 켜 봅니다 (최대 90초, 끝나면 자동으로 끕니다)'
    local out; out=$(mktemp -t wdsrv)
    ( cd "$srv" && exec "$PYEXE" -u -X utf8 server.py >"$out" 2>&1 ) & local pid=$!
    local ok=0 d='90초 안에 "준비 완료" 가 뜨지 않음' i=0
    while [ $i -lt 30 ]; do
        sleep 3; i=$((i+1))
        if grep -q '준비 완료' "$out"; then ok=1; d=$(grep '준비 완료' "$out" | head -n 1 | sed 's/^[[:space:]]*//'); break; fi
        if grep -qE '❌|Error|Traceback' "$out"; then d=$(grep -E '❌|Error' "$out" | head -n 1); [ -z "$d" ] && d='오류로 종료'; break; fi
        if ! kill -0 $pid 2>/dev/null; then d='서버가 바로 꺼짐'; break; fi
        printf '%s.%s' "$D" "$N"
    done
    printf '\n'
    kill $pid 2>/dev/null; wait $pid 2>/dev/null
    rm -f "$out"
    local agents; agents=$(ls "$KIT/.claude/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ $ok -eq 1 ] && [ "$agents" = "0" ] && d="$d — 직원은 아직 0명(모듈 1에서 만듭니다)"
    set_result server '슬랙 서버 첫 기동 (준비 완료)' '필수' $ok "$d" 'slack-server 폴더에서 py -3 -X utf8 server.py 를 켜고 메시지를 읽으세요'
}

enable_autostart() {
    # 맥에 로그인할 때마다 슬랙 서버가 저절로 뜨게 등록한다 (macOS LaunchAgent).
    # 서버가 꺼지면 macOS 가 10초 뒤 다시 켠다 — 윈도우판 감시기(supervisor.ps1) 역할까지 한다.
    [ $NO_SERVER_TEST -eq 1 ] && return
    local sh_="$KIT/slack-server/autostart.sh"
    [ -f "$sh_" ] || { set_result autostart '맥 켤 때 슬랙 서버 자동 시작' '필수' 0 'autostart.sh 가 없습니다 — 스타터킷 다시 설치'; return; }
    step '이제 맥에 로그인할 때마다 슬랙 서버가 저절로 뜨도록 등록합니다'
    /bin/bash "$sh_" --enable --quiet 2>&1 | while IFS= read -r l; do info "$l"; done
    local plist="$HOME/Library/LaunchAgents/kr.gplatform.starterkit.server.plist"
    local ok=0 d='자동시작 등록에 실패했습니다'
    if [ -f "$plist" ]; then
        ok=1
        local spid; spid=$(launchctl print "gui/$(id -u)/kr.gplatform.starterkit.server" 2>/dev/null | awk '$1=="pid"{print $3; exit}')
        if [ -n "$spid" ]; then d="등록 완료 — 지금도 켜져 있습니다 (PID $spid)"
        elif is_ok server; then d='등록 완료 — 다음에 로그인하면 뜹니다'
        else d='등록은 됐습니다 — 다만 서버가 아직 안 떴습니다. 슬랙 열쇠 3개를 확인하고 환경점검을 다시 돌리면 그때부터 저절로 뜹니다'; fi
    fi
    set_result autostart '맥 켤 때 슬랙 서버 자동 시작' '필수' $ok "$d" '스타터킷 폴더의 자동시작_켜기.command 를 눌러 주세요'
}

check_mail_env() {
    local envf="$KIT/mail/.env" nm='메일 연결 (네이버·다음·지메일 앱 비밀번호)'
    [ -f "$KIT/mail/mail_check.py" ] || return
    if [ ! -f "$envf" ]; then set_result mail "$nm" '선택' 0 'mail/.env 가 아직 없습니다 (부록 B-2 · 수업 뒤 선택)' '메일_연결.command 를 실행해 앱 비밀번호를 붙여넣습니다' 'https://mail.naver.com/'; return; fi
    local p u w; p=$(trim_q "$(env_get "$envf" MAIL_PROVIDER)"); u=$(trim_q "$(env_get "$envf" MAIL_USER)"); w=$(trim_q "$(env_get "$envf" MAIL_APP_PASSWORD)")
    local miss=""; [ -z "$p" ] && miss="$miss MAIL_PROVIDER"; [ -z "$u" ] && miss="$miss MAIL_USER"; [ -z "$w" ] && miss="$miss MAIL_APP_PASSWORD"
    w=""
    if [ -z "$miss" ]; then set_result mail "$nm" '선택' 1 "$p $u (비밀번호는 확인하지 않습니다)"
    else set_result mail "$nm" '선택' 0 "${miss# } 비어 있음" '메일_연결.command 를 실행해 앱 비밀번호를 붙여넣습니다'; fi
}

fix_mail() {
    { [ $MAIL -eq 1 ] || [ $MAIL_ONLY -eq 1 ]; } || return
    [ $SKIP_LOGIN -eq 1 ] && return
    [ -f "$KIT/mail/mail_check.py" ] || return
    if is_ok mail; then
        local cur; cur=$(detail_of mail | sed 's/ (비밀번호는 확인하지 않습니다)//')
        ask "지금 $cur 이(가) 연결돼 있습니다. 다른 메일로 바꿀까요? (y = 바꾸기 / 그냥 return = 그대로)"
        [ "$(lower "$REPLY")" = "y" ] || return
        info '새 메일로 다시 묻습니다. 끝까지 넣으면 예전 연결은 새 것으로 바뀝니다 (메일 연결은 한 계정만 기억합니다).'
    fi
    local envf="$KIT/mail/.env"
    step '메일 연결 (선택) — 메일을 직원이 읽게 합니다. 앱 비밀번호는 교안 부록 B-2 대로 미리 받아 둡니다'
    info '연습은 개인 메일로 합니다. 회사 메일은 회사 승인을 받은 뒤에만 custom 으로 연결합니다.'
    info '네이버: 메일 → 환경설정 → POP3/IMAP 에서 IMAP 켜기 → 네이버 보안 → 2단계 인증 → 애플리케이션 비밀번호'
    info '다음: 메일 → 설정 → IMAP/SMTP 사용 → 카카오계정 2단계 인증 → 앱 비밀번호   /   지메일: 구글 계정 → 보안 → 앱 비밀번호'
    local prov
    while true; do
        ask '어느 메일인가요 — naver / daum / gmail / custom(회사 메일) 중 하나 (나중에 하려면 s)'
        prov=$(lower "$(trim_q "$REPLY")")
        [ "$prov" = "s" ] && { info '메일은 나중에. 수업 뒤 부록 카드 B-2 로 다시 할 수 있습니다.'; return; }
        case "$prov" in naver|daum|gmail|custom) break ;; esac
        warn 'naver, daum, gmail, custom 중 하나를 영문으로 적어 주세요 (회사 메일이 구글 워크스페이스면 gmail)'
    done
    local custom=""
    if [ "$prov" = "custom" ]; then
        warn '회사 메일은 회사 승인이 먼저입니다 — IMAP 접속 허용, 메일 본문을 Claude 가 읽는 것, 발송은 사람이 하는 것까지.'
        info '서버 주소는 회사 IT 에 물어보세요. 마이크로소프트 365(아웃룩)는 이 방식으로 연결되지 않습니다.'
        ask '회사 승인을 받았나요 (y / n)'
        [ "$(lower "$REPLY")" = "y" ] || { info '승인 뒤에 메일_연결.command 를 다시 실행하세요. 연습은 개인 메일로 합니다.'; return; }
        local ih="" ip sh sp=""
        while [ -z "$ih" ]; do
            ask '받는 메일 서버 IMAP 주소 (예: imap.회사도메인)'; ih=$(trim_q "$REPLY")
            if printf '%s' "$ih" | grep -qiE '(^|\.)(office365|outlook)\.com$'; then warn '마이크로소프트 365 는 연결되지 않습니다. 개인 메일로 연습하세요.'; return; fi
        done
        ask 'IMAP 포트 (모르면 그냥 return = 993)'; ip=$(trim_q "$REPLY")
        ask '보내는 메일 서버 SMTP 주소 (읽기만 할 거면 그냥 return)'; sh=$(trim_q "$REPLY")
        [ -n "$sh" ] && { ask 'SMTP 포트 (모르면 그냥 return = 465, 587 도 됩니다)'; sp=$(trim_q "$REPLY"); }
        custom=$(printf 'MAIL_IMAP_HOST=%s\nMAIL_IMAP_PORT=%s\nMAIL_SMTP_HOST=%s\nMAIL_SMTP_PORT=%s' "$ih" "$ip" "$sh" "$sp")
    fi
    local user
    while true; do
        ask '메일 주소 전체 (예: hong@naver.com)'; user=$(trim_q "$REPLY")
        printf '%s' "$user" | grep -qE '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' && break
        warn '@ 가 들어간 메일 주소 전체를 적어 주세요'
    done
    local pw
    while true; do
        ask_secret '앱 비밀번호 (로그인 비밀번호가 아닙니다) — 붙여넣고 return (⌘V · 화면에 안 보이면 정상 · 나중에 하려면 s)'
        pw=$(trim_q "$REPLY")
        [ "$(lower "$pw")" = "s" ] && { info '메일은 나중에.'; return; }
        [ ${#pw} -ge 8 ] && break
        warn '너무 짧습니다. 앱 비밀번호를 다시 붙여넣으세요 (⌘V)'
    done
    umask 077
    {
        echo "# 메일 열쇠 — 환경점검이 $(date '+%Y-%m-%d %H:%M') 에 저장. 비밀번호와 같습니다. 남에게 주지 마세요."
        echo "MAIL_PROVIDER=$prov"
        echo "MAIL_USER=$user"
        echo "MAIL_APP_PASSWORD=$pw"
        echo "MAIL_ALLOW_EXTERNAL=0"
        [ -n "$custom" ] && printf '%s\n' "$custom"
    } > "$envf" || { warn 'mail/.env 저장 실패'; return; }
    umask 022
    pw=""; REPLY=""
    info 'mail/.env 저장됨'
    check_mail_env
}

test_mail_live() {
    is_ok mail || return
    is_ok python || return
    local chk="$KIT/mail/mail_check.py"
    [ -f "$chk" ] || return
    step '메일 서버에 실제로 로그인해 봅니다 (비밀번호는 화면에 나오지 않습니다)'
    run_to 60 "$PYEXE" -X utf8 "$chk"; local code=$?
    printf '%s\n' "$OUT" | sed '/^[[:space:]]*$/d' | while IFS= read -r l; do info "$l"; done
    local d; d=$(printf '%s\n' "$OUT" | sed '/^[[:space:]]*$/d' | tail -n 1); [ -z "$d" ] && d='응답 없음'
    local ok=0; [ $code -eq 0 ] && ok=1
    set_result mail-live '메일 로그인이 실제로 통한다' '선택' $ok "$d" 'mail/README.md 의 오류 3가지를 보고 앱 비밀번호를 다시 받습니다'
}

# ── 5. 결과 HTML ─────────────────────────────────────────────
html_esc() { printf '%s' "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'; }
write_report() {
    local i rows="" mark cls fix
    for i in "${!R_ID[@]}"; do
        if [ "${R_OK[$i]}" = "1" ]; then mark="$OKM"; cls=ok; elif [ "${R_GROUP[$i]}" = "선택" ]; then mark="$WRN"; cls=opt; else mark="$NOM"; cls=no; fi
        fix=""; [ "${R_OK[$i]}" != "1" ] && [ -n "${R_FIX[$i]}" ] && fix="<div class=fix>고치기: $(html_esc "${R_FIX[$i]}")</div>"
        rows="$rows<tr class=$cls><td>$mark</td><td>$(html_esc "${R_GROUP[$i]}")</td><td><b>$(html_esc "${R_NAME[$i]}")</b><div class=d>$(html_esc "${R_DETAIL[$i]}")</div>$fix</td></tr>"
    done
    cat > "$REPORT" <<EOF
<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>환경점검 결과 (맥)</title>
<style>body{font-family:-apple-system,"Apple SD Gothic Neo",sans-serif;max-width:860px;margin:32px auto;padding:0 16px;color:#222}
h1{font-size:22px}table{border-collapse:collapse;width:100%}td{border-bottom:1px solid #eee;padding:10px 8px;vertical-align:top}
td:first-child{width:28px;font-size:18px}td:nth-child(2){width:48px;color:#888;font-size:13px}.d{color:#666;font-size:13px;margin-top:2px}
.fix{color:#b26a00;font-size:13px;margin-top:4px}tr.no b{color:#c62828}.sum{padding:12px 14px;border-radius:8px;background:#f5f3ff;margin:16px 0}</style></head>
<body><h1>에이전트팀 만들기 — 환경점검 결과 (맥)</h1>
<div class="sum">$(html_esc "$SUMMARY")<br><span class="d">$(date '+%Y-%m-%d %H:%M') · $(html_esc "$KIT")</span></div>
<table>$rows</table></body></html>
EOF
}

# ── 6. 실행 ──────────────────────────────────────────────────
printf '\n  %s┌──────────────────────────────────────────────────┐%s\n' "$M" "$N"
printf '  %s│   에이전트팀 만들기 과정 — 출발선 자동 점검·설치 (맥)  │%s\n' "$M" "$N"
printf '  %s└──────────────────────────────────────────────────┘%s\n' "$M" "$N"
info "스타터킷: $KIT"
[ -n "$PRETEND" ] && warn "테스트 모드 — 없는 것으로 가정: ${PRETEND//,/ }"

if [ $SLACK_ONLY -eq 1 ]; then
    step '1/3 준비 확인 (파이썬 · 꾸러미 · 폴더)'
    check_python; check_pypackages; check_folders
    { is_ok python && is_ok pypkg; } || warn '설치가 덜 끝났습니다. 환경점검.command 를 먼저 실행하세요.'
    step '2/3 슬랙 열쇠 넣기 · 연결 시험'
    check_slack_env
    if is_ok slack && [ $YES -eq 0 ]; then
        info '열쇠가 이미 들어 있습니다. 그대로 쓰려면 return, 새 열쇠로 바꾸려면 y.'
        ask_yesno '열쇠를 새로 넣을까요?' 0 && fix_slack force
    else fix_slack; fi
    test_slack_live
    if is_ok slack && ! is_ok slack-live && [ $YES -eq 0 ]; then
        warn '열쇠가 슬랙에 통하지 않습니다. 바로 위 NG 줄이 어느 열쇠가 틀렸는지 알려 줍니다.'
        ask_yesno '지금 열쇠를 다시 넣을까요?' 1 && { fix_slack force; test_slack_live; }
    fi
    step '3/3 슬랙 서버 첫 기동 · 자동시작 등록'
    test_server
    enable_autostart
elif [ $MAIL_ONLY -eq 1 ]; then
    step '메일 연결 (부록 B-2 · 선택)'
    check_python
    check_mail_env
    fix_mail
    test_mail_live
else
    if [ $SKIP_SLACK -eq 1 ]; then info '이 프로그램은 묻지 않고 설치합니다. 사람이 할 일은 설치 창의 「설치」 와 로그인뿐입니다.'
    else info '이 프로그램은 묻지 않고 설치합니다. 사람이 할 일은 설치 창의 「설치」, 로그인, 슬랙 열쇠 붙여넣기뿐입니다.'; fi

    step '1/6 기본 확인'
    check_macos; check_internet; check_disk

    step '2/6 프로그램 — 없으면 설치, 파이썬은 3.14 로'
    ensure_path_profile
    check_git;    fix_git
    check_node;   fix_node
    check_python; fix_python
    check_pip; check_pylauncher
    check_claude; fix_claude
    check_claude_version; fix_claude_version
    check_vscode; check_chrome

    step '3/6 Claude Code 로그인'
    check_claude_login; fix_claude_login

    step '4/6 파이썬 꾸러미'
    check_pypackages; fix_pypackages

    step '5/6 스타터킷 · 슬랙 열쇠 · 서버 첫 기동'
    check_folders; check_mydata
    check_slack_env; fix_slack
    test_slack_live; test_server; enable_autostart
    check_sleep

    step '6/6 선택 항목 (메일 연결 · 네이버 블로그 로그인)'
    check_mail_env; fix_mail; test_mail_live
    check_naver_login
fi

# ── 7. 최종 체크리스트 ───────────────────────────────────────
printf '\n  %s══════════════════ 체크리스트 ══════════════════%s\n' "$M" "$N"
req_n=0; req_ok=0; opt_n=0; opt_ok=0; slack_left=0; other_left=0
printf '  %s[필수]%s\n' "$W" "$N"
for i in "${!R_ID[@]}"; do
    [ "${R_GROUP[$i]}" = "선택" ] && continue
    req_n=$((req_n+1))
    if [ "${R_OK[$i]}" = "1" ]; then req_ok=$((req_ok+1)); printf '  %s%s %s%s\n' "$G" "$OKM" "${R_NAME[$i]}" "$N"
    else
        printf '  %s%s %s%s\n' "$R" "$NOM" "${R_NAME[$i]}" "$N"
        printf '        %s└ %s%s\n' "$D" "${R_DETAIL[$i]}" "$N"
        [ -n "${R_FIX[$i]}" ] && printf '        %s└ 고치기: %s%s\n' "$Y" "${R_FIX[$i]}" "$N"
        case "${R_ID[$i]}" in slack|slack-live|server) slack_left=1 ;; autostart) ;; *) other_left=1 ;; esac
    fi
done
printf '  %s[선택]%s\n' "$W" "$N"
for i in "${!R_ID[@]}"; do
    [ "${R_GROUP[$i]}" = "선택" ] || continue
    opt_n=$((opt_n+1))
    if [ "${R_OK[$i]}" = "1" ]; then opt_ok=$((opt_ok+1)); printf '  %s%s %s%s\n' "$G" "$OKM" "${R_NAME[$i]}" "$N"
    else printf '  %s%s %s%s\n' "$Y" "$WRN" "${R_NAME[$i]}" "$N"; fi
done
printf '  %s─────────────────────────────────────────────────%s\n' "$M" "$N"
if [ $req_ok -eq $req_n ]; then
    SUMMARY="🎉 필수 $req_ok/$req_n 전부 통과 · 선택 $opt_ok/$opt_n — 출발 준비 완료! 새 터미널 창을 열고 claude 를 부르세요."
    printf '  %s%s%s\n' "$G" "$SUMMARY" "$N"
else
    SUMMARY="필수 $req_ok/$req_n 통과 · 선택 $opt_ok/$opt_n — ❌ 표시된 것만 고치고 다시 실행하세요."
    printf '  %s%s%s\n' "$Y" "$SUMMARY" "$N"
fi
if [ $slack_left -eq 1 ] && [ $other_left -eq 0 ] && [ $SLACK_ONLY -eq 0 ]; then
    printf '  %s👉 슬랙 줄만 ❌ 면 정상입니다. 교안 「슬랙 ①②」로 열쇠를 받은 뒤 아래 파일을 더블클릭하세요.%s\n' "$C" "$N"
    printf '     %s%s/슬랙열쇠_넣기.command%s\n' "$C" "$KIT" "$N"
fi

write_report && info "결과 파일: $REPORT" && [ $NO_BROWSER -eq 0 ] && open "$REPORT" 2>/dev/null
info "소요 $(( $(date +%s) - STARTED ))초"

if [ $NO_PAUSE -eq 0 ]; then printf '  창을 닫으려면 return '; read -r _ </dev/tty; fi
[ $req_ok -eq $req_n ]
