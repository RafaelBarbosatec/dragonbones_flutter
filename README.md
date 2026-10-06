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

The oracle harness is verified working: `Dragon` (19 bones, sprites only, 4
animations) and `龙` (60 bones, 29 slots, deformable meshes, IK) both dump
cleanly. See `doc/FINDINGS.md` for the full investigation.

## Status

| Piece | State |
| --- | --- |
| Oracle harness (node + official runtime) | ✅ working — both fixtures dump |
| Reference dumps committed | ✅ `tool/ground_truth/out/*.json` |
| Dart runtime port | ✅ **milestone 1 verified** — `Dragon` (sprites, bone timelines) matches the official runtime to ~5e-7 |
| `drawVertices` renderer for Flame | 🚧 not started |
| Example Flame app | 🚧 not started |

### Milestone 1 result

```
  rest     2 frames, 19 bones,  36 slot draw-data, max err 4.945e-7  OK
  stand   31 frames, 19 bones, 558 slot draw-data, max err 5.000e-7  OK
  walk    21 frames, 19 bones, 378 slot draw-data, max err 4.997e-7  OK
  jump     6 frames, 19 bones, 108 slot draw-data, max err 4.987e-7  OK
  fall     6 frames, 19 bones, 108 slot draw-data, max err 4.992e-7  OK

33660 numeric comparisons, 0 mismatches (tolerance 0.0001)
RESULT: PASS
```

Checked per frame: every bone's global matrix, **and** every slot's draw data —
world matrix, pivot, quad size, atlas region, z-order, visibility, blend mode and
colour. That is the complete geometry a renderer needs, so drawing it is a thin,
low-risk step rather than guesswork.

~5e-7 is the rounding precision of the reference dumps themselves, so the port is
effectively exact. `dart analyze` is clean and both checks run in CI.

Not yet: deform meshes / FFD, IK constraints (the `龙` fixture), and the canvas
renderer.

## Fixtures

Two animations exported with DragonBones Pro 5.6, format version **5.5**.
They are a deliberate ladder:

| Fixture | Bones | Slots | Features | Milestone |
| --- | ---: | ---: | --- | --- |
| `Dragon` | 19 | 18 | sprites only, 4 animations (`stand`/`walk`/`jump`/`fall`) | 1 |
| `龙` | 60 | 29 | 5 deform meshes, FFD timeline, IK, 1 animation | 2 |

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
packages/flame_dragon_bones/    Flame/Bonfire component (drawVertices)
doc/FINDINGS.md                 investigation notes + evidence
```

## Licence

MIT (this repository). The DragonBones runtime and format are MIT
(© DragonBones team and contributors). Bundled DragonBones assets remain under
their original licence.
