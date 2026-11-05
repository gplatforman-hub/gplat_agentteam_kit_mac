#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 맥에 로그인할 때마다 슬랙 서버가 저절로 뜨게 (윈도우판 자동시작_켜기.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./slack-server/autostart.sh --enable
