#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# ZIP 으로 받았을 때: ~/AgentOffice 표준 폴더를 만들고 스타터킷을 설치합니다 (윈도우판 00_폴더생성_및_설치.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./install_starterkit.sh "$@"
