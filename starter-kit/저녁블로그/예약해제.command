#!/bin/bash
# 저녁 블로그 예약 지우기 (맥)
LABEL="kr.gplatform.starterkit.eveningblog"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1
if [ -f "$PLIST" ]; then rm -f "$PLIST"; echo "  [OK] 저녁 블로그 예약을 지웠습니다."; else echo "  · 예약이 원래 없었습니다."; fi
read -r -p "  창을 닫으려면 return " _
