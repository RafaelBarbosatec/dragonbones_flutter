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

The oracle harness is verified working on all three fixtures: `Dragon` (19 bones,
sprites only, 4 animations), `龙` (60 bones, 29 slots, 5 deformable meshes, FFD
timelines, IK) and `mecha_1004d` (4 armatures in one file, 3 of them nested
inside slots of the first). See `doc/FINDINGS.md` for the full investigation.

## Status

| Piece | State |
| --- | --- |
| Oracle harness (node + official runtime) | ✅ working — all three fixtures dump |
| Reference dumps committed | ✅ `tool/ground_truth/out/*.json` |
| Dart runtime port | ✅ **verified** — bone matrices, sprite draw data, mesh geometry and nested armatures all match the official runtime to ~5e-7 |
| Canvas renderer (`update` + `render`), no engine coupling | ✅ sprites **and** meshes (`drawVertices`) |
| Nested child armatures | ✅ built, animated and flattened into the draw list |
| Example Flutter app | ✅ `example/` — run it to see it |
| FFD / deform timelines | ✅ ported (`DeformTimelineState`) |
| Path constraints, `Surface` bones, animation events (`EventObject`) | 🚧 not ported |

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
  rest     2 frames, 19 bones,  36 slot draw-data, max err 4.945e-7  OK
  stand   31 frames, 19 bones, 558 slot draw-data, max err 5.000e-7  OK
  walk    21 frames, 19 bones, 378 slot draw-data, max err 4.997e-7  OK
  jump     6 frames, 19 bones, 108 slot draw-data, max err 4.987e-7  OK
  fall     6 frames, 19 bones, 108 slot draw-data, max err 4.992e-7  OK
  long    31 frames, 60 bones, 899 slot draw-data, 21173 mesh values, max err 5.000e-7  OK
  mecha   59 frames, 20 bones, 826 slot draw-data, max err 5.202e-5  OK

172925 numeric comparisons, 0 mismatches (tolerance 0.0001)
21173 mesh values, 118 nested-armature slots
RESULT: PASS
```

Checked per frame: every bone's global matrix, every slot's draw data (world
matrix, pivot, quad size, atlas region, z-order, visibility, blend mode, colour),
every mesh's **posed vertices, UVs and triangle indices**, and every nested
armature's slots with the parent slot's matrix composed onto them. That is the
complete geometry a renderer needs, so drawing it is a thin, low-risk step rather
than guesswork.

~5e-7 is the rounding precision of the reference dumps themselves, so the port is
effectively exact (`mecha` reaches 5.2e-5 purely because composing two matrices
per child slot compounds the dump's own rounding). `dart analyze` is clean and
all checks run in CI.

**One caveat worth stating plainly**: the oracle for *mesh* geometry is the
official **Egret binding** (`.ref/egret-binding/EgretSlot.ts`), not the core
runtime — because in DragonBones the per-vertex deformation lives in the engine
binding: `Slot._updateMesh` is abstract and the core never implements it. So that
transcription is the reference, and it is transcribed verbatim in both the oracle
(`tool/ground_truth/dump.js`) and the port
(`packages/dragonbones/lib/src/render/mesh_geometry.dart`).

Not yet: path constraints, `Surface` bones, animation events (`EventObject`),
and `SlotZIndex` / `SlotAlpha` timelines.

## Fixtures

Three animations exported with DragonBones Pro 5.6, format version **5.5**.
They are a deliberate ladder:

| Fixture | Bones | Slots | Features |
| --- | ---: | ---: | --- |
| `Dragon` | 19 | 18 | sprites only, 4 animations (`stand`/`walk`/`jump`/`fall`) |
| `龙` | 60 | 29 | 5 deform meshes (2 skinned), FFD timeline, IK, 1 animation |
| `mecha_1004d` | 20 | 18 | 4 armatures in one file, 3 nested in slots, 10 animations |

Assets come from the DragonBones assets shipped with
[Godot-DragonBones](https://github.com/DragonBones/Godot-DragonBones)
(`demo/dragonbones_demo/assets`). They are animation *data*, MIT-licensed.

## Running

```bash
# 1. get the oracle runtime (clones + compiles the official TS runtime)
tool/ground_truth/fetch_runtime.sh

# 2. regenerate every reference dump
tool/ground_truth/run_all.sh

# 3. (once the port exists) check the Dart port against the dumps
dart run packages/dragonbones/tool/check_against_oracle.dart
```

## Layout

```
tool/ground_truth/dump.js       headless oracle: official runtime -> JSON
tool/ground_truth/run_all.sh    regenerates every dump
tool/ground_truth/out/*.json    committed reference dumps
test/fixtures/                  DragonBones assets used by both sides
packages/dragonbones/           pure Dart runtime (no deps, no Flutter)
packages/dragonbones_flutter/   Canvas renderer: update() + render(), sprites + meshes
example/                        minimal Flutter app (dragon / mecha / 龙)
doc/FINDINGS.md                 investigation notes + evidence
```

## Licence

MIT (this repository). The DragonBones runtime and format are MIT
(© DragonBones team and contributors). Bundled DragonBones assets remain under
their original licence.
