#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 슬랙 서버 자동시작을 끄고 서버를 내립니다 (윈도우판 자동시작_끄기.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./slack-server/autostart.sh --disable
