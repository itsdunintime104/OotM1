#!/bin/zsh
# Starts the app without its launcher, presses A four times, takes a screenshot and reads the game log.
# Prints PASS (frame times logged, frame p50 under 40 ms, screenshot written, no crash) or FAIL with the reason.
# Usage: check_run.sh <app> [title id]   (default title id 0400486024DEC000; quit the game first)
set -e
APP=$1; ID=${2:-${TITLE_ID:-0400486024DEC000}}
[ -n "$APP" ] && [ -d "$APP" ] || { print -u2 "usage: check_run.sh <app> [title id]"; exit 2; }
APP=${APP:A}
pgrep -f "$APP/Contents/MacOS/" > /dev/null && { print -u2 "the game is running: quit it first"; exit 2; }
DATA="$HOME/Library/Application Support/nxnative/$ID"; ENVF="$DATA/env.txt"; LOGF="$HOME/Library/Logs/nxnative/$ID.log"
B='# check_run.sh begin'; E='# check_run.sh end'
TMP=$(mktemp -d); CTL="$TMP/ctl"; PNG="${SHOT:-$PWD/check_run-$ID.png}"; rm -f "$PNG"; : > "$CTL"   # SHOT=<png> sets where the screenshot goes
made_env=0; [ -f "$ENVF" ] || { mkdir -p "$DATA"; : > "$ENVF"; made_env=1; }
strip() { awk -v b="$B" -v e="$E" '$0==b{s=1;next} $0==e{s=0;next} !s' "$ENVF" > "$ENVF.new" && mv "$ENVF.new" "$ENVF"; }
cleanup() {
  pgrep -f "$APP/Contents/MacOS/" > /dev/null && osascript -e "quit app \"$APP\"" > /dev/null 2>&1 || true
  strip; [ $made_env = 1 ] && [ ! -s "$ENVF" ] && rm -f "$ENVF"
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM
strip; { print -r -- "$B"; print -r -- "DM_CTL=$CTL"; print -r -- "DM_FOCUS_KEEP=1"; print -r -- "$E"; } >> "$ENVF"

open "$APP" --args --no-launcher
sleep 30
for i in 1 2 3 4; do print A >> "$CTL"; sleep 6; done
sleep 40
print -r -- "shot $PNG" >> "$CTL"
for i in {1..15}; do [ -s "$PNG" ] && break; sleep 1; done
running=1; pgrep -f "$APP/Contents/MacOS/" > /dev/null || running=0
shot=0; [ -s "$PNG" ] && shot=1

why=()
[ -f "$LOGF" ] || why+=("no game log at ~/Library/Logs/nxnative/$ID.log")
if [ -f "$LOGF" ]; then
  # hle_nvn.c tsummary prints every 300 frames: "[nvn] timing up to frame N: frame time p50 X / p95 Y / max Z ms"
  p50=$(grep -E '\[nvn\] timing up to frame [0-9]+: frame time p50 [0-9.]+' "$LOGF" | tail -1 | sed -E 's/.*frame time p50 ([0-9.]+).*/\1/')
  bad=$(grep -E '\[RED\]|crash|abort|Assertion failed|command buffer execution error' "$LOGF" | grep -v 'failed to load shader' | head -5)
  [ -n "$p50" ] || why+=("no frame-time line ('[nvn] timing up to frame N: frame time p50 <ms>') in the log")
  [ -n "$p50" ] && [ $(( p50 < 40 )) = 0 ] && why+=("frame p50 $p50 ms is not under 40 ms")
  [ -n "$bad" ] && why+=("log has [RED]/crash/abort lines:"$'\n'"$bad")
fi
[ $running = 1 ] || why+=("the game was not running at the screenshot (crash or early exit)")
[ $shot = 1 ] || why+=("no screenshot written")
[ -n "$p50" ] && print "frame p50: $p50 ms"
if [ ${#why} = 0 ]; then print PASS; exit 0; fi
print FAIL; for w in $why; do print -r -- "  - $w"; done; exit 1
