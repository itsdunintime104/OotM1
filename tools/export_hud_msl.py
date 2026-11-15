#!/usr/bin/env python3
"""Writes the MSL of the game's HUD shaders for frame generation, from the build's shader cache.

Frame generation draws the HUD on a layer of its own. For that the host compiles a copy of each HUD shader from its
MSL source, which the app does not carry (it holds compiled shaders only). The host reads the sources from
DM_MFX_MSL_DIR/b-<shader set>/<key>_b.metal, so this writes them there.

Usage: export_hud_msl.py <engine dir> <cas.db> <keys file> <dest dir> [game log ...]
  keys file: one shader key per line (# comments allowed); the game logs add the keys they name in
  "fragment shader <key>_b: no MSL source" lines (HUD shaders met in play that the list does not hold yet).
Run with the engine's Python, with DM_GAME set to the game's title ID. Exit 0 also when some keys are not in the
cache (it says which): a missing source only keeps that shader's draws out of the UI layer.
"""
import json, os, re, sys

if len(sys.argv) < 5: sys.exit(__doc__)
eng, cas, keys_file, dest, *logs = sys.argv[1:]
sys.path[:0] = [os.path.join(eng, 'dm', 'tools'), os.path.join(eng, 'dm', 'gfx', 'tools')]
import dmsh_chain, shader_cache   # noqa: E402  (the engine's modules: the shader set's name and the cache)

keys = [ln.split('#')[0].strip() for ln in open(keys_file)]
keys = [k for k in keys if k]
learned = []
for log in logs:
    if not os.path.isfile(log): continue
    with open(log, errors='replace') as f:
        for m in re.finditer(r'fragment shader ([0-9a-f]{16})_b: no MSL source', f.read()):
            if m[1] not in keys and m[1] not in learned: learned.append(m[1])

out = os.path.join(dest, 'b-' + dmsh_chain.version())
os.makedirs(out, exist_ok=True)
store = shader_cache.Store(cas)
written, missing = 0, []
for k in keys + learned:
    meta = store.get(f'index/{k}.json')
    msl = store.get(f'shader/{json.loads(meta)["digest"]}/mac/{k}_b.metal') if meta else None
    if msl is None: missing.append(k); continue
    with open(os.path.join(out, f'{k}_b.metal'), 'wb') as f: f.write(msl)
    written += 1
store.close()
print(f'frame generation: {written} HUD shader sources in {out}'
      + (f' ({len(learned)} of them named by the game log)' if learned else '')
      + (f'; not in the shader cache: {" ".join(missing)}' if missing else ''))
