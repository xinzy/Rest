#!/usr/bin/env bash
# 用无头 Chrome 把 index.html 中的每个画框截成 2 倍分辨率的 PNG，保存到 screenshots/。
# 用法：design/mockups/capture.sh [画框 id]    例如：design/mockups/capture.sh 02-panel
set -euo pipefail

cd "$(dirname "$0")"
DIR="$(pwd)"
OUT="$DIR/screenshots"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
ONLY="${1:-}"

[[ -x "$CHROME" ]] || { echo "找不到 Chrome：$CHROME（可用环境变量 CHROME 指定）" >&2; exit 1; }
mkdir -p "$OUT"
PROFILE="$(mktemp -d)"
trap 'rm -rf "$PROFILE"' EXIT

# 每行输出「id 宽 高」，来自 <section class="shot" id="…" data-w="…" data-h="…">
frames="$(grep -o '<section class="shot" id="[^"]*" data-w="[0-9]*" data-h="[0-9]*"' index.html \
  | sed -E 's/.*id="([^"]*)" data-w="([0-9]*)" data-h="([0-9]*)"/\1 \2 \3/')"
[[ -n "$frames" ]] || { echo "index.html 中没有找到画框" >&2; exit 1; }

# 先在画廊模式下跑一遍页面：脚本报错或内容超出画框时，页面顶部会出现 .err-line，这时不截图
dom="$("$CHROME" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
  --user-data-dir="$PROFILE" --window-size=1600,1000 --virtual-time-budget=3000 \
  --dump-dom "file://$DIR/index.html" 2>/dev/null || true)"
problems="$(grep -o '<div class="err-line">[^<]*' <<< "$dom" | sed 's/<div class="err-line">//' || true)"
[[ -z "$problems" ]] || { echo "原型检查未通过：" >&2; echo "$problems" >&2; exit 1; }
grep -q 'data-ready="1"' <<< "$dom" || { echo "原型页面没有渲染完成（Chrome 无输出或脚本中断）" >&2; exit 1; }

count=0
while read -r id w h; do
  [[ -z "$ONLY" || "$ONLY" == "${id}" ]] || continue
  rm -f "$OUT/${id}.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check \
    --user-data-dir="$PROFILE" --force-device-scale-factor=2 --window-size="$w,$h" \
    --virtual-time-budget=3000 --screenshot="$OUT/${id}.png" \
    "file://$DIR/index.html?only=${id}" </dev/null >/dev/null 2>&1
  [[ -s "$OUT/${id}.png" ]] || { echo "✗ ${id} 截图失败" >&2; exit 1; }
  echo "✓ ${id}（${w}×${h}）"
  count=$((count + 1))
done <<< "$frames"

[[ $count -gt 0 ]] || { echo "没有这个画框：$ONLY" >&2; exit 1; }
