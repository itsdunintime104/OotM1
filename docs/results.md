# OotM1: state of the test work on an M1 Max

Status on 2026-11-11, with the results of 12 Nov added in "Results of 12 Nov: scene changes, the opening movie and the city". The results of 17 to 19 Nov are in their own section and describe the branch `experimental`. This page describes a private test tree, not the released app. Most of the settings named here are not in this repository's `main` yet. The table in "What the test tree holds" says which.

- Game: Ocarina of Time (Switch 2).
- Machine: MacBook Pro with M1 Max, 32 GB, 120 Hz variable refresh screen, macOS 26.6.
- Test conditions from 11 Nov 02:25: power adapter connected, High Power mode, windowed, the same place in the game. Earlier runs were at least partly on battery. Their power state is not known, and that includes the 10 Nov baseline and the logged frame generation run.
- Goal: a steady 60 frames a second, or motion that feels like it.

## Where it stands

| Date | Frame time | Frames a second | Source |
|---|---|---|---|
| 10 Nov, start | 28.0 ms | 35.8 | run log |
| 11 Nov, run B | mean 18.7 ms, blocks of 300 frames from 16.7 to 20.9 ms | 53 | run log |
| 11 Nov, Render scale 0.75 | not logged | 40 to 56 | the tester read the HUD, and the log of that run was lost |

| 11 Nov, build 5, Render scale 1.0 | mean 18.4 ms over 3,600 frames | 54 | run log |
| 11 Nov, build 5, Render scale 0.75 | 16.7 to 17.4 ms in five blocks of 300 frames, about 25 s of play | 60 | run log |

Build 5 is the test tree with pull request 1929, the early depth tests and the shared command allocator. The table "What the test tree holds" lists them.

60 frames a second needs 16.7 ms. At the game's own resolution the game does not hold it yet. Two faults remain:

- Hitches of 95 to 204 ms, a few each minute.
- Uneven motion below 60. The game moves in whole steps of 1/60 s. A late frame is paid back later by a double step. In run B 514 of 1,800 frames took a double step, and each was shown about as long as a single one. The average speed is right (1.000 of real time), but the motion speeds up and slows down. After a hitch the debt is paid as a burst, which looks like fast forward.

## Settings used in the test build

| Setting | Value | Why |
|---|---|---|
| Frame rate | 60 | the game's own target |
| Game's upscaler | MetalFX | replaces a compute chain of the game that cost 3.2 ms a frame |
| Render scale | 0.75 | draws the 3D views smaller. The HUD still says 1440p. The game composes its final picture at 2560 x 1440, and the scale changes only the 3D views |
| Encode thread | On | Encode ahead needs it |
| Encode ahead | On | translates the next frame while the GPU still draws the last one |
| Frame generation | Off | experimental, see below |
| GPU overlap | Off | the picture flashes with it on (see "The model") |

Frame generation is in the test build and is not ready:

- 30 + 30 holds the game at 30 and MetalFX makes one frame between two. On the adapter in High Power the tester called it "amazing". It has no logged numbers. It seems to turn off during talk with a character, and the cause is not known.
- Uncapped, one logged run on 10 Nov at a 1080p output: real frames fell from about 41 to between 32 and 36 a second, 65 to 72 were shown, and MetalFX cost 4.1 ms a frame. The tester saw 70 to 80 on the HUD and said it was not smooth and had some input lag.
- Open faults from the first runs: the picture shakes at the border between the scene and the HUD, and some generated frames show ghosts.
- Since 11 Nov the Uncapped mode also holds late frames, so the game steps evenly at 60 or 30.
- Since 11 Nov frame generation runs with the encode thread. One run: 300 of 300 frames interpolated, no generated frame dropped, clean exit. MetalFX cost 3.7 to 3.8 ms a frame there.
- Uncapped at Render scale 1.0 (build 5): the game fell to 31 real frames a second and the tester saw ghosts. The generated frame costs GPU time, and the real frame was already at the limit.
- Uncapped at Render scale 0.75 with the encode thread: 60 real frames were not held. Six tries at a hold of one refresh failed with a real frame of 17.0 to 19.4 ms, and it fell back to 30 + 30.
- MetalFX makes one frame between two real frames. On a fixed 120 Hz link only 60 + 60 and 30 + 30 give even spacing.
- The tester rejected Render scale 0.75 as the answer: the picture is visibly softer. The target is the game's own resolution.

## What the test tree holds

"In main" means this repository's `main` at engine pin `ab41d6a`.

| Change | Source | In main | Measured here |
|---|---|---|---|
| 120 Hz display link (`DM_PRESENT_LINK=2`) | engine switch | yes | part of the gain from 28.0 to 18.7 ms, not separated |
| Shaders read global memory at Metal's own addresses | upstream pull request 1833, open | no | GPU time 22.66 to 20.62 ms a frame, run log |
| MetalFX takes the game's own upscaler | upstream pull request 1951, open | no | removes a 3.2 ms compute chain, run log |
| Render scale for this game | upstream pull request 1903, open | no | 40 to 56 frames a second at 0.75 by the tester, no log |
| Border corrections compiled out of pipelines that do not need them | upstream pull request 1929, closed | no | not measured here. Upstream reports 1.8 ms less on an M4 Air |
| Early depth tests from the shader's own flag | upstream commit `a888e668` | yes | not measured here |
| One command allocator shared by a frame's submissions | upstream commit `fd8188c9` | no | in build 5: no allocator wait, and hitches remain (2 in 3,600 frames). So the allocator pool was not their cause |
| Encode ahead (`DM_NVN_PREENCODE`) | written in the test tree | no | part of the gain from 28.0 to 18.7 ms, not separated |
| Frame generation (`DM_MFX_INTERP`) | adapted from MacNativeGames (MIT license) | no | one logged run of the Uncapped mode, see "Settings used in the test build". Not ready |
| GPU overlap (`DM_NVN_SYNC_LAG`) | written in the test tree, experiment only | no | build 5 at Render scale 1.0: 18.1 ms against 18.4 ms, and the picture flashed. Stopped: the gain is under the 1.5 ms gate |
| Frame generation with the encode thread | written in the test tree | no | see "Settings used in the test build" |
| Copy seam switch (`DM_NVN_COPY_SEAM`, off by default) | written in the test tree, experiment only | no | never acted in the test run. See "Results of 11 Nov" |

What did not help, each measured: fewer or merged submissions, the encode thread on or off, the GPU clock held at its top frequency, GPU overlap, and the copy seam switch.

The changes written in the test tree are in [`patches/`](../patches/series) (21 to 24, and 90 for the default settings).

## Results of 11 Nov (build 5, the game's own resolution)

Where the GPU time of one frame goes, from the host's per-pass profile of four frames:

- The CPU has encoded the frame after 7.6 ms. The GPU ends it after 15.9 ms and works the whole time. The GPU is the limit.
- The frame has about 110 draw passes and about 30 compute or copy steps. The per-pass timer starts after a pass's vertex stage. 11.4 ms lie inside the timers, and 4.5 ms lie before passes start. That part is most likely vertex and mesh work that waits for earlier work. Upstream's trace on an M4 Pro shows the same split.
- About 30 draw passes a frame start behind a full wait: about 25 after a compute or copy step, about 5 after a barrier of the game. The other 80 start without it.
- Read in the game's code: after every compute dispatch and every texture copy the game asks that later vertex work waits. It is one generic pattern of the engine. So these waits are the game's request, and the host may drop one only with its own proof that the next pass does not read what was written.

The copy seam switch tried that for passes that follow only texture copies. It failed:

- In the test run it never acted. A dump of one frame shows why: the game makes 2 texture copies a frame, and of 99 gaps between passes only 1 holds nothing but a copy. 50 hold only barriers and state changes, 33 hold uniform data updates, and 17 hold compute dispatches.
- The assumption behind the switch (most copy steps between passes are texture copies) was not checked against such a dump before the switch was built.
- The same run compared "every pass waits" with the normal state: 18.4 ms against 17.5 ms as the median of 15 phases each. Two states that ran identical code differed by 1.0 ms, and the scene moved during the run. So this run does not show whether overlap of vertex and fragment work shortens the frame on this GPU.

Later the same day, from the same data and three more runs:

- Overlap does help. The profiled frames of that run give the GPU's time for one frame directly, and two states that ran identical code agree within 0.15 ms: 18.1 ms with every pass waiting, 15.9 and 16.1 ms in the normal state. The 80 passes a frame that start without the full wait save about 2.1 ms, about 0.03 ms each.
- The dump was read before the next build. In 15 of the 17 gaps with compute dispatches, the passes that follow do not read what the dispatches wrote before their fragment stage.
- The switch was extended to those gaps: a dispatch's storage buffers and images join the list that each draw is checked against. In a run of 35 phases of 5 seconds it opened about 5 gaps a frame, and a draw closed one again in 0.1 to 0.5 frames. The GPU's time for one frame was 16.8 ms with it off and 17.2 ms with it on (means 17.07 and 17.06 ms). No measurable gain, which fits 5 gaps at 0.03 ms. The tester saw no picture fault.
- What keeps the other gaps closed, per frame: a copy step that holds only uniform updates or host copies (13 to 14), an ordering barrier of the game from before the first write (6), a draw that writes memory from its shader (4). Opening all of them would be worth about 0.7 ms at most, with a rising risk for the picture.
- The host's pass merging (`DM_NVN_TBDR=1`, off for this game) was tried once: no gain, more long frames, and wrong water. It stays off.
- The fragment shaders of the costly passes were inspected for slow translation. They are large (3,000 to 6,000 lines, 16 to 23 texture reads), and no fault of that kind was found.

**Decision of the tester, 11 Nov:** the game's own resolution at about 57 frames a second (17.4 to 17.5 ms in the test scene) is the accepted baseline. A lower render scale and dynamic resolution are rejected, because the picture comes first. The work on 60 at this resolution stops here.

Not found yet: the cause of the hitches. In play, a hitch is one command buffer that the GPU holds for 20 to 150 ms, with no upload, no new pipeline, no allocator wait and no pattern in the residency numbers. So the cause is not visible from the game or the host. Other apps that use the GPU and swap are suspects, not tested yet.

## Results of 11 and 12 Nov: parallel GPU work

Question: can more of the frame run in parallel on the M1 Max GPU? Measured with Apple's Metal System Trace (5 seconds in the test scene) and in-run A/B tests.

What the trace shows:

- The GPU works about 72 % of the time: vertex 15 %, fragment 34 %, compute 27 %.
- Two or more of these units work at the same time only about 4 % of the time. The GPU runs the frame's steps one after another.
- The idle 28 % is mostly short gaps (under 0.1 ms) between steps inside one command buffer, and about 1.2 ms a frame between command buffers.
- The host's own per-pass timer counts waiting as work. The trace is the reference.

What was tried:

- `DM_NVN_MDX_SEAM`: the gap before the second half of the main pass stays about 1 ms with the switch on. No gain. Off.
- `DM_NVN_ASYNC_CS` (the async compute window, `patches/22-mdx-seam-and-async-compute.diff`):
  - It works. With it on, the two full-screen passes after the frame's largest compute group (4 dispatches, about 1.1 ms) start at the same time as that group. With it off, they start after it.
  - The gain is small. That part of the frame takes 1.445 ms on and 1.467 ms off: the passes run beside the group but slow down from 0.29 to 1.4 ms, because the group and the passes already fill the shader cores.
  - Trace: time with two or more units busy at once rose from 39.5 to 46.0 ms a second.
  - A/B, 20 phases of 5 seconds each: frame mean 16.76 ms on, 16.98 ms off. The median sits at the 60 Hz limit in both states.
  - The picture was correct in screenshots taken while it was on.
  - The first build did nothing: a block at the end of every command buffer stopped the first compute group of each one. That block is needed only with frame generation on (its MetalFX work is the only compute outside the frame's own command buffers) and now applies only then.

Conclusion: on this GPU, running more work side by side helps little, because each heavy step already keeps the cores busy. The time left to win is the short waits between steps and between command buffers.

Not explained: in one run the frame took 19.3 ms in both A/B states, and in later runs 16.7 ms in both states. The code was the same, so the run conditions changed.

## Results of 12 Nov: scene changes, the opening movie and the city

A 27-minute play log (92,100 frames) showed three kinds of drops at scene changes and new places. Each was traced to its cause before anything was built.

**1. The host's texture table (fixed, on by default).**

- After a scene change the game leaves thousands of texture slots pointing at textures it has freed. The host looked each one up when it rebuilt its texture table.
- A table of 512 freed textures overflowed. Every lookup missed, its notes overflowed, and the host rebuilt the whole table every frame. Host CPU was 29 to 69 ms a frame against 7 ms, in stretches of up to 15 s.
- The game's code shows that it frees a texture only when no slot holds it any more, and it does not read a freed slot again before it fills it with a new texture. So the host now gives such a slot a placeholder (`DM_NVN_POOL_RETIRED=1`).
- Test runs (about 5 and 20 minutes): no table overflow in any block, worst host CPU a frame 8.3 to 8.4 ms (was 68.7), no block with a median over 20 ms (was 6), and no picture fault seen.

**2. Pipelines built at the first draw (partly fixed, needs lists).**

- The host built mesh pipelines that were not in its archive while the frame waited: 31 builds and 7.9 s of freezes in the long play, the longest 722 ms.
- Fix: one base pipeline per set of game shaders is built before the first frame, and a draw specializes it in a few ms (`DM_NVN_MESH_SETS`).
- A second fault kept those bases from being found. Many translated shader libraries are byte-identical, and Metal returns one object for equal bytes. The host named that object after whichever twin loaded last, so the archive key of a pipeline changed at every start. A list of the twins (`DM_NVN_LIB_TWINS`) gives each group one fixed name. After it, a start compiled 0 bases (was 58 every start), the prepare step took 4.6 s (was 7.1 s), and no mesh pipeline was built at a draw.
- Both lists are made from the game's own files, so they are not in this repository. Without them the fix does nothing.

**3. Loads.** A scene's first texture uploads (up to about 250 MB) take 0.3 to 0.9 s once. Not changed.

**GPU pauses between frames.** In the city, the GPU sometimes waited 40 to 160 ms between command buffers that were already sent, with no slow pass. The Mac had 9.2 of 10 GB of swap in use, and browsers and a chat app were open. With them closed, these waits fell from 4.4 to 0.2 to 0.42 per 1,000 frames. Memory pressure is the likely cause. It is not proven.

**The opening movie (fixed).**

- The movie is AV1, 1920 × 1080 at 60 frames a second. The M1 has no AV1 decoder, so the CPU decodes it.
- Most pictures take about 9 ms to decode, but 1 in 100 takes 88 to 132 ms. The host decoded each packet on the game's movie thread, which is also the thread that shows the pictures. A slow picture held the movie on one picture.
- Measured: 31 to 55 pauses over 50 ms per 600 pictures, the longest 217 ms.
- Fix: the host decodes on its own thread and the game's call returns at once. The game still sees the same buffer limits. A simulation over the real decode times showed no late picture once the decoder can run 8 pictures ahead, and the host allows 12.
- After: 1 to 6 pauses over 50 ms per 600 pictures. The tester: "the cut scene is great now".

**The city.** Hyrule Castle Town market: frame median 16.6 to 18.4 ms, 95th percentile 18.3 to 22 ms, GPU about 17.3 ms a frame. It is limited by the GPU. The host's per-pass timer counts waiting as GPU work, so the next step is a Metal System Trace in the market with each pass named (`DM_NVN_ENC_LABEL=1`), and a fix only for what that trace shows.

## Results of 17 to 19 Nov: the full scene size (branch `experimental`)

This section describes the branch `experimental`, not `main`. Its work is one patch, [`patches/30-experiments-19-nov.diff`](../patches/series).

- Place: Kakariko village, a still view, the same save in every run.
- Output 2560 x 1440, power adapter, High Power mode, macOS 27.2.
- The runs drive themselves: a script starts the game, loads the save and stops the game. Each table names its runs.
- The run logs stay with the test tree. They are not in this repository.
- Each time is a median over the gameplay frames of a run, and was computed again from the run logs for this page.
- Two runs hold GPU error lines: `lag1g` (2) and `lag1h` (4). No other run named here holds one.

### The scene was drawn too small before

Up to 17 Nov the host told the game that it runs at the lower graphics level. The game then composed its final picture at 2048 x 1152 and drew the 3D scene at 1536 x 864. `main` still does this.

`experimental` reports the top level. The game then composes at 2560 x 1440 and draws the scene at 1920 x 1080. `DM_GFX_SCALE=1` gives the old level. This is the one change on the branch that is on by default. It makes the branch slower than `main`.

- The scene is 0.75 of the final picture at both levels.
- Which level a real docked console reports is not measured.
- The smaller scene has 64 % of the pixels of the full one.
- Earlier sections of this page call the smaller size "the game's own resolution" and give the final picture as 2560 x 1440. The logs of those runs show 2048 x 1152.

| | Scene | Frame time | GPU span | Scene passes |
|---|---|---|---|---|
| Lower level, as on `main` (run `tsbase`) | 1536 x 864 | 17.33 ms | 16.53 ms | 9.02 ms |
| Top level (run `t0`) | 1920 x 1080 | 19.84 ms | 19.53 ms | 12.92 ms |

- GPU span: from the GPU's start on a frame to its end on that frame.
- Scene passes: the summed GPU time of the passes that draw at the scene size. It grew 1.43 times for 1.56 times the pixels.
- In run `t0` other windows covered the game window at times. Its frame time is less sure than its GPU numbers. A later run with the same settings (`base4`) gave 19.18 ms.

### The GPU is the limit at the full size

- The GPU span is 19.53 ms. The budget for 60 frames a second is 16.67 ms.
- The host starts to translate the next frame 11.09 ms before the GPU ends the current one (run `t0`). The GPU does not wait for the host.
- So faster translation on the CPU does not help at this size. Only less GPU work helps.

Point 1 of "The model" below was written for the smaller scene. It does not hold at the full size. Point 2 was not tested again at this size.

### Cost tests inside one run

These tests measure what a part of the frame costs. A switch stops that part from being drawn, so the picture is wrong while it is on.

- One run turns the switch on and off every 300 frames (`DM_AB=300`).
- The host prints one line for each block of 300 frames, without the block's first quarter.
- The table gives the median of those lines.

Two terms:

- Small passes: render passes that draw into small targets, for example 128 x 128.
- Task and mesh draws: draws that use the task and mesh shader stages. The game draws much of its scene geometry this way.

| What is not drawn | Run, blocks | Frame time, off to on | Summed GPU time, off to on |
|---|---|---|---|
| The small passes (`DM_NVN_SKIP_SMALL`) | `smallab`, 10 to 20 | 19.12 to 17.84 ms | 27.76 to 25.78 ms |
| The task and mesh draws (`DM_NVN_SKIP_MESH=1`) | `meshdrop`, 30 to 40 | 19.54 to 16.62 ms | 28.12 to 23.40 ms |
| Only the pixels of the task and mesh draws (`DM_NVN_SKIP_MESH=2`) | `meshnofs`, 30 to 40 | 19.61 to 19.49 ms | 28.22 to 27.47 ms |

Summed GPU time is the sum of the GPU times of a frame's command buffers. It is larger than the frame time.

What the tests show:

- **Small passes.** The switch removes about 37 of 117 passes a frame. Together they cost 1.3 ms of frame time.
- A join of such passes keeps their draws and removes only pass boundaries, so it saves less. It is not built. Upstream measured 0.52 ms of GPU time for a join of 14 passes in another game.
- **Task and mesh draws.** The switch removes 441 of 3,213 draws a frame. The frame then reaches the display's limit of 60 frames a second. So these draws cost 2.9 ms of frame time or more.
- In summed GPU time they cost 4.72 ms, and 0.75 ms of that is pixel work. About 84 % is spent before the rasterizer: in the task and mesh stages and in the GPU's tile sorting.
- One limit of the last test: without the depth of these draws, later draws may shade more pixels. That hides a part of the pixel cost.

### Changes tested run against run

Upstream pull request 2889 reads read-only storage buffers through Metal's constant address space. Three runs without it and three with it:

| | Runs | Frame time | GPU span |
|---|---|---|---|
| Without | `scA10`, `scA11`, `scA12` | 18.89, 18.92, 18.66 ms | 18.35, 18.45, 18.26 ms |
| With | `scB10`, `scB11`, `scB12` | 18.89, 19.00, 18.82 ms | 18.46, 18.45, 18.33 ms |

No gain. The change is not in the patch.

One frame in flight (`DM_NVN_SYNC_LAG=1`) lets the game build a frame while the GPU still draws the frame before:

| | Run | Scene | Frame time | Picture |
|---|---|---|---|---|
| Off | `mlag0` | 1536 x 864 | 17.39 ms | the reference |
| On | `mlag1` | 1536 x 864 | 16.71 ms | not checked in this run |
| Off | `base4` | 1920 x 1080 | 19.18 ms | the reference |
| On | `lag1g` | 1920 x 1080 | 17.11 ms | wrong, 2 GPU error lines |
| On | `lag1h` | 1920 x 1080 | 16.57 ms (773 frames) | wrong, 4 GPU error lines |
| On, with the uniform data copied at submit | `snapl` | 1920 x 1080 | 18.91 ms | mostly right |

- In `mlag1` the frames over 17.5 ms fell from 45.6 % to 2.1 %.
- Uniform data: the constants a draw reads, such as its matrices.
- The game rewrites its per-frame buffers in place while the host still translates the frame before. Draws then read data of the next frame. That is the cause of the wrong picture.
- In `snapl` the host copies the uniform data when the game submits a frame. Grass, small leaves and vines are still wrong.
- `snapl` is 0.27 ms faster than `base4`. Equal runs differ by as much: 18.66 to 18.92 ms in the three runs without pull request 2889.
- So the gain of `lag1g` and `lag1h` came with the wrong picture and the GPU errors. With most of the picture right, no gain is left.

Conditional rendering decided on the GPU (`DM_NVN_RC_GPU`) has a self-check (`DM_NVN_RC_GPU_CHECK`). In run `t0` it compared 5,792,396 draws: 0 were hidden wrongly and 0 were drawn wrongly.

Not checked again for this page, from the notes of 17 Nov: translation on several threads was slower in each run, and merged copy passes and late clears changed nothing.

### Where it stands on 19 Nov

- `main` draws the smaller scene. Its numbers are in the README.
- `experimental` draws the full scene at 18.7 to 19.6 ms a frame in Kakariko. That is 51 to 54 frames a second.
- These are the frame times of `base4`, of the three runs without pull request 2889, and of the "off" blocks of the cost tests.
- The gap to 60 frames a second is 2.0 to 2.9 ms of frame time. Of all parts measured, only the task and mesh draws cost that much.

### Next step: the task and mesh draws

The cause of their cost is not measured yet. Two candidates:

- A fixed cost for each mesh draw on this GPU. Upstream measured about 2.7 µs for each on an M1. For 441 draws that is 1.2 ms, so it cannot be the whole cost.
- The host issues these draws with indirect arguments. Apple's feature table lists indirect mesh draw arguments for a newer GPU family than the M1's.

Plan:

1. Count the runs of mesh draws with the same shader pair, and who writes each argument buffer: the game on the CPU, or a GPU pass.
2. If the game writes the arguments on the CPU: test direct mesh draws behind a switch. The host reads the arguments when the game submits.
3. Decide on merging draws from the counts of step 1.

### Notes for testers

- A shader chain is one set of translated shaders. A second chain must have its own pipeline cache folder (`DM_PSO_ARCHIVE=<folder>`).
- The keys of the cache do not hold the chain. Two chains in one folder compile every pipeline again at each start.
- A slow start of the game shifts every timed key press of a test script. Check the first screenshots of a run before you trust its numbers.

## The model

1. The frame is a serial chain. The game builds a frame. A host thread translates it (7 to 9.5 ms of CPU). The GPU runs it (15.4 to 20.4 ms from the first start to the last end). The game then waits until the GPU is done before it lets the next frame's commands run. In run B that wait took 3.7 to 11.5 ms a frame.
2. The GPU is not saturated. Holding its clock at the top did not change the time. The cost is latency in series: 111 to 115 render passes and 28 to 37 submissions a frame, and about 71 of the passes load and store whole attachments. A tile-based GPU pays at each pass boundary.
3. The wait in point 1 is the game's own code. Each frame it submits with a fence, acquires the next window texture, waits on that fence with no timeout, and only then signals the event that the next frame's commands wait on. The game never lets one frame start while the GPU holds the frame before it. So nothing in the game promises that a frame's memory stays untouched while the next one is built. The likely cause of the flashing with GPU overlap follows from this: the host lets the game run ahead, and the game rewrites memory that the GPU still reads. Which memory that is has not been measured yet.
4. The hitches fall in the blocks of run B where the host's pool of 32 command allocators ran out. This is a candidate cause, not a proven one.

## Next steps

Steps 1 and 2 of the earlier plan are done (build 5 measured, GPU overlap stopped). What is next:

1. Play tests for stability with the baseline settings: crashes, picture faults, hitches.
2. The hitch cause: a play run with no other app on the GPU, and a count of the long frames.
3. More tests of what the game's code shows, each as a quick switch that is checked against a one-frame dump before it is built.
4. Even motion: 60 + 60 frame generation needs the real frame under 16.7 ms, so it is parked. 30 + 30 is stable.
5. Frame rate above 60 (asked 12 Nov): not possible with the current host. The game advances its time by a frame ratio that the host's frame step patch sets from whole vsyncs of 1/60 s, and the host's 120 fps mode refuses a game with such a step. It needs a step in 1/120 s units in the patch and the host, and a check in the game's code that a ratio of 0.5 keeps the game's speed and physics right.
6. Bring the changes of the table into this repository as patches, each with its measurement. Until then, of the settings in the table "Settings used in the test build", the released app shows only Frame rate and Encode thread for this game. Its Upscaling row is a different setting from Game's upscaler.

## Plan for reverse engineering

The game's code is read with REA, an MCP server that drives Ghidra.

Rule: measure with a run first. Read the game's code only when a log cannot answer the question and the answer changes what gets built.

What works:

- The whole game module is too large for the tool's start limit. One function at a time works and takes seconds.
- So each question is narrowed first with small scans (a table of the game's NVN function pointers, then the call sites of one function), and only the functions that the scans name are decompiled.

Done so far:

- Point 3 of the model. It confirmed a measurement, named its parts, and showed that the game has no usable switch that removes the wait. The one mode that skips it also skips the window.
- The game keeps two sets of per-frame buffers and one main command buffer.
- The barrier the game issues after each compute dispatch and texture copy, and the engine features that make texture copies (fog pre-pass depth, soft-edge depth, a shared copy helper for snapshot, picking and exposure). See "Results of 11 Nov".

Planned, in this order, each behind its own gate:

| Question | Gate that must pass first | Why the game's code is needed |
|---|---|---|
| Which memory does the game rewrite in place each frame? | step 2 above shows a gain | a host diagnostic names the ranges first. The code is read only to explain a range the diagnostic names |
| Where is the frame step computed and used, and does the game accept a step of 1.5? | a decision to build the 40 frames a second step | the step lives in game code and no log shows where |
| Where do the 28 to 37 submissions a frame come from? | a GPU trace shows that pass boundaries are the cost | only the game's code shows why it flushes |

Not planned: analysis of the whole module, more tooling, or reading code to confirm what a run already measured.

Handling: decompiled code stays on the test machine. Only findings about behaviour are written down. No game file, key or extracted data is committed.
