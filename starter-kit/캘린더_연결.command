#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 네이버 캘린더 연결 — 부록 (윈도우판 캘린더_연결.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./naver-calendar/connect.sh "$@"
