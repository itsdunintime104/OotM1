> [!IMPORTANT]
> This project does not include any game files. You need your own copy of Ocarina of Time for Nintendo Switch 2, as a `.nup` file.

<h1 align="center">OotM1</h1>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-black?logo=apple" alt="Platform: macOS on Apple Silicon">
  <img src="https://img.shields.io/badge/status-playable-brightgreen" alt="Status: playable">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0">
</p>

A set of patches and one setup script that build Ocarina of Time (Switch 2) as a native Mac app, tuned for a MacBook Pro with M1 Max. It runs at the game's own resolution with a 2560 × 1440 picture at about 55 to 60 frames a second.

The engine is [seedds/nxnative](https://github.com/seedds/nxnative). This repository pins one of its commits, adds open pull requests of that project and the M1 Max work on top, and sets the app's default settings to the ones that measured best.

This project is not affiliated with or endorsed by Nintendo.

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Settings](#settings)
- [Performance](#performance)
- [Status](#status)
- [Troubleshooting](#troubleshooting)
- [Building and development](#building-and-development)
- [Credits](#credits)
- [License](#license)

## Requirements

- A Mac with Apple silicon. Tuned and measured on an M1 Max (32 GB). Other chips work, at their own speed.
- macOS 26.6 or later
- Xcode 27.2, with its Metal toolchain
- Homebrew, with `xcodegen`, `zstd`, `glslang`, Python 3.12 or newer and the .NET SDK 10. The .NET SDK builds the shader translator: OotM1's patches change its source, so `setup.sh` builds it on your Mac.
- Your own `.nup` file of the game, with the same update as the tested build (update 131072; another update may not work)
- Free disk space: about 80 GB for the work folder (the extracted game and the shader cache, kept for the next build) and about 40 GB for the app (it is about 35 GB). By default the work folder is next to the `.nup` file and the app goes to `/Applications`. `setup.sh --check` tells you if there is not enough.

## Install

1. Install Xcode 27.2 from the App Store or developer.apple.com, open it once, then select it and add its Metal toolchain:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app
   xcodebuild -downloadComponent MetalToolchain
   ```
2. Install the tools with [Homebrew](https://brew.sh):
   ```sh
   brew install xcodegen zstd glslang python@3.14
   brew install --cask dotnet-sdk
   ```
3. Get this repository and check your Mac:
   ```sh
   git clone https://github.com/itsdunintime104/OotM1.git
   cd OotM1
   ./setup.sh ~/Games/game.nup --check
   ```
   It prints the Python it will use and `Requirements: all found`, or a list of what is missing with the command that installs each item.
4. Connect the power adapter and build. `caffeinate -i` keeps the Mac awake until the build ends:
   ```sh
   caffeinate -i ./setup.sh ~/Games/game.nup
   ```
5. When it prints `app: /Applications/The Legend of Zelda - Ocarina of Time.app`, open **The Legend of Zelda - Ocarina of Time** from Applications or Launchpad. The app goes into `/Applications`, so build with an administrator account (or use `--no-install`). A build made before 15 Nov is at `~/Applications/OotM1.app`: move it to the Trash.

`setup.sh` never changes your `.nup` file. If the `.nup` file or the work folder is on an external drive, keep the drive connected until the build ends.

### What the build does, and how long it takes

Measured on an M1 Max on 14 Nov, with the `.nup` file and the work folder on a USB hard disk. The first build takes about 5 hours there; an SSD is faster. Most of it is step 4.

| Step | First build | Next builds |
|---|---|---|
| Engine source, Python packages (in `engine/.venv`) and shader translator | about 5 min | under 1 min |
| [1] Unpack the game, then check its files | about 30 min | about 3 min (only the check) |
| [2] Rewrite the game's code | about 1 min | reused |
| [3] Shader split: 42,848 shaders | about 16 min | about 16 min (a split made with damaged game files is never reused) |
| [4] Mac shaders: translate and compile all of them, then write the library | about 3 h (measured: 26,784 shaders in 1 h 43 min, then 19 min to write the 6.6 GB library) | only the changed ones |
| [5] Mac host | under 1 min | under 1 min |
| [6] Pipeline archive for your GPU | about 46 min (3.8 GB) | only when its inputs changed |
| [7] Copy the game files into the app and sign it | about 14 min | about 14 min |

Each step prints a progress line every 30 seconds with its own time estimate. A step whose inputs did not change says `reused (inputs unchanged)`.

### Messages you will see

| Message | What it means |
|---|---|
| `python packages: installed into …/engine/.venv` | The first run made a Python environment for the build. Your own Python is not changed. |
| `shader translator: building it from the patched source` | Normal at every run. It takes a few seconds. |
| `[RED] … 3 file(s) whose bytes do not start as their names promise` | The tested game files have 3 damaged textures (a Fairy Fountain floor, a Ganon stage texture, a Water Temple gate). The build packs them as they are and goes on. |
| `setup.sh: no file at …` | The `.nup` file is not at that path. If it is on an external drive, check that the drive is connected (Finder shows it). |
| `setup.sh: the build stopped: …` | A step failed. The `[RED]` lines above it say why, and the step's full log is in the work folder's `logs/` folder. Fix the cause and run the same command again: the finished steps are reused. |

### Options

| Option | Effect |
|---|---|
| `--check` | Only check the requirements |
| `--tree <dir>` | Use this folder for the engine source (default `./engine`) |
| `--work <dir>` | Use this folder for the extracted game and the shader cache (default next to the `.nup` file) |
| `--no-install` | Build the app next to the `.nup` file instead of in `/Applications` |

After a build, `tools/check_run.sh <app>` starts the game, goes in through the menus, takes a screenshot and reads the log. It prints PASS or FAIL.

## Settings

The settings window opens when the app starts. Its defaults are the settings that measured best on the M1 Max:

| Setting | Default | Why |
|---|---|---|
| Frame rate | 60 | the game's own target |
| Render scale | 1.0 | the game's own resolution. 0.75 is faster but visibly softer |
| Game's upscaler | MetalFX | replaces a compute chain of the game that costs 3.2 ms a frame |
| Fullscreen resolution | 2560 × 1440 | the size the game composes its picture at |
| Frame generation | Off | experimental: ghosts, and it costs real frames at this resolution |
| Encode thread | On | Encode ahead needs it |
| Encode ahead | On | translates the next frame while the GPU still draws the last one |
| GPU overlap | Off | the picture flashes with it on |
| Hold frames when late | Off | a late frame is shown late rather than held |
| Performance HUD | Off | turn it on to see the frame rate |

Three host settings are on by default and have no row:

- the 120 Hz display link (`DM_PRESENT_LINK=2`)
- the async compute window (`DM_NVN_ASYNC_CS=1`): runs some of the game's compute work beside its draw passes
- freed-texture IDs get a placeholder (`DM_NVN_POOL_RETIRED=1`): fixes the long slowdowns after scene changes (see [Status](#status))

## Performance

MacBook Pro 16-inch, M1 Max, 32 GB, macOS 26.6, power adapter connected, High Power mode, windowed, Kokiri Forest, the defaults above:

| Measure | Result |
|---|---|
| Frame time, median | 16.6 to 16.7 ms (the 60 Hz limit) in the latest runs; 17.4 to 18.4 ms in earlier runs of the same build |
| Frames a second | about 55 to 60 |
| GPU busy | about 72 % of the time |

Hyrule Castle Town market, the heaviest place measured so far: frame time median 16.6 to 18.4 ms, 95th percentile 18.3 to 22 ms, about 17.3 ms of GPU time a frame.

The GPU is the limit at this resolution. The work behind these numbers, including what did not help, is in [docs/results.md](docs/results.md).

## Status

Playable. The numbers above come from the test build this repository reproduces: `setup.sh --tree-only` gives its engine source exactly (checked on 12 Nov), plus the 6 default settings of `patches/90-m1max-defaults.diff`. On 14 Nov a full build through `setup.sh` on an M1 Max passed `tools/check_run.sh`: 60 frames a second at the start and no missing shaders.

Fixed on 12 Nov (`patches/24-scene-changes-and-movie.diff`):

- **Long slowdowns after scene changes.** After a scene change the host looked up thousands of texture slots a frame that point at textures the game had already freed. A small table overflowed, and the host rebuilt its texture table every frame: 29 to 69 ms of CPU a frame, for up to 15 s. The game never reads such a slot, so the host now gives it a placeholder. In the test runs the worst host CPU time a frame fell from 68.7 ms to 8.3 ms. On by default.
- **Laggy opening movie.** The movie is AV1, which the M1 decodes on the CPU. A slow picture (up to 132 ms) held the game's movie thread, so the movie stopped on one picture. Decoding now runs on its own thread. Pauses over 50 ms fell from 31 to 55 to 1 to 6 per 600 pictures, and the tester called it great.

### In the test build, not yet in these patches (13 Nov)

The work below runs in the test build. It is not in `patches/` yet, so `setup.sh` does not build it.

- **Frame generation pacing.** With frame generation on, the frame rate swung between about 70 and 30 frames a second. The host counted the frame generation's GPU time wrongly, so it held frames it did not need to hold. It now counts the frame generation's measured work, and the time the GPU is busy rather than the sum of buffers that overlap. In Hyrule Field the result was a steady 30 + 30, with no hold changes (17 to 30 before). The tester found that locked rate choppy and preferred the variable one, so holding stays a setting.
- **Real-time game speed below 60.** The game's time step now follows the measured frame time, not whole 1/60 s steps. In Hyrule Field with frame generation on, game time ran at 0.97 to 0.99 of real time at about 43 real frames a second. Off by default.
- **Smaller host fixes.** Queue work held back at loads now runs on the encode thread, not on the game's thread. Shared textures that nothing has used for 600 submissions are released.
- **Measured: Hyrule Field's grass is limited by the GPU.** A frame's GPU work spans 15.6 to 17.8 ms, and the GPU is idle for about 5 ms of it. The cause of that idle time is not found yet. A steady 60 + 60 with frame generation needs about 5 ms less GPU time per real frame.

Known faults:

- **Freezes at the first visit to a place**, up to about 0.7 s. The host builds a new pipeline while the frame waits. The second visit does not freeze. A fix that builds them before the first frame is in patch 24, but it needs two lists made from your own game files, which this repository does not ship (`DM_NVN_MESH_SETS`, `DM_NVN_LIB_TWINS`). Without the lists it does nothing.
- **Hitches of 40 to 200 ms**, where the GPU stops between two frames that are ready. They come with memory pressure: with browsers and chat apps closed, they fell from 4.4 to 0.2 to 0.4 per 1,000 frames. This is a strong sign, not a proof.
- **Below 60 in the city and in Hyrule Field's grass.** These places are limited by the GPU (see above).
- **A white glow on some textures in the city**, seen by the tester. The cause is not found yet.
- Below 60 the game moves in whole steps of 1/60 s, so motion can speed up and slow down. The test build fixes this (see above).
- Frame generation is experimental. Its frame rate can swing between about 70 and 30. The test build fixes this (see above).
- Above 60 frames a second is not possible yet: the game's time step is handed over in whole 1/60 s steps.

## Troubleshooting

- **`setup.sh` stops at the check.** It names what is missing and the command that installs it. Install it and run the same command again.
- **The build stops.** The `[RED]` lines above `setup.sh: the build stopped` say why. Each step's full log is in the work folder's `logs/` folder. Run the same command again after the fix: the finished steps are reused.
- **`Device not configured` or `database disk image is malformed`.** The external drive with the work folder disconnected during the build. Connect it straight to the Mac (no hub), and run the same command again. A damaged shader cache is made anew, so step 4 starts over.
- **The Mac went to sleep and the build stopped.** Start it with `caffeinate -i` in front, as in the install steps.
- **macOS will not open the app.** Sign it once: `codesign -f -s - "/Applications/The Legend of Zelda - Ocarina of Time.app"` (takes a few minutes).
- **Low frame rate.** Connect the power adapter and set High Power mode (System Settings → Battery). Close other apps that use the GPU.
- **Hitches.** Close browsers, chat apps and other apps that use a lot of memory. The game uses up to 16 GB of GPU memory in the city, and on a 32 GB Mac the rest can push it into swap.
- **The log.** The game's log is in `~/Library/Logs/nxnative/`, replaced at each start; the run before is kept as `.prev.log`.

## Building and development

- `patches/series` lists the patches in order. Patches that carry upstream code with game code references are not stored here: `setup.sh` makes them from upstream pull requests and commits at pinned commits and checks their SHA-256 (`patches/upstream.tsv`). Where the tested patch differs from the public one, a `fixup-*.diff` in `patches/` holds only the difference.
- `patches/23-test-tree-local-edits.diff` and `patches/24-scene-changes-and-movie.diff` hold the M1 Max work. Patch 24 also adds diagnostics to the log: `DM_NVN_GPUPROF=slow:<ms>` prints the per-pass GPU times of frames that take at least that long, a `[paging]` line reports swap and page-ins, and the movie decoder reports its pauses every 600 pictures.
- `patches/90-m1max-defaults.diff` holds the default settings above.
- Each host change can be switched with its environment variable in `env.txt`, in the game's folder under `~/Library/Application Support/nxnative/`, one `NAME=value` per line.

### Rebuild after a change

- **New patches from this repository.** Run `git pull`, then run `./setup.sh` again with the same `.nup` file and the same options (the same `--work` folder, if you gave one). The build reuses the extracted game and the shader cache, and skips the steps whose inputs did not change.
- **Your own change to the engine.** `setup.sh` resets `engine/` to the pinned commit and applies `patches/series` again, so a change made in `engine/` is lost at the next run. Save it as a patch first:
  ```sh
  git -C engine diff > patches/25-my-change.diff
  ```
  Then add `25-my-change.diff` to `patches/series`, above `90-m1max-defaults.diff`, and run `./setup.sh` again. `git diff` holds only your change, because `setup.sh` stages the patches it applies.
- **Settings only.** A change to `env.txt` needs no rebuild. It applies at the next start of the game.

## Credits

- [seedds/nxnative](https://github.com/seedds/nxnative) and the authors of its pull requests used here (listed in `patches/upstream.tsv`)
- Frame generation adapted from MacNativeGames (MIT license)

## License

GPL-3.0. See [LICENSE](LICENSE).

The patches carry code from projects under the MIT license, which stays theirs: the engine [seedds/nxnative](https://github.com/seedds/nxnative), the shader translator from Ryujinx, and the frame generation from MacNativeGames. Their notices are in [LICENSES/](LICENSES/).
