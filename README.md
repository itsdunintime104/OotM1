> [!IMPORTANT]
> This project does not include any game files. You need your own copy of Ocarina of Time for Nintendo Switch 2, as a `.nup` file.

<h1 align="center">OotM1</h1>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-black?logo=apple" alt="Platform: macOS on Apple Silicon">
  <img src="https://img.shields.io/badge/status-playable-brightgreen" alt="Status: playable">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0">
</p>

Patches and a setup script that build Ocarina of Time (Switch 2) as a native Mac app, tuned for the M1 Max: the game's own resolution, a 2560 × 1440 picture, 55 to 60 frames a second.

The engine is [seedds/nxnative](https://github.com/seedds/nxnative) at a pinned commit, plus open pull requests of that project and the M1 Max work. Not affiliated with or endorsed by Nintendo.

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Settings](#settings)
- [Performance](#performance)
- [Known faults](#known-faults)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Credits and license](#credits-and-license)

## Requirements

- A Mac with Apple silicon (measured on an M1 Max, 32 GB), macOS 26.6 or later
- Xcode 27.2 with its Metal toolchain
- Homebrew: `xcodegen`, `zstd`, `glslang`, Python 3.12+, .NET SDK 10
- Your own `.nup` file, update 131072
- Free disk space: 80 GB for the work folder (next to the `.nup` file by default) and 40 GB for the app

## Install

```sh
# 1. Xcode 27.2 (open it once first)
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -downloadComponent MetalToolchain

# 2. Tools
brew install xcodegen zstd glslang python@3.14
brew install --cask dotnet-sdk

# 3. This repository, and a check of your Mac
git clone https://github.com/itsdunintime104/OotM1.git
cd OotM1
./setup.sh ~/Games/game.nup --check

# 4. Build (power adapter connected; caffeinate keeps the Mac awake)
caffeinate -i ./setup.sh ~/Games/game.nup
```

The app is installed as **The Legend of Zelda - Ocarina of Time** in `/Applications` (build with an administrator account, or use `--no-install`). `setup.sh` never changes your `.nup` file.

The first build takes about 5 hours with the work folder on a USB hard disk, less on an SSD; most of it is compiling 42,848 shaders. Later builds reuse the extracted game and the shader cache. Keep an external drive connected until the build ends.

| Option | Effect |
|---|---|
| `--check` | Only check the requirements |
| `--tree <dir>` | Engine source folder (default `./engine`) |
| `--work <dir>` | Work folder: extracted game and shader cache (default next to the `.nup` file) |
| `--no-install` | Build the app next to the `.nup` file instead of in `/Applications` |
| `--hud-msl-only` | Write the frame generation HUD shader sources again (see below) |

`tools/check_run.sh <app>` starts the game, goes through the menus, takes a screenshot and prints PASS or FAIL.

## Settings

The settings window opens when the app starts. Defaults (measured best on the M1 Max):

| Setting | Default | Why |
|---|---|---|
| Frame rate | 60 | the game's own target |
| Render scale | 1.0 | 0.75 is faster but visibly softer |
| Game's upscaler | MetalFX | replaces a compute chain that costs 3.2 ms a frame |
| Fullscreen resolution | 2560 × 1440 | the size the game composes its picture at |
| Frame generation | Off | experimental |
| Encode thread, Encode ahead | On | the next frame is translated while the GPU draws the last |
| GPU overlap | Off | the picture flashes with it on |
| Hold frames when late | Off | a late frame is shown late, not held |
| Performance HUD | Off | shows the frame rate |

Also on by default: the 120 Hz display link (`DM_PRESENT_LINK=2`), the async compute window (`DM_NVN_ASYNC_CS=1`) and the scene-change fix (`DM_NVN_POOL_RETIRED=1`). Any setting can be changed in `env.txt` in `~/Library/Application Support/nxnative/0400486024DEC000/`, one `NAME=value` per line, without a rebuild.

### Frame generation

Frame generation needs the source of each HUD shader, which the app does not carry. After each build, `setup.sh` writes the sources of the shaders in `tools/hud_shaders.txt` to `mfx_msl/` in the folder above, and adds the frame generation settings to `env.txt` (it never changes a line you set). If the log names a shader with `no MSL source`, run `./setup.sh <file.nup> --hud-msl-only` and restart the game.

## Performance

M1 Max, 32 GB, power adapter, High Power mode, defaults:

| Place | Frame time, median | 95th percentile |
|---|---|---|
| Kokiri Forest | 16.6 to 16.7 ms (60 fps) | |
| Castle Town market (heaviest) | 16.6 to 18.4 ms | 18.3 to 22 ms |

The GPU is the limit at this resolution. Details, including what did not help: [docs/results.md](docs/results.md).

## Known faults

- **Freezes of up to about 1 s at the first visit to a place**, while the host builds new pipelines. The second visit does not freeze.
- **Hitches of 40 to 200 ms** under memory pressure. Closing browsers and chat apps cut them from 4.4 to under 0.5 per 1,000 frames.
- **Below 60 in the city and in Hyrule Field's grass**, where the GPU is the limit.
- **A white glow on some city textures.** Cause not found.
- Below 60 the game moves in whole 1/60 s steps, so motion can speed up and slow down. Above 60 is not possible yet.
- Frame generation's frame rate can swing between about 70 and 30. A fix for this, and real-time game speed below 60, run in the test build and are not in these patches yet.

## Troubleshooting

| Problem | Fix |
|---|---|
| `setup.sh` stops at the check | Install what it names, then run it again |
| `setup.sh: no file at …` | The `.nup` path is wrong, or its drive is not connected |
| `setup.sh: the build stopped` | The `[RED]` lines above say why; full logs are in the work folder's `logs/`. Fix it and run the same command: finished steps are reused |
| `[RED] … 3 file(s) whose bytes do not start as their names promise` | Normal: the game files have 3 damaged textures, packed as they are |
| `Device not configured` or `database disk image is malformed` | The external drive disconnected. Connect it directly (no hub) and run again |
| The build stopped when the Mac slept | Run it with `caffeinate -i` |
| macOS will not open the app | `codesign -f -s - "/Applications/The Legend of Zelda - Ocarina of Time.app"` |
| Low frame rate or hitches | Power adapter, High Power mode, and close browsers and chat apps |

The game's log is `~/Library/Logs/nxnative/0400486024DEC000.log`; the run before is kept as `.prev.log`.

## Development

- `patches/series` lists the patches in order. Patches with upstream code are made by `setup.sh` from pinned upstream commits and checked by SHA-256 (`patches/upstream.tsv`); `fixup-*.diff` holds only the tested difference.
- Patches 23 and 24 hold the M1 Max work; patch 90 the default settings.
- `setup.sh` resets `engine/` at each run. Save your own change as a patch first, then add it to `patches/series` above `90-m1max-defaults.diff`:
  ```sh
  git -C engine diff > patches/25-my-change.diff
  ```
- To update: `git pull`, then run `./setup.sh` again with the same options.

## Credits and license

- [seedds/nxnative](https://github.com/seedds/nxnative) and the authors of the pull requests in `patches/upstream.tsv`
- Frame generation adapted from MacNativeGames

GPL-3.0, see [LICENSE](LICENSE). Code from the engine, the Ryujinx shader translator and MacNativeGames stays under its MIT license; notices are in [LICENSES/](LICENSES/).
