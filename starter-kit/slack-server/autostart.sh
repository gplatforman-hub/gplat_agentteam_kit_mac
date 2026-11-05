#!/bin/bash
# ============================================================
#  autostart.sh — 슬랙 서버 자동시작 켜기/끄기 (맥 · 윈도우판 autostart.ps1 + supervisor.ps1 자리)
#
#  켜기: 맥에 로그인할 때마다 슬랙 서버가 저절로 뜨고, 꺼져도 10초 뒤 macOS 가 다시 켠다.
#        (macOS LaunchAgent: ~/Library/LaunchAgents/kr.gplatform.starterkit.server.plist)
#        caffeinate 로 감싸서, 전원이 연결돼 있는 동안 서버 때문에 맥이 잠들지 않게 한다.
#  끄기: 등록을 지우고 이 킷이 띄운 서버만 내린다 (이름이 server.py 인 다른 파이썬은 건드리지 않는다).
#
#  옵션: --enable | --disable   [--quiet]  (--quiet = 환경점검이 부를 때. return 을 기다리지 않는다)
# ============================================================

set -u
MODE=""; QUIET=0
for a in "$@"; do
    case "$a" in --enable) MODE=enable ;; --disable) MODE=disable ;; --quiet) QUIET=1 ;; esac
done

DIR="$(cd "$(dirname "$0")" && pwd)"
KIT="$(dirname "$DIR")"
COURSE="$(dirname "$KIT")"
if [ "$(basename "$COURSE")" = "01_KIT" ]; then ROOT="$(dirname "$COURSE")"; else ROOT="$HOME/AgentOffice"; fi
PYEXE="$ROOT/.venv/bin/python"
LABEL="kr.gplatform.starterkit.server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
LOGDIR="$DIR/logs"

M=$'\033[35m'; G=$'\033[32m'; R=$'\033[31m'; D=$'\033[90m'; Y=$'\033[33m'; N=$'\033[0m'
say() { printf '  %s%s%s\n' "${2:-}" "$1" "$N"; }
pause_if() { [ $QUIET -eq 1 ] || { printf '  이 창을 닫으려면 return '; read -r _ </dev/tty; }; }
server_pid() { launchctl print "$DOMAIN/$LABEL" 2>/dev/null | awk '$1=="pid"{print $3; exit}'; }

printf '\n'
if [ "$MODE" = "disable" ]; then
    say '슬랙 서버 자동시작 — 끄기' "$M"; printf '\n'
    if launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1; then say '✔ 켜져 있던 서버를 내렸습니다.' "$G"; fi
    if [ -f "$PLIST" ]; then rm -f "$PLIST"; say '✔ 로그인 자동시작 등록을 지웠습니다.' "$G"
    else say '· 자동시작 등록이 원래 없었습니다.' "$D"; fi
    printf '\n'
    say '이제 슬랙에 말을 걸어도 직원들이 답하지 않습니다. 다시 켜려면 자동시작_켜기.command 를 누르세요.' "$D"
    printf '\n'; pause_if; exit 0
fi

if [ "$MODE" != "enable" ]; then
    say '사용법: autostart.sh --enable | --disable' "$Y"; exit 2
fi

say '슬랙 서버 자동시작 — 켜기' "$M"; printf '\n'

if [ ! -x "$PYEXE" ]; then
    say "❌ 수업용 파이썬이 없습니다: $PYEXE" "$R"
    say '   스타터킷 폴더의 환경점검.command 를 먼저 실행하세요.' "$Y"
    printf '\n'; pause_if; exit 1
fi

if [ ! -f "$DIR/.env" ]; then
    # 열쇠가 없으면 막다른 길 대신 슬랙열쇠_넣기.command 로 바로 잇는다. 그 창이 열쇠 → 연결 시험 → 서버 → 자동시작까지 한다.
    say '❌ 슬랙 열쇠가 아직 없습니다 (slack-server/.env 없음).' "$R"
    printf '\n'
    say '슬랙열쇠_넣기.command 로 열쇠를 넣으면 서버도 저절로 켜집니다. 메모에 모아 둔 세 줄을 열어 두세요.' "$Y"
    say '  묻는 순서: ① 앱 토큰 xapp-  ② 봇 토큰 xoxb-  ③ 내 멤버 ID U…  ④ 내 이름(한글)'
    say '  메모에서 한 줄 복사(⌘C) → 열쇠 창에서 ⌘V → return. 화면에 안 보이면 정상입니다.'
    KEYCMD="$KIT/슬랙열쇠_넣기.command"
    if [ $QUIET -eq 0 ] && [ -f "$KEYCMD" ]; then
        printf '\n  ? 지금 열쇠 넣기 창을 열까요? (return = 예, n = 아니오) '
        read -r a </dev/tty
        if [ "$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')" != "n" ]; then
            open "$KEYCMD"
            say '✔ 열쇠 넣기 창을 열었습니다. 그 창에서 이어서 진행하세요. 이 창은 닫아도 됩니다.' "$G"
            exit 0
        fi
    fi
    printf '\n'; pause_if; exit 1
fi

say '※ 터미널에서 직접 켜 둔 서버가 있다면, 그 창에서 control+C 로 먼저 꺼주세요.' "$D"
say '   두 벌이 돌면 슬랙에서 직원이 같은 말을 두 번 합니다.' "$D"
printf '\n'

mkdir -p "$LOGDIR" "$HOME/Library/LaunchAgents"
# 이 킷이 앞서 띄워둔 것이 있으면 내리고 새로 시작한다.
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 && sleep 1

xml_esc() { printf '%s' "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'; }
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-i</string>
        <string>-s</string>
        <string>$(xml_esc "$PYEXE")</string>
        <string>-u</string>
        <string>-X</string>
        <string>utf8</string>
        <string>server.py</string>
    </array>
    <key>WorkingDirectory</key><string>$(xml_esc "$DIR")</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key><string>$(xml_esc "$HOME")/.local/bin:$(xml_esc "$HOME")/.local/node22/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>LANG</key><string>ko_KR.UTF-8</string>
        <key>PYTHONIOENCODING</key><string>utf-8</string>
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>StandardOutPath</key><string>$(xml_esc "$LOGDIR")/launcher.log</string>
    <key>StandardErrorPath</key><string>$(xml_esc "$LOGDIR")/launcher.log</string>
</dict>
</plist>
EOF

if ! plutil -lint "$PLIST" >/dev/null 2>&1; then
    say "❌ 등록 파일이 깨졌습니다: $PLIST" "$R"; printf '\n'; pause_if; exit 1
fi
if ! launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
    # 예전 macOS·이미 올라와 있는 경우를 위해 한 번 더 (load -w)
    launchctl load -w "$PLIST" 2>/dev/null
fi
say '✔ 맥에 로그인할 때마다 저절로 켜지도록 등록했습니다.' "$G"
say "  등록 파일: $PLIST" "$D"
say '· 지금 바로 켜는 중입니다...' "$D"

OK=0; SPID=""
for i in $(seq 1 25); do
    sleep 1
    SPID=$(server_pid)
    [ -n "$SPID" ] && { OK=1; break; }
done
printf '\n'
# 프로세스가 「지금 있다」 만 보고 ✔ 라고 하면 안 된다. 열쇠가 틀리면 서버는 3초쯤 살았다 죽고
# macOS 가 10초마다 다시 띄우므로, 찍는 순간에는 늘 PID 가 있다. 같은 PID 가 12초를 버티는지 본다. (윈도우판 2026-10-05 과 같음)
if [ $OK -eq 1 ]; then
    sleep 12
    [ "$(server_pid)" = "$SPID" ] || OK=0
fi
if [ $OK -eq 1 ]; then
    say "✔ 슬랙 서버가 켜졌습니다 (PID $SPID). 터미널 창은 필요 없습니다." "$G"
    say '  이제 맥을 껐다 켜도 저절로 뜹니다. 슬랙에서 직원을 불러 확인해 보세요.' "$G"
    say '  (덮개를 닫으면 맥이 잠들어 서버도 쉽니다. 수업·업무 중에는 덮개를 열어 두세요.)' "$D"
elif [ -n "$SPID" ]; then
    say '⚠ 서버가 떴다가 바로 꺼졌습니다 — 거의 틀림없이 슬랙 열쇠 문제입니다.' "$Y"
    say '  슬랙열쇠_넣기.command 를 다시 눌러 세 줄(xapp-, xoxb-, 멤버 ID)을 다시 넣어 주세요.' "$Y"
    say '  자동시작 등록은 그대로 남겨둡니다 — 열쇠를 고치면 그때부터 저절로 뜹니다.' "$D"
else
    say '⚠ 25초 안에 서버가 올라오지 않았습니다. slack-server/logs/launcher.log 와 server.log 를 확인해 주세요.' "$Y"
fi
printf '\n'
pause_if
