# flame_dragon_bones

Skeletal (bone-based) animation for **Flame** and **Bonfire**, using animations
exported from **DragonBones** — the free/MIT alternative to Spine and Rive.

> **Status: spike / proof of concept.** Nothing here is published or stable.
> See the status table below for exactly what works today.

DragonBones is a 2D skeletal animation tool. Its runtimes are MIT and exist
officially for TypeScript/JS, C++, C#, Java and ActionScript — but **not for
Dart/Flutter**. This repo exists to find out how expensive that gap is to close,
and to close it.

## Why

- Flame has `flame_spine`, `flame_rive` and `flame_lottie`, but **no DragonBones**
  bridge. `flame_spine`/`flame_rive` require paid tooling; DragonBones is free.
- There is an open Flame issue asking for exactly this — and the maintainers'
  answer is an explicit invitation:

  > "We're not planning on implementing this from the core team, but if anyone
  > feels like creating a bridge package to live in the monorepo we're more than
  > happy to review it and take it in."
  > — [flame-engine/flame#3788](https://github.com/flame-engine/flame/issues/3788)

- For an RPG the win is not "prettier sprites", it is **slot/skin swapping**
  (equip armour/weapon without authoring N sprite combinations), **deform meshes**,
  **bone attachment** (hitboxes / effect spawn points) and **animation events**
  (drive damage, sounds, projectiles from the animation itself).

## How this spike works

The hard part of a port is *being sure the math is right*. Rendering is visible;
skeletal math silently drifts.

So the correctness strategy is: **run the official runtime as an oracle**.

```
tool/ground_truth/     node harness wrapping the OFFICIAL DragonBones runtime
                       (headless, no renderer) -> dumps the armature state
                       frame by frame as JSON  == the oracle
packages/dragonbones/  pure-Dart port; a test replays the same frames and
                       asserts every bone matrix matches the oracle
```

Because the Dart port has **zero external dependencies**, it can be verified with
a bare Dart SDK — no Flutter, no device, no eyeballing pixels. Flutter is only
needed for the render layer, which is the one part that genuinely needs eyes.

The oracle harness is verified working on all three hand-picked fixtures — `Dragon`
(19 bones, sprites only), `龙` (60 bones, 5 deformable meshes, FFD, IK) and
`mecha_1004d` (4 armatures in one file, 3 nested) — **and on all 44 assets from the
DragonBones Unity SDK demos**, which is the sweep CI actually gates on. See
`doc/FINDINGS.md` for the full investigation.

## Status

| Piece | State |
| --- | --- |
| Oracle harness (node + official runtime) | ✅ working — every fixture dumps |
| Reference dumps committed | ✅ `tool/ground_truth/out/*.json` (holds the whole sweep) |
| Dart runtime port | ✅ **verified** — 51 assets, 757k numeric comparisons, 0 mismatches |
| Canvas renderer (`update` + `render`), no engine coupling | ✅ sprites **and** meshes (`drawVertices`) |
| Nested child armatures | ✅ built, animated and flattened into the draw list |
| FFD / deform timelines | ✅ ported (`DeformTimelineState`) |
| IK constraints | ✅ ported (`IKConstraint`) |
| Example Flutter app | ✅ `example/` — run it to see it |
| Path constraints, `Surface` bones, animation events (`EventObject`), `SlotZIndex` / `SlotAlpha` timelines | 🚧 not ported |

### The renderer is not coupled to any engine

`packages/dragonbones_flutter` depends on Flutter only — **not on Flame**. It
exposes two methods, so it drops into anything:

```dart
player.update(dt);     // advance the animation
player.render(canvas); // draw the pose
```

| Where | How |
| --- | --- |
| Plain Flutter app | `DragonBonesWidget`, or your own `CustomPainter` |
| Flame game | call the two methods from a `Component` |
| Bonfire | call them from a `GameComponent` |
| Headless test | assert on `armature.buildDrawList()` |

The renderer never mutates engine objects: the runtime is driven through a
renderer-less factory and the pose is read back as a `SlotDrawData` list. That is
also why the geometry is verifiable without a GPU.

### Verification result

```
  rest                           2 frames, 19 bones,  36 slot draw-data, max err 4.945e-7  OK
  stand                         31 frames, 19 bones, 558 slot draw-data, max err 5.000e-7  OK
  walk                          21 frames, 19 bones, 378 slot draw-data, max err 4.997e-7  OK
  jump                           6 frames, 19 bones, 108 slot draw-data, max err 4.987e-7  OK
  fall                           6 frames, 19 bones, 108 slot draw-data, max err 4.992e-7  OK
  long                          31 frames, 60 bones, 899 slot draw-data, 21173 mesh values, max err 5.000e-7  OK
  mecha                         59 frames, 20 bones, 826 slot draw-data, 118 child slots, max err 5.202e-5  OK
  bounding_box_tester            2 frames,  6 bones,   2 slot draw-data,  16 child slots, max err 0.000e+0  OK
  mecha_1002_101d_light         81 frames, 20 bones, 1458 slot draw-data, 81 child slots, max err 2.908e-5  OK
  mecha_1406                    61 frames, 17 bones, 793 slot draw-data, max err 4.999e-7  OK
  mecha_2903                     2 frames, 35 bones,  70 slot draw-data, max err 5.000e-7  OK
  progress_bar                 101 frames,  5 bones, 303 slot draw-data, 606 child slots, max err 3.968e-6  OK
  skin_1502b                     2 frames, 17 bones,  24 slot draw-data, max err 4.956e-7  OK
  weapon_1004_show               6 frames,  2 bones,   5 slot draw-data,  45 mesh values, max err 4.741e-7  OK
  you_xin/body                  71 frames, 70 bones, 6816 slot draw-data, 47357 mesh values, max err 5.000e-7  OK
  you_xin/suit2/20106010         2 frames, 20 bones,   2 slot draw-data, 630 mesh values, max err 4.999e-7  OK
  … 35 more …                                                                            all OK

757701 numeric comparisons over 51 assets (51 clean, 0 failing)
74245 mesh values, 1228 nested-armature slots
RESULT: PASS
```

Checked per frame: every bone's global matrix, every slot's draw data (world
matrix, pivot, quad size, atlas region, z-order, visibility, blend mode, colour),
every mesh's **posed vertices, UVs and triangle indices**, and every nested
armature's slots with the parent slot's matrix composed onto them. That is the
complete geometry a renderer needs, so drawing it is a thin, low-risk step rather
than guesswork.

~5e-7 is the rounding precision of the reference dumps themselves, so the port is
effectively exact. The few values that peak higher (`mecha` at 5.2e-5, `mecha_1002_101d`
at 2.9e-5) are the assets with nested armatures, where composing two matrices per
child slot compounds the dumps' own rounding. `dart analyze` is clean and the whole
sweep runs in CI.

**One caveat worth stating plainly**: the oracle for *mesh* geometry is the
official **Egret binding** (`.ref/egret-binding/EgretSlot.ts`), not the core
runtime — because in DragonBones the per-vertex deformation lives in the engine
binding: `Slot._updateMesh` is abstract and the core never implements it. So that
transcription is the reference, and it is transcribed verbatim in both the oracle
(`tool/ground_truth/dump.js`) and the port
(`packages/dragonbones/lib/src/render/mesh_geometry.dart`).

Two more things the sweep does **not** judge, stated so they are not mistaken for
coverage: how any of it *looks* (no GPU on a runner — the Flutter tests rasterise
to prove pixels are produced, not that they are pretty), and assets that need the
features still listed as unported above.

## Fixtures

Three hand-picked animations plus the whole Unity SDK demo set (format version
**5.5**), a deliberate ladder:

| Fixture | Bones | Slots | Features |
| --- | ---: | ---: | --- |
| `Dragon` | 19 | 18 | sprites only, 4 animations (`stand`/`walk`/`jump`/`fall`) |
| `龙` | 60 | 29 | 5 deform meshes (2 skinned), FFD timeline, IK, 1 animation |
| `mecha_1004d` | 20 | 18 | 4 armatures in one file, 3 nested in slots, 10 animations |
| `unity/*` | 1–70 | 1–96 | 44 assets from the Unity SDK demos: nested armatures, skinned meshes, FFD, active IK, skin swapping |

The first three are hand-picked from the DragonBones assets shipped with
[Godot-DragonBones](https://github.com/DragonBones/Godot-DragonBones); the sweep
comes from the
[DragonBones Unity SDK](https://github.com/DragonBones/DragonBonesUnity)
(`Assets/DragonBones/Demos/Resources`). Both are animation *data*, MIT-licensed.

The sweep is fetched, not vendored: `tool/ground_truth/fetch_fixtures.sh` pulls the
skeleton/atlas JSON from a pinned revision (~1.6 MB, committed) and leaves the
11 MB of atlas images out — the geometry oracle reads regions and names out of the
tex JSON and never opens the PNGs. `--with-images` grabs them when you want pixels.

## Running

```bash
# 1. get the oracle runtime (clones + compiles the official TS runtime)
tool/ground_truth/fetch_runtime.sh

# 2. get the Unity SDK sweep fixtures (JSON only; ~1.6 MB)
tool/ground_truth/fetch_fixtures.sh

# 3. regenerate every reference dump (named ladder + the whole sweep)
tool/ground_truth/run_all.sh

# 4. check the Dart port against the dumps — this is the real test
dart run packages/dragonbones/tool/check_against_oracle.dart
```

Step 4 replays every asset frame by frame and diffs it against the official
runtime. It exits non-zero on the first asset that drifts, crashes or is missing a
dump, and prints one line per asset so a slow one never looks like a hang.

## Layout

```
tool/ground_truth/dump.js            headless oracle: official runtime -> JSON
tool/ground_truth/fetch_runtime.sh   fetches + compiles the official TS runtime
tool/ground_truth/fetch_fixtures.sh  fetches the Unity SDK demo assets
tool/ground_truth/run_all.sh         regenerates every dump
tool/ground_truth/out/*.json         committed reference dumps (the whole sweep)
test/fixtures/                       hand-picked assets used by both sides
test/fixtures/unity/                 Unity SDK sweep (JSON committed, PNGs not)
packages/dragonbones/                pure Dart runtime (no deps, no Flutter)
packages/dragonbones_flutter/        Canvas renderer: update() + render()
example/                             minimal Flutter app (dragon / mecha / 龙)
doc/FINDINGS.md                      investigation notes + evidence
```

## Licence

MIT (this repository). The DragonBones runtime and format are MIT
(© DragonBones team and contributors). Bundled DragonBones assets remain under
their original licence.
