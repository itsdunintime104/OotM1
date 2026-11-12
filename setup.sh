#!/bin/zsh
# Builds The Legend of Zelda: Ocarina of Time (Switch 2, 0400486024DEC000) as a Mac app with the patches of this repository.
# Usage: ./setup.sh <file.nup> [--check] [--tree <dir>] [--work <dir>] [--no-install]
set -e
autoload -Uz is-at-least

HERE=${0:A:h}; PATCHES=$HERE/patches
REPO_URL=https://github.com/seedds/nxnative.git
BASE=04811a634b7f9344e882129b0973dd493369dd62
APP_NAME="Ocarina of Time.app"
MIN_FREE_GB=80
ROWS_COMMENT="# Rows below from seedds/nxnative#1732 (40,154 entries regenerated on main, recorded through Kokiri Forest, the Great Deku Tree, Hyrule Field, Kakariko Village, Dodongo's Cavern, Zora's Domain, Jabu-Jabu's Belly and the Forest Temple), those not already listed above."

usage() {
  cat <<'EOF'
usage: ./setup.sh <file.nup> [--check] [--tree <dir>] [--work <dir>] [--no-install]
  --check         only check the requirements
  --tree <dir>    folder for the engine source (default ./engine)
  --work <dir>    folder for the extracted game and the shader cache (default: next to the .nup file)
  --no-install    build the app next to the .nup file, not in ~/Applications
EOF
}
die() { print -u2 -- "setup.sh: $*"; exit 1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

NUP= CHECK_ONLY=0 TREE=$PWD/engine WORK= INSTALL=1 TREE_ONLY=0 DEFAULTS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --tree) [ -n "$2" ] || die "--tree needs a folder"; TREE=$2; shift ;;
    --work) [ -n "$2" ] || die "--work needs a folder"; WORK=$2; shift ;;
    --no-install) INSTALL=0 ;;
    --tree-only) TREE_ONLY=1 ;;      # not in the usage: make the engine source only (for checking the patches)
    --no-defaults) DEFAULTS=0 ;;     # not in the usage: leave out 90-m1max-defaults.diff
    -h|--help) usage; exit 0 ;;
    -*) usage; die "unknown option $1" ;;
    *) [ -z "$NUP" ] || die "one .nup file only"; NUP=$1 ;;
  esac
  shift
done
TREE=${TREE:A}

check_requirements() {   # prints each missing requirement with its fix; returns 1 when one is missing
  local miss=() v where free
  [ "$(uname -m)" = arm64 ] || miss+=("a Mac with Apple silicon (this one is $(uname -m))")
  v=$(sw_vers -productVersion 2>/dev/null)
  is-at-least 26.6 "$v" || miss+=("macOS 26.6 or later (this Mac has $v): update macOS in System Settings")
  v=$(xcodebuild -version 2>/dev/null | sed -n 's/^Xcode //p')
  [[ "$v" = 27.2 || "$v" = 27.2.* ]] || miss+=("Xcode 27.2 (found: ${v:-none}): install it, then run: sudo xcode-select -s /Applications/Xcode.app")
  xcrun -sdk macosx metal --version > /dev/null 2>&1 || miss+=("the Metal toolchain: xcodebuild -downloadComponent MetalToolchain")
  command -v git > /dev/null || miss+=("git: xcode-select --install")
  command -v xcodegen > /dev/null || miss+=("xcodegen: brew install xcodegen")
  command -v zstd > /dev/null || miss+=("zstd: brew install zstd")
  command -v glslangValidator > /dev/null || miss+=("glslang: brew install glslang")
  command -v dotnet > /dev/null || miss+=("the .NET SDK: brew install --cask dotnet-sdk")
  python3 -c 'import sys, platform; sys.exit(not (sys.version_info >= (3, 12) and platform.machine() == "arm64"))' 2>/dev/null \
    || miss+=("Python 3.12 or newer for arm64 as python3: brew install python")
  where=${WORK:-${NUP:+${NUP:A:h}}}; where=${where:-$PWD}
  while [ ! -d "$where" ]; do where=${where:h}; done
  free=$(df -k "$where" | awk 'NR==2 { print int($4 / 1048576) }')
  [ "$free" -ge $MIN_FREE_GB ] || miss+=("$MIN_FREE_GB GB of free disk space at $where (free: $free GB)")
  if [ ${#miss} -gt 0 ]; then print "Missing:"; for v in $miss; do print -r -- "  - $v"; done; return 1; fi
  print "Requirements: all found"
}

row_field() { awk -F'\t' -v p="$1" -v n="$2" '$1 == p { print $n; exit }' "$PATCHES/upstream.tsv"; }

fetch() { local c; for c in "$@"; do git -C "$TREE" cat-file -e "$c^{commit}" 2>/dev/null || git -C "$TREE" fetch -q origin "$c" || die "cannot fetch $c from $REPO_URL"; done; }

make_1732() {   # the pipeline manifest rows of pull request 1732 that the base does not list
  local from=$(row_field 01-1732.diff 3) to=$(row_field 01-1732.diff 4) file=$(row_field 01-1732.diff 5) want=$(row_field 01-1732.diff 7) b p made
  fetch "$to"
  b=$(mktemp); p=$(mktemp); made=$(mktemp)
  git -C "$TREE" show "$from:$file" > "$b"; git -C "$TREE" show "$to:$file" > "$p"
  { cat "$b"; print -r -- "$ROWS_COMMENT"; awk 'NR==FNR { seen[$0] = 1; next } !/^#/ && !($0 in seen)' "$b" "$p"; } > "$TREE/$file"
  git -C "$TREE" diff --no-color -- "$file" | normalise > "$made"
  [ "$(sha "$made")" = "$want" ] || die "01-1732.diff made from pull request 1732 does not match its SHA-256 $want"
  git -C "$TREE" add "$file"
  rm -f "$b" "$p" "$made"
}

normalise() { sed -e '/^index [0-9a-f]*\.\.[0-9a-f]*/d' -e 's/^\(@@ [^@]* @@\).*/\1/'; }

apply_upstream() {   # one series entry made from upstream commits, each row of upstream.tsv in turn
  local name=$1 row src from to paths excl want d args x
  awk -F'\t' -v p="$name" '$1 == p' "$PATCHES/upstream.tsv" | while IFS=$'\t' read -r row src from to paths excl want; do
    fetch "$from" "$to"
    d=$(mktemp)
    args=(); [ "$paths" = - ] || args=(${(s:,:)paths})
    git -C "$TREE" diff --no-color "$from" "$to" -- $args | normalise > "$d"
    [ "$(sha "$d")" = "$want" ] || die "$name ($src at $to) does not match its SHA-256 $want"
    args=(); [ "$excl" = - ] || for x in ${(s:,:)excl}; do args+=("--exclude=$x"); done
    git -C "$TREE" apply --index --whitespace=nowarn $args "$d" || die "$name ($src) does not apply"
    rm -f "$d"
    print "applied $name from $src ($to)"
  done
}

make_tree() {
  local p
  if [ -d "$TREE/.git" ]; then
    print "engine source: reusing $TREE (reset to $BASE: changes there are lost)"
  else
    [ ! -e "$TREE" ] || [ -z "$(ls -A "$TREE")" ] || die "$TREE exists and is not a clone of $REPO_URL"
    git clone -q --no-checkout "$REPO_URL" "$TREE"
  fi
  fetch "$BASE"
  git -C "$TREE" -c advice.detachedHead=false checkout -q -f "$BASE"
  git -C "$TREE" clean -fdq -e .venv -e build
  for p in $(<"$PATCHES/series"); do
    if [ "$p" = 01-1732.diff ]; then make_1732; print "applied $p from pull/1732"
    elif [ -n "$(row_field "$p" 1)" ]; then apply_upstream "$p"
    elif [ "$p" = 90-m1max-defaults.diff ] && [ $DEFAULTS = 0 ]; then print "left out $p"
    elif [ -f "$PATCHES/$p" ]; then git -C "$TREE" apply --index --whitespace=nowarn "$PATCHES/$p" || die "$p does not apply"; print "applied $p"
    else die "patches/series names $p, which is neither in patches/ nor in patches/upstream.tsv"
    fi
  done
  print "engine source ready: $TREE"
}

if [ $TREE_ONLY = 1 ]; then command -v git > /dev/null || die "git is missing: xcode-select --install"; make_tree; exit 0; fi
if [ $CHECK_ONLY = 1 ]; then check_requirements; exit $?; fi
[ -n "$NUP" ] || { usage; exit 1; }
[ -f "$NUP" ] || die "no file at $NUP"
NUP=${NUP:A}
check_requirements || die "install what is missing, then run setup.sh again"
pgrep -f "$APP_NAME/Contents/MacOS/" > /dev/null && die "the game is running: quit it first"
make_tree
if [ $INSTALL = 1 ]; then OUT=$HOME/Applications/$APP_NAME; mkdir -p "$HOME/Applications"; else OUT=${NUP:h}/$APP_NAME; fi
args=("$NUP" --platform mac-app --allow-damaged --seen-shaders --progress lines -o "$OUT")
[ -n "$WORK" ] && args+=(--work-dir "${WORK:A}")
( cd "$TREE" && python3 scripts/build_ipa_from_nsp.py "${args[@]}" )
print "app: $OUT"
