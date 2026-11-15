#!/bin/zsh
# Builds OotM1 (Switch 2) as a Mac app with the patches of this repository.
# Usage: ./setup.sh <file.nup> [--check] [--tree <dir>] [--work <dir>] [--no-install] [--hud-msl-only]
set -e
autoload -Uz is-at-least

HERE=${0:A:h}; PATCHES=$HERE/patches
REPO_URL=https://github.com/seedds/nxnative.git
BASE=04811a634b7f9344e882129b0973dd493369dd62
APP_NAME="The Legend of Zelda - Ocarina of Time.app"   # a file name cannot hold ':'; the name inside the app is "The Legend of Zelda: Ocarina of Time"
APP_DIR=/Applications
OLD_APP=$HOME/Applications/OotM1.app   # where builds before 15 Nov went
TITLE_ID=0400486024DEC000
SUPPORT="$HOME/Library/Application Support/nxnative/$TITLE_ID"   # the game's own folder: save, env.txt, and the HUD shader sources for frame generation
GAME_LOG=$HOME/Library/Logs/nxnative/$TITLE_ID.log
MIN_FREE_GB=80
APP_FREE_GB=40                    # the app is about 35 GB
ROWS_COMMENT="# Rows below from seedds/nxnative#1732 (40,154 entries regenerated on main, recorded through Kokiri Forest, the Great Deku Tree, Hyrule Field, Kakariko Village, Dodongo's Cavern, Zora's Domain, Jabu-Jabu's Belly and the Forest Temple), those not already listed above."

usage() {
  cat <<'EOF'
usage: ./setup.sh <file.nup> [--check] [--tree <dir>] [--work <dir>] [--no-install] [--hud-msl-only]
  --check         only check the requirements
  --tree <dir>    folder for the engine source (default ./engine)
  --work <dir>    folder for the extracted game and the shader cache (default: next to the .nup file)
  --no-install    build the app next to the .nup file, not in /Applications
  --hud-msl-only  after a build: write frame generation's HUD shader sources again, adding those the last game logs name
EOF
}
die() { print -u2 -- "setup.sh: $*"; exit 1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

NUP= CHECK_ONLY=0 TREE=$PWD/engine WORK= INSTALL=1 TREE_ONLY=0 VENV_ONLY=0 TRANSLATOR_ONLY=0 HUD_ONLY=0 DEFAULTS=1 PY= PYV=
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --tree) [ -n "$2" ] || die "--tree needs a folder"; TREE=$2; shift ;;
    --work) [ -n "$2" ] || die "--work needs a folder"; WORK=$2; shift ;;
    --no-install) INSTALL=0 ;;
    --tree-only) TREE_ONLY=1 ;;      # not in the usage: make the engine source only (for checking the patches)
    --venv-only) VENV_ONLY=1 ;;      # not in the usage: make the Python environment only
    --translator-only) TRANSLATOR_ONLY=1 ;;   # not in the usage: make the engine source, the Python environment and the shader translator only
    --no-defaults) DEFAULTS=0 ;;     # not in the usage: leave out 90-m1max-defaults.diff
    --hud-msl-only) HUD_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; die "unknown option $1" ;;
    *) [ -z "$NUP" ] || die "one .nup file only"; NUP=$1 ;;
  esac
  shift
done
TREE=${TREE:A}

find_python() {   # sets PY and PYV to the first Python that is arm64 and 3.12 or newer; returns 1 when there is none
  local c p3 cands=()
  if [ -n "$OOTM1_PYTHON" ]; then cands=("$OOTM1_PYTHON")      # set: the only candidate
  else p3=$(command -v python3) || p3=; cands=(/opt/homebrew/bin/python3.14 /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3 $p3); fi   # 3.14 first: newer ones may lack package wheels
  for c in $cands; do
    if [ -x "$c" ] && "$c" -c 'import sys, platform; sys.exit(not (sys.version_info >= (3, 12) and platform.machine() == "arm64"))' 2>/dev/null; then
      PY=$c; PYV=$("$c" -c 'import platform; print(platform.python_version())'); return 0
    fi
  done
  return 1
}

check_requirements() {   # prints each missing requirement with its fix; returns 1 when one is missing
  local miss=() v where app free
  [ -z "$NUP" ] || [ -f "$NUP" ] || miss+=("the .nup file at $NUP (not found; if it is on an external drive, connect the drive)")
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
  if find_python; then print "Python: $PY ($PYV)"
  else miss+=("Python 3.12 or newer for arm64: brew install python@3.14 (or set OOTM1_PYTHON to one)${OOTM1_PYTHON:+; OOTM1_PYTHON is $OOTM1_PYTHON, which is not one}"); fi
  where=${WORK:-${NUP:+${NUP:A:h}}}; where=${where:-$PWD}
  while [ ! -d "$where" ]; do where=${where:h}; done
  if [ $INSTALL = 1 ]; then app=$APP_DIR; else app=${NUP:+${NUP:A:h}}; app=${app:-$PWD}; fi
  [ $INSTALL = 0 ] || [ -w "$APP_DIR" ] || miss+=("write access to $APP_DIR (this account is not an administrator): ask an administrator to run setup.sh, or use --no-install to build the app next to the .nup file")
  while [ ! -d "$app" ]; do app=${app:h}; done
  free=$(df -k "$where" | awk 'NR==2 { print int($4 / 1048576) }')
  if [ -n "$NUP" ] && [ ! -f "$NUP" ]; then :   # no .nup there: the free space of the folder above it says nothing
  elif [ "$(df -k "$where" | awk 'NR==2 { print $1 }')" = "$(df -k "$app" | awk 'NR==2 { print $1 }')" ]; then   # one volume for both: add the two needs
    [ "$free" -ge $((MIN_FREE_GB + APP_FREE_GB)) ] || miss+=("$((MIN_FREE_GB + APP_FREE_GB)) GB of free disk space at $where for the work folder and the app (free: $free GB); or use --no-install to build the app next to the .nup file")
  else
    [ "$free" -ge $MIN_FREE_GB ] || miss+=("$MIN_FREE_GB GB of free disk space at $where (free: $free GB)")
    free=$(df -k "$app" | awk 'NR==2 { print int($4 / 1048576) }')
    [ "$free" -ge $APP_FREE_GB ] || miss+=("$APP_FREE_GB GB of free disk space for the app at $app (free: $free GB); or use --no-install to build it next to the .nup file")
  fi
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

make_venv() {   # the build's Python packages in $TREE/.venv, made with $PY
  local v=$TREE/.venv chk='import sys, lz4.block, capstone, fontTools, zbic
if sys.version_info < (3, 14): import backports.zstd'
  if [ -x "$v/bin/python3" ] && "$v/bin/python3" -c "$chk" 2>/dev/null; then print "python packages: ready ($v)"; return 0; fi
  "$PY" -m venv --clear "$v" || die "cannot make the Python environment at $v with $PY"   # --clear: a broken one is made again
  # pinned to the versions the 14 Nov build was tested with; backports.zstd (Python before 3.14 only) was not part of that test
  "$v/bin/python3" -m pip install -q lz4==4.4.5 capstone==5.0.9 fonttools==4.68.0 zbic==1.0.1.post1 'backports.zstd; python_version < "3.14"' \
    || die "cannot install the build's Python packages (see the pip output above); check the internet connection and run setup.sh again"
  print "python packages: installed into $v"
}

# OotM1's patches change the translator's source; a dotnet build never gives the fingerprints of the one the lock was made with (engine AGENTS.md), so each machine builds its own and records it.
make_translator() {   # the shader translator built from the patched source and recorded in the lock
  local py=$TREE/.venv/bin/python3 lock=dm/gfx/tools/tool_lock.py
  if ( cd "$TREE" && "$py" $lock --check-tools > /dev/null 2>&1 ); then print "shader translator: matches the lock"; return 0; fi
  print "shader translator: building it from the patched source (dotnet publish, about a minute the first time)"
  ( cd "$TREE" && dotnet publish dm/gfx/tools/dmsh_xlate/dmsh_xlate.csproj -c Release -r osx-arm64 --self-contained false -o dm/gfx/tools/dmsh_xlate_bin -nologo -v quiet ) \
    || die "cannot build the shader translator with dotnet (see above); check that the .NET SDK 10 is installed: brew install --cask dotnet-sdk"
  ( cd "$TREE" && "$py" $lock --update-lock > /dev/null ) || die "cannot record the shader translator in the lock"
  ( cd "$TREE" && "$py" $lock --check-tools > /dev/null 2>&1 ) || die "the shader translator still does not match the lock after a rebuild"
  print "shader translator: built and recorded in the lock"
}

# Frame generation draws the HUD on a layer of its own: the host compiles a copy of each HUD shader from its MSL, which the app does not carry.
# The sources come from the build's shader cache (tools/export_hud_msl.py), and env.txt names their folder (DM_MFX_MSL_DIR). A failure here leaves the game as it is.
make_hud_msl() {
  local work=${WORK:+${WORK:A}} dest=$SUPPORT/mfx_msl
  work=${work:-${NUP:h}/${TITLE_ID}_build}
  if [ ! -f "$work/shader/cache/cas.db" ]; then print "frame generation: no shader cache at $work/shader/cache: HUD shader sources not written"; return 0; fi
  DM_GAME=$TITLE_ID "$TREE/.venv/bin/python3" "$HERE/tools/export_hud_msl.py" "$TREE" "$work/shader/cache/cas.db" "$HERE/tools/hud_shaders.txt" "$dest" "$GAME_LOG" "${GAME_LOG:r}.prev.log" \
    || { print "frame generation: the HUD shader sources could not be written (see above); the game runs, but frame generation makes no frames"; return 0; }
  mkdir -p "$SUPPORT"
  env_line DM_MFX_MSL_DIR "$dest" "the HUD shader sources"
  env_line DM_MFX_CAMERA vertex:0:13568 "the game's camera block (vertex uniform slot 0, 13568 bytes), measured with the host's DM_MFX_PROBE"
  env_line DM_MFX_SCENE_FIRST 1 "the 3D scene is the first pass of a frame"
  env_line DM_MFX_DEPTH 1:1000 "the depth range (near 1, far 1000)"
}

env_line() {   # NAME VALUE WHY: adds NAME=VALUE to env.txt when env.txt does not set NAME; names a different value without changing it
  local envf=$SUPPORT/env.txt have
  have=$(sed -n "s/^$1=//p" "$envf" 2>/dev/null | head -1)   # empty when env.txt or the line is not there
  if [ -z "$have" ]; then { print "# Frame generation: $3 (written by setup.sh)"; print -r -- "$1=$2"; } >> "$envf"; print "frame generation: $1 added to $envf"
  elif [ "$have" != "$2" ]; then print "frame generation: $envf sets $1=$have, not $2; frame generation may make no frames with it"; fi
}

if [ $VENV_ONLY = 1 ]; then find_python || die "Python 3.12 or newer for arm64: brew install python@3.14 (or set OOTM1_PYTHON to one)"; make_venv; exit 0; fi
if [ $TREE_ONLY = 1 ]; then command -v git > /dev/null || die "git is missing: xcode-select --install"; make_tree; exit 0; fi
if [ $TRANSLATOR_ONLY = 1 ]; then find_python || die "Python 3.12 or newer for arm64: brew install python@3.14 (or set OOTM1_PYTHON to one)"; make_tree; make_venv; make_translator; exit 0; fi
if [ $CHECK_ONLY = 1 ]; then check_requirements; exit $?; fi
if [ $HUD_ONLY = 1 ]; then   # the engine source and its Python environment as the last build left them; the work folder from --work or the .nup's folder
  [ -n "$NUP$WORK" ] || die "--hud-msl-only needs the .nup file or --work, to find the work folder"
  [ -x "$TREE/.venv/bin/python3" ] || die "no engine source with its Python environment at $TREE: run a full build first"
  NUP=${NUP:+${NUP:A}}; make_hud_msl; exit 0
fi
[ -n "$NUP" ] || { usage; exit 1; }
[ -f "$NUP" ] || die "no file at $NUP"
NUP=${NUP:A}
check_requirements || die "install what is missing, then run setup.sh again"
pgrep -f "$APP_NAME/Contents/MacOS/" > /dev/null && die "the game is running: quit it first"
make_tree
make_venv
make_translator
if [ $INSTALL = 1 ]; then OUT=$APP_DIR/$APP_NAME; else OUT=${NUP:h}/$APP_NAME; fi
args=("$NUP" --platform mac-app --allow-damaged --progress lines -o "$OUT")
[ -n "$WORK" ] && args+=(--work-dir "${WORK:A}")
( cd "$TREE" && PATH="$TREE/.venv/bin:$PATH" "$TREE/.venv/bin/python3" scripts/build_ipa_from_nsp.py "${args[@]}" ) || die "the build stopped: the [RED] lines above say why; each step's full log is in the work folder's logs/ folder"
make_hud_msl
print "app: $OUT"
if [ -d "$OLD_APP" ]; then print "An older build is still at $OLD_APP. It is not used any more: move it to the Trash to free about 35 GB."; fi
