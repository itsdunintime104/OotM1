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
- Homebrew, with `xcodegen`, `zstd`, `glslang` and the .NET SDK
- Python 3.12 or newer (arm64)
- Your own `.nup` file of the game, with the same update as the tested build (another update may not work)
- About 80 GB of free disk space for the first build (the extracted game and the shader cache are kept for the next build)

## Install

1. Install Xcode 27.2 and select it, then its Metal toolchain:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app
   xcodebuild -downloadComponent MetalToolchain
   ```
2. Install the tools:
   ```sh
   brew install xcodegen zstd glslang python
   brew install --cask dotnet-sdk
   ```
3. Get this repository and run the setup script with your `.nup` file:
   ```sh
   git clone https://github.com/itsdunintime104/OotM1.git
   cd OotM1
   ./setup.sh ~/Games/game.nup
   ```
4. Open **OotM1** from `~/Applications`.

`setup.sh` checks your Mac, downloads the engine at the pinned commit, applies the patches, builds the app from your `.nup` file and installs it. The first build takes 1 to 2 hours, most of it shader compilation. It never changes your `.nup` file.

| Option | Effect |
|---|---|
| `--check` | Only check the requirements |
| `--tree <dir>` | Use this folder for the engine source (default `./engine`) |
| `--work <dir>` | Use this folder for the extracted game and the shader cache (default next to the `.nup` file) |
| `--no-install` | Build the app next to the `.nup` file instead of in `~/Applications` |

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

Playable. The numbers above come from the test build this repository reproduces: `setup.sh --tree-only` gives its engine source exactly (checked on 12 Nov), plus the 6 default settings of `patches/90-m1max-defaults.diff`. A full build through `setup.sh` has not been run yet.

Fixed on 12 Nov (`patches/24-scene-changes-and-movie.diff`):

- **Long slowdowns after scene changes.** After a scene change the host looked up thousands of texture slots a frame that point at textures the game had already freed. A small table overflowed, and the host rebuilt its texture table every frame: 29 to 69 ms of CPU a frame, for up to 15 s. The game never reads such a slot, so the host now gives it a placeholder. In the test runs the worst host CPU time a frame fell from 68.7 ms to 8.3 ms. On by default.
- **Laggy opening movie.** The movie is AV1, which the M1 decodes on the CPU. A slow picture (up to 132 ms) held the game's movie thread, so the movie stopped on one picture. Decoding now runs on its own thread. Pauses over 50 ms fell from 31 to 55 to 1 to 6 per 600 pictures, and the tester called it great.

Known faults:

- **Freezes at the first visit to a place**, up to about 0.7 s. The host builds a new pipeline while the frame waits. The second visit does not freeze. A fix that builds them before the first frame is in patch 24, but it needs two lists made from your own game files, which this repository does not ship (`DM_NVN_MESH_SETS`, `DM_NVN_LIB_TWINS`). Without the lists it does nothing.
- **Hitches of 40 to 200 ms**, where the GPU stops between two frames that are ready. They come with memory pressure: with browsers and chat apps closed, they fell from 4.4 to 0.2 to 0.4 per 1,000 frames. This is a strong sign, not a proof.
- **Below 60 in the city.** The heaviest places are limited by the GPU. Measuring them is the next step.
- **A white glow on some textures in the city**, seen by the tester. The cause is not found yet.
- Below 60 the game moves in whole steps of 1/60 s, so motion can speed up and slow down.
- Frame generation is experimental.
- Above 60 frames a second is not possible yet: the game's time step is handed over in whole 1/60 s steps.

## Troubleshooting

- **`setup.sh` stops at the check.** It names what is missing and how to install it.
- **macOS will not open the app.** Sign it once: `codesign -f -s - ~/Applications/OotM1.app` (takes a few minutes).
- **Low frame rate.** Connect the power adapter and set High Power mode (System Settings → Battery). Close other apps that use the GPU.
- **Hitches.** Close browsers, chat apps and other apps that use a lot of memory. The game uses up to 16 GB of GPU memory in the city, and on a 32 GB Mac the rest can push it into swap.
- **The log.** The game's log is in `~/Library/Logs/nxnative/`, replaced at each start; the run before is kept as `.prev.log`.

## Building and development

- `patches/series` lists the patches in order. Patches that carry upstream code with game code references are not stored here: `setup.sh` makes them from upstream pull requests and commits at pinned commits and checks their SHA-256 (`patches/upstream.tsv`). Where the tested patch differs from the public one, a `fixup-*.diff` in `patches/` holds only the difference.
- `patches/23-test-tree-local-edits.diff` and `patches/24-scene-changes-and-movie.diff` hold the M1 Max work. Patch 24 also adds diagnostics to the log: `DM_NVN_GPUPROF=slow:<ms>` prints the per-pass GPU times of frames that take at least that long, a `[paging]` line reports swap and page-ins, and the movie decoder reports its pauses every 600 pictures.
- `patches/90-m1max-defaults.diff` holds the default settings above.
- Each host change can be switched with its environment variable in `env.txt`, in the game's folder under `~/Library/Application Support/nxnative/`, one `NAME=value` per line.

## Credits

- [seedds/nxnative](https://github.com/seedds/nxnative) and the authors of its pull requests used here (listed in `patches/upstream.tsv`)
- Frame generation adapted from MacNativeGames (MIT license)

## License

GPL-3.0. See [LICENSE](LICENSE).

The patches carry code from projects under the MIT license, which stays theirs: the engine [seedds/nxnative](https://github.com/seedds/nxnative), the shader translator from Ryujinx, and the frame generation from MacNativeGames. Their notices are in [LICENSES/](LICENSES/).
