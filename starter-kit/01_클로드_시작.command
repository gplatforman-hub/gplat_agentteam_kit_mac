#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 스타터킷 폴더에서 Claude Code 를 켭니다.
# 이 폴더에서 켜야 직원(.claude/agents)·스킬(.claude/skills)·자동 저장/안전장치가 붙습니다.
# 다른 곳에서 claude 를 치면 직원이 0명입니다.
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/.local/bin:$HOME/.local/node22/bin:$PATH"
if ! command -v claude >/dev/null 2>&1; then
    echo "[GP] Claude Code 가 없습니다. 이 폴더의 환경점검.command 를 먼저 더블클릭하세요."
    read -r -p "창을 닫으려면 return " _
    exit 1
fi
echo "[GP] 스타터킷 폴더: $PWD"
echo "[GP] Claude Code 를 켭니다. 직원·스킬·안전장치가 여기서 불러와집니다."
echo
claude
