#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 프로그램·파이썬 3.14·꾸러미를 확인하고 없으면 설치합니다 (윈도우판 환경점검.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./env_check.sh "$@"
