#!/bin/bash
# ============================================================
#  connect.sh — 네이버 캘린더 연결 (맥 · 캘린더_연결.command 가 부른다 · 윈도우판 connect.ps1)
#  1) 이미 연결돼 있으면 바꿀지 묻는다 (그냥 return = 그대로 두고 확인만)
#  2) 메일을 네이버로 연결해 두었으면 그 아이디·앱 비밀번호를 같이 쓸지 묻는다
#  3) 아니면 아이디와 앱 비밀번호(화면에 안 보이게)를 받아 naver-calendar/.env 에 저장한다
#  4) cal_check.py 로 실제로 로그인해 캘린더 목록과 이번 주 일정 수를 본다 (읽기만)
#  🔒 비밀번호는 화면·기록 어디에도 찍지 않는다.
# ============================================================
set -u
NO_PAUSE=0; [ "${1:-}" = "--no-pause" ] && NO_PAUSE=1
HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(dirname "$HERE")"
ENVF="$HERE/.env"
MAILENV="$KIT/mail/.env"
export PATH="$HOME/.local/bin:$PATH"
M=$'\033[35m'; G=$'\033[32m'; Y=$'\033[33m'; N=$'\033[0m'
CODE=1

env_get() { [ -f "$1" ] || return 1; LC_ALL=C sed $'1s/^\xEF\xBB\xBF//' "$1" | grep -E "^[[:space:]]*$2[[:space:]]*=" | tail -n 1 | sed -E "s/^[[:space:]]*$2[[:space:]]*=//;s/^[[:space:]\"']*//;s/[[:space:]\"']*\$//"; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
done_() { echo; [ $NO_PAUSE -eq 1 ] || { printf '창을 닫으려면 return '; read -r _ </dev/tty; }; exit $CODE; }
run_check() {
    echo
    printf '%s▶ 네이버 캘린더에 실제로 로그인해 봅니다 (읽기만 · 비밀번호는 화면에 나오지 않습니다)%s\n' "$M" "$N"
    py -3 -X utf8 "$HERE/cal_check.py"; CODE=$?
    if [ $CODE -eq 0 ]; then
        # 직원용 스킬을 .claude/skills/naver-calendar 에 넣는다 (Claude 는 .claude 를 못 고치므로 여기서)
        mkdir -p "$KIT/.claude/skills/naver-calendar" && cp "$HERE/skill/SKILL.md" "$KIT/.claude/skills/naver-calendar/SKILL.md" \
            && echo '  직원용 스킬을 .claude/skills/naver-calendar 에 넣었습니다' \
            || printf '  %s! 스킬 복사 실패%s\n' "$Y" "$N"
        printf '  %s✅ 연결됐습니다. Code 탭은 새 세션, 슬랙은 「새 대화」 를 보낸 뒤 「이번 주 네이버 캘린더 일정 알려 줘」 처럼 말하면 됩니다.%s\n' "$G" "$N"
    else
        printf '  %s❌ 위 줄의 → 뒤 안내대로 고친 뒤 캘린더_연결.command 를 다시 실행하세요.%s\n' "$Y" "$N"
    fi
}

echo
printf '%s▶ 네이버 캘린더 연결 (부록 · 선택)%s\n' "$M" "$N"
echo '   필요한 것: 네이버 「애플리케이션 비밀번호」 — 내정보 → 보안설정 → 2단계 인증 관리 → 애플리케이션 비밀번호 생성'
echo '   연습은 개인 계정으로 합니다.'

CUR_USER=$(env_get "$ENVF" NAVER_CAL_USER); CUR_PW=$(env_get "$ENVF" NAVER_CAL_APP_PASSWORD)
if [ -n "$CUR_USER" ] && [ -n "$CUR_PW" ]; then
    CUR_PW=""
    printf '  ? 지금 %s 이(가) 연결돼 있습니다. 다른 계정으로 바꿀까요? (y = 바꾸기 / 그냥 return = 그대로) ' "$CUR_USER"
    read -r a </dev/tty
    [ "$(lower "$a")" = "y" ] || { run_check; done_; }
fi

USER_=""; PW=""
if [ "$(env_get "$MAILENV" MAIL_PROVIDER)" = "naver" ]; then
    MU=$(env_get "$MAILENV" MAIL_USER)
    if [ -n "$MU" ] && [ -n "$(env_get "$MAILENV" MAIL_APP_PASSWORD)" ]; then
        printf '  ? 메일에 연결한 네이버 계정 %s 의 앱 비밀번호를 같이 쓸까요? (y = 같이 / 그냥 return = 새로 넣기) ' "$MU"
        read -r a </dev/tty
        if [ "$(lower "$a")" = "y" ]; then USER_="$MU"; PW=$(env_get "$MAILENV" MAIL_APP_PASSWORD); fi
    fi
fi

if [ -z "$USER_" ]; then
    while true; do
        printf '  ? 네이버 아이디 (예: hong 또는 hong@naver.com · 나중에 하려면 s) '
        read -r USER_ </dev/tty
        USER_=$(printf '%s' "$USER_" | sed "s/^[[:space:]\"']*//;s/[[:space:]\"']*\$//")
        [ "$(lower "$USER_")" = "s" ] && { echo '  캘린더는 나중에.'; CODE=0; done_; }
        printf '%s' "$USER_" | grep -qE '^[A-Za-z0-9._-]+(@naver\.com)?$' && break
        printf '  %s! 네이버 아이디만, 또는 아이디@naver.com 으로 적어 주세요%s\n' "$Y" "$N"
    done
    while true; do
        printf '  ? 애플리케이션 비밀번호 12자리 — 붙여넣고 return (⌘V · 화면에 안 보이면 정상 · 나중에 하려면 s) '
        read -r -s PW </dev/tty; echo
        PW=$(printf '%s' "$PW" | tr -d "[:space:]\"'")
        [ "$(lower "$PW")" = "s" ] && { echo '  캘린더는 나중에.'; CODE=0; done_; }
        [ ${#PW} -ge 8 ] && break
        printf '  %s! 너무 짧습니다. 애플리케이션 비밀번호를 다시 붙여넣으세요%s\n' "$Y" "$N"
    done
fi

umask 077
{
    echo "# 네이버 캘린더 열쇠 — 캘린더_연결.command 가 $(date '+%Y-%m-%d %H:%M') 에 저장. 비밀번호와 같습니다. 남에게 주지 마세요."
    echo "NAVER_CAL_USER=$USER_"
    echo "NAVER_CAL_APP_PASSWORD=$PW"
} > "$ENVF" || { printf '  %s! naver-calendar/.env 저장 실패%s\n' "$Y" "$N"; done_; }
umask 022
PW=""
echo '  naver-calendar/.env 저장됨'
run_check
done_
