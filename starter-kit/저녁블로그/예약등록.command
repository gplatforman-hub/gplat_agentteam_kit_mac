#!/bin/bash
# 저녁 블로그 예약 등록 — 매일 20:00 (맥 · 윈도우판 예약등록.bat). 한 번만 더블클릭. 관리자 비밀번호 필요 없음.
# 맥이 20:00 에 잠들어 있으면 깨어난 뒤 한 번 실행합니다.
HERE="$(cd "$(dirname "$0")" && pwd)"
LABEL="kr.gplatform.starterkit.eveningblog"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
chmod +x "$HERE/evening_blog.sh"
mkdir -p "$HOME/Library/LaunchAgents" "$HERE/logs"
esc() { printf '%s' "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'; }
echo
echo "  등록: EveningBlog (매일 20:00)"
echo "  대상: $HERE/evening_blog.sh"
echo
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key><array><string>/bin/bash</string><string>$(esc "$HERE")/evening_blog.sh</string></array>
    <key>StartCalendarInterval</key><dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
    <key>StandardOutPath</key><string>$(esc "$HERE")/logs/evening_blog.log</string>
    <key>StandardErrorPath</key><string>$(esc "$HERE")/logs/evening_blog.log</string>
</dict>
</plist>
EOF
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1
if plutil -lint "$PLIST" >/dev/null 2>&1 && launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
    echo "  [OK] 등록했습니다."
    echo "       지금 한 번 돌려 보기:  launchctl kickstart $DOMAIN/$LABEL"
    echo "       예약 지우기:          예약해제.command 더블클릭"
else
    echo "  [!] 등록하지 못했습니다. 위 메시지를 복사해 강사에게 보여 주세요."
fi
echo
read -r -p "  창을 닫으려면 return " _
