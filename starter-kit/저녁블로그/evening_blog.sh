#!/bin/bash
# 저녁 블로그 — 매일 20:00 에 macOS 가 부른다 (예약등록.command 가 등록 · 윈도우판 evening_blog.bat)
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/.local/bin:$HOME/.local/node22/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
exec py -3 -X utf8 ./evening_blog.py
