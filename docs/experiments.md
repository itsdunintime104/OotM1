# OotM1: experiment ledger

One row for each thing that was tried, from 10 Nov 2026 on. The page answers one question: was this tried before, and what came out?

- Machine: MacBook Pro with M1 Max, 32 GB. Goal: 60 frames a second, which needs 16.67 ms a frame.
- The story behind the rows is in [results.md](results.md). This page is the list.
- Times are frame times unless the row says otherwise.
- Many runs sit at the display's limit of 16.67 ms. There the frame time cannot show a gain, so the rows also give GPU time.

## How to read a row

| Verdict | Meaning |
|---|---|
| Kept | On by default, or in the tested settings |
| Off | In the code behind a switch that is off |
| Closed | No gain, a wrong picture, or against the tester's rules. Do not repeat it without new evidence |
| Open | Not decided. The row says what is missing |
| Diagnostic | A measurement tool. It changes nothing by itself |

The column "Basis" says where the number comes from:

- **digest**: computed again on 20 Nov from the run digest in [`data/`](data). The row names the log or the runs.
- **record**: copied from the notes written at the time of the test. Not computed again.

Three terms:

- Display tick: one refresh of the 120 Hz screen, 8.33 ms. A frame at 60 frames a second stays for 2 ticks.
- Summed GPU time: the sum of the GPU times of a frame's command buffers. It is larger than the frame time.
- Residency commit: the step that makes new GPU memory usable. It is slow when the Mac is short of memory.

## The run digest

The raw run logs are not in this repository, and most of them were deleted on 20 Nov to free disk space. Three small tables keep what the rows need:

| File | Content |
|---|---|
| [`data/runs.tsv`](data/runs.tsv) | One line for each run that has a per-frame table: frames, frame time (median, 95th and 99th percentile), GPU span, summed GPU time, draws |
| [`data/ab_phases.tsv`](data/ab_phases.tsv) | Every line the host printed for a block of an in-run A/B test: GPU time, frame time, passes |
| [`data/logs.tsv`](data/logs.tsv) | One line for each log: date, size, GPU error lines, final picture size, the switches that alternated |

- A summary line counts gameplay frames only: from frame 4,500 on, with more than 1,500 draws.
- "main thread" in `runs.tsv` is the host thread that translates the game's commands.
- An A/B run turns its switch on in every second block. In `ab_phases.tsv` the `label` column names the switch that is on in a block, and `base` means off.
- Three logs label every block `base`: `run_smallab`, `run_meshdrop` and `run_meshnofs`. Their switch is on in the odd blocks.
- An A/B number is the median over the blocks from block 4 on.

## Rule for new work

Every experiment gets a row here before its logs are deleted. A row needs: the date, what was changed, the switch, the runs, the numbers of both sides, and a verdict.

## 10 and 11 Nov: from 28.0 ms to about 18 ms

| Tried | Switch or source | Result | Verdict | Basis |
|---|---|---|---|---|
| 120 Hz display link | `DM_PRESENT_LINK=2` | Part of the gain from 28.0 to 18.7 ms. Not separated | Kept | record |
| Shaders read global memory at Metal's own addresses | upstream pull request 1833 | GPU time 22.66 to 20.62 ms a frame | Kept | record |
| MetalFX takes the game's own upscaler | upstream pull request 1951 | Removes a compute chain of 3.2 ms a frame | Kept | record |
| Encode ahead | `DM_NVN_PREENCODE` | Part of the gain from 28.0 to 18.7 ms. Not separated | Kept | record |
| Border corrections compiled out | upstream pull request 1929 | Not measured here | Kept | record |
| Early depth tests from the shader's flag | upstream commit `a888e668` | Not measured here | Kept | record |
| One command allocator for a frame's submissions | upstream commit `fd8188c9` | No allocator wait any more. Hitches remain (2 in 3,600 frames), so the allocator was not their cause | Kept | record |
| Render scale 0.75 | upstream pull request 1903 | 16.7 to 17.4 ms: holds 60 | Closed: the tester rejected the softer picture | record |
| GPU overlap, first form | `DM_NVN_SYNC_LAG` | 18.1 against 18.4 ms, and the picture flashed | Closed, see 18 Nov | record |
| Every pass waits for the pass before (measurement) | `DM_NVN_BARRIER` | 18.1 ms against 15.9 to 16.1 ms. The 80 passes that start without a full wait save about 2.1 ms. This gain was already in the host | Diagnostic | record |
| Passes after texture copies start without the full wait | `DM_NVN_COPY_SEAM` | Never acted: the game makes 2 texture copies a frame | Closed | record |
| The same for gaps with compute dispatches | `DM_NVN_COPY_SEAM`, `DM_NVN_SEAM_DISPATCH` | GPU time of a frame 16.8 ms off, 17.2 ms on. It opened about 5 gaps a frame | Closed | record |
| The host's pass merging | `DM_NVN_TBDR=1` | No gain, more long frames, wrong water | Closed | record |
| Search for slow shader translation in the costly passes | reading | No fault found | Closed | record |
| Fewer or merged submissions, encode thread on or off, GPU clock held at the top | several | No change | Closed | record |
| Wait before the second half of the main pass | `DM_NVN_MDX_SEAM` | The gap stays about 1 ms. 16.68 ms off, 16.75 ms on. Summed GPU time 24.59 against 26.19 ms | Closed | record; digest, log `1111_2152_mdx_seam_self` |
| Async compute window | `DM_NVN_ASYNC_CS` | Mean 16.76 ms on, 16.98 ms off. Picture correct. Medians: 16.70 ms off, 16.64 ms on | Kept | record; digest, log `1111_acs_ab2_self` |
| Frame generation, 30 + 30 | `DM_MFX_INTERP` | Stable. No logged numbers | Off | record |
| Frame generation, Uncapped and 60 + 60 | `DM_MFX_INTERP` | Real frames fell from about 41 to between 32 and 36 a second. 60 + 60 was not held: the real frame took 17.0 to 19.4 ms | Off: needs a real frame under 16.7 ms | record |

## 12 Nov: scene changes, the opening movie, the city

| Tried | Switch or source | Result | Verdict | Basis |
|---|---|---|---|---|
| Placeholder for texture slots the game has freed | `DM_NVN_POOL_RETIRED=1` | Worst host CPU a frame 68.7 to 8.3 ms. No block with a median over 20 ms (was 6) | Kept | record |
| One base pipeline for each set of mesh shaders, built before the first frame | `DM_NVN_MESH_SETS` | 31 builds and 7.9 s of freezes in a long play. After this and the next row: no mesh pipeline built at a draw | Kept. Needs a list made from the game's files | record |
| One fixed name for byte-identical shader libraries | `DM_NVN_LIB_TWINS` | Bases compiled at a start 58 to 0. Prepare step 7.1 to 4.6 s | Kept. Needs a list made from the game's files | record |
| Opening movie decoded on its own thread | host change | Pauses over 50 ms: 31 to 55 per 600 pictures before, 1 to 6 after | Kept | record |
| Browsers and a chat app closed during play | none | GPU waits between command buffers fell from 4.4 to between 0.2 and 0.42 per 1,000 frames | Open: memory pressure is likely, not proven | record |
| Attachment loads skipped when the first draw covers the target | `DM_NVN_LOAD_ELIDE` | The safe form skips none: 82 of 86 candidates draw a full-screen triangle with no position attribute | Off | record |
| The same without the safety check (measurement) | `DM_NVN_LOAD_ELIDE_UNSAFE` | Loads 304 to 268 MB a frame. First reading, 2 clean blocks: GPU median 15.67 to 15.37 ms. All 11 blocks a side: summed GPU time 16.59 ms off, 16.91 ms on, and 16.67 ms on both sides | Closed: no gain shown | record; digest, log `1113_run13_ab_unsafe_short` |
| 4K output | launcher setting | Costs frames in the field. No number kept | Closed for tests: they stay at 2560 x 1440 | record |

## 13 Nov: host CPU at scene changes, pacing, frame generation

| Tried | Switch or source | Result | Verdict | Basis |
|---|---|---|---|---|
| Per-pool index for shared textures, pool index kept sorted | host change | Unit tests: take-over 47 to 0.51 µs, texture lookup 40.5 to 1.28 µs, pool index sort 77 to 1.5 µs. In play: calm median 16.66 ms as before, and the first market load is as slow as before (737 + 395 ms) | Kept | record |
| Round 2 of small CPU fixes on the translating thread | host change | Estimate from a profile: about 1.0 ms a frame in busy frames, 0.7 ms in calm play. Play median 16.6 to 17.0 ms as before | Kept | record |
| Queue state switched by pointer, not copied | host change | Estimate 0.3 to 0.45 ms a frame from a trace | Kept | record |
| Upload staging memory shrinks again after a load | host change | Before: about 0.45 GB stayed held after a load. No number after | Kept | record |
| Identical re-encodes of draw arguments skipped | counters only | 6.5 identical re-encodes a frame. Too few | Closed: not built | record |
| Early hand-over of encoded blocks to the encode thread | `DM_NVN_REC_EARLY` | Before: the drain blocked 1.4 to 1.7 ms a frame. No number after | Kept | record |
| Cheaper pool finalize | host change | Before: 4,857 calls, 1.17 s in one run. No number after | Kept | record |
| Pipeline prediction never compiles on the submit path | host change | Fight spikes of 280 to 460 ms. Predictions about 800 to 0.8 ms a window | Kept | record |
| Upload sources kept between loads | host change | Worse: 4,058 MB held, residency commits 1,166 against 541 ms | Off | record |
| Shared textures dropped when idle | `DM_NVN_ALIAS_IDLE_DROP` | No number kept | Open: effect not measured | record |
| Real frames held for their period on the 120 Hz link | `DM_NVN_LINK_HOLD` | First reading: mean 16.84 ms on, 17.29 ms off, with a scene that differed. Three more runs, off and on: 16.69 and 16.93, 16.80 and 16.83, 17.46 and 17.13 ms | Closed: no steady difference. `DM_PRESENT_HOLD2` replaced it | record; digest, logs `1113_fg_off_2648fe5`, `1113_grass_gpuprof`, `1113_run17` |
| Frame generation: hold capped, GPU time judged by the real span | host change | Steady 30 + 30: median 33.33 ms, 0 hold changes in the field (was 17 to 30) | Off: the tester found locked 30 + 30 choppy | record |
| Real-time frame step | `DM_FPS_REALTIME` | Game speed 0.970 to 0.991 of real time at about 43 real frames a second | Open: one counter in the game still rounds the step | record |

## 16 and 17 Nov: pacing, several threads, conditional rendering

| Tried | Switch or source | Result | Verdict | Basis |
|---|---|---|---|---|
| Deferred pass merge | `DM_NVN_PASS_DEFER`, from upstream pull request 2441 | Field, 13 blocks a side: 20.71 ms off, 20.78 ms on. Summed GPU time 20.36 against 20.39 ms | Closed | digest, log `run_pd2441_field` |
| The translating thread does not wait for the encode thread after each batch | `DM_NVN_DRAIN_LAZY=1` | Translating thread 13.1 to 10.4 ms. Side effect: frames shown for 1, 2 or 3 display ticks went from 6 / 1,713 / 6 to 241 / 1,277 / 246. Frame time 16.72 ms off, 16.73 ms on | Kept, only together with the next row | record; digest, log `run_f10_ab` |
| Every frame stays on screen for its full time on the 120 Hz link | `DM_PRESENT_HOLD2=1` | Frames not shown for exactly 2 ticks 31.4 to 6.5 per 1,000 in the market. It adds 8.3 ms of delay by design | Kept | record |
| Translation on several threads | `DM_NVN_PAR` and its workers | Median 17.0 to 18.3 and 18.8 ms. Late frames 59 to 106 per 1,000 became 234 to 327 | Closed | record |
| Conditional rendering decided on the GPU | `DM_NVN_RC_GPU`, self-check `DM_NVN_RC_GPU_CHECK` | The fault it fixes: in the city 414 of 513 conditional blocks a frame were drawn because the result was not back. Self-check: 5,792,396 draws, 0 wrong. A/B in play: summed GPU time 22.87 ms off, 21.70 ms on. Frame time 16.68 and 16.70 ms, at the limit | Kept | record; digest for the A/B, log `run_play_h16b` |
| Two earlier forms of that fix: a block with no result yet is drawn through indirect draws, or reads its last known result | `DM_NVN_RC_LATE`, `DM_NVN_RC_LAST` | Summed GPU time: 18.57 ms off and 19.34 ms on, and 18.86 ms off and 19.45 ms on. Frame time at the limit on both sides | Off: `DM_NVN_RC_GPU` replaced them | digest, logs `run_play_h14`, `run_play_h15` |
| The translating thread polls every 0.1 ms, not every 1 ms, at the game's event waits | `DM_NVN_EVT_FAST` | 17.59 ms off, 17.90 ms on. Summed GPU time 20.91 against 21.49 ms | Off: slower with it on | digest, log `run_play_h13b` |
| Host compute jobs join the open copy pass, and late clears | `DM_NVN_COPY_MERGE`, `DM_NVN_CLEAR_LAZY` | Four states in one run: off 17.09 ms, late clears 17.10 ms, copy merge 17.15 ms, both 17.16 ms. Summed GPU time 24.59 to 24.67 ms in all four | Off | digest, log `run_s3k1` |
| One frame in flight before the fence fix | `DM_NVN_SYNC_LAG=0, 1, 2` | 17.36, 17.34 and 17.29 ms: no change. The game's wait moved from one call to another | Closed. See 18 Nov for the fixed form | record |
| A 128 x 128 probe render and its filter chain not drawn (measurement) | `DM_NVN_SKIP_SMALL=128` | Smaller scene: 16.38 to 15.95 ms, GPU busy time 11.0 to 10.0 ms | Diagnostic | record |
| A memory pool the game creates and frees most frames | counters only | 0.2 to 0.3 ms of CPU a frame, no GPU cost seen | Closed: not built | record |

## 18 and 19 Nov: the full scene size

The numbers of these rows are explained in [results.md](results.md), section "Results of 17 to 19 Nov".

| Tried | Switch or source | Result | Verdict | Basis |
|---|---|---|---|---|
| Is the scene size set by the GPU time the host reports? | `DM_NVN_TSFLAT`, `DM_NVN_GPU_TS=submission` | The scene stayed 1536 x 864 with the reported load at 0 | Closed: it is not | record |
| The host reports the top graphics level | default; `DM_GFX_SCALE=1` gives the old level | Scene 1536 x 864 to 1920 x 1080. 17.33 to 19.84 ms, GPU span 16.53 to 19.53 ms | Kept on `experimental` | digest, runs `tsbase`, `t0` |
| The lower graphics level as the answer | `DM_GFX_SCALE=1` | 17.33 ms, against 19.84 ms at the top level | Closed: the tester wants the full scene size | digest, runs `tsbase`, `t0` |
| One frame in flight, smaller scene, with the fence fix | `DM_NVN_SYNC_LAG=1` | 17.39 to 16.71 ms. Frames over 17.5 ms 45.6 % to 2.1 %. Picture not checked | Open at this size | digest, runs `mlag0`, `mlag1` |
| One frame in flight, full scene | `DM_NVN_SYNC_LAG=1` | 19.18 ms to 17.11 and 16.57 ms, with a wrong picture and GPU errors | Closed | digest, runs `base4`, `lag1g`, `lag1h` |
| The same, with the uniform data copied when the game submits | host change in the patch, with `DM_NVN_SYNC_LAG=1` | 18.91 against 19.18 ms: inside the spread between equal runs. Grass and leaves still wrong | Closed | digest, runs `base4`, `snapl` |
| Which buffers does the game rewrite in place, and when? | `DM_NVN_BUFLOG`, `DM_NVN_LAG_COPY`, `DM_NVN_SUBWATCH` | The game writes its per-frame buffers after it presents: 285 writes after a present, 2 before | Diagnostic | record |
| Cost of the small passes | `DM_NVN_SKIP_SMALL` | 19.12 to 17.84 ms. Summed GPU time 27.76 to 25.78 ms | Open: a join is not built. Upstream measured 0.52 ms for a join of 14 passes in another game | digest, log `run_smallab` |
| Read-only storage buffers through Metal's constant address space | upstream pull request 2889 | 18.66 to 18.92 ms without, 18.82 to 19.00 ms with | Closed | digest, runs `scA10` to `scA12`, `scB10` to `scB12` |
| Cost of the task and mesh draws | `DM_NVN_SKIP_MESH=1` | 19.54 to 16.62 ms, the display's limit. Summed GPU time 28.12 to 23.40 ms | Open: the next lever | digest, log `run_meshdrop` |
| Cost of their pixels only | `DM_NVN_SKIP_MESH=2` | 19.61 to 19.49 ms. Summed GPU time 28.22 to 27.47 ms | Diagnostic | digest, log `run_meshnofs` |
| MetalFX temporal upscaler from a public branch | not built | It draws the scene below the full size | Closed: against the tester's rule. Not built | record |
