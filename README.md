# DragonBones for Dart & Flutter

[![CI](https://github.com/RafaelBarbosatec/dragonbones_flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/RafaelBarbosatec/dragonbones_flutter/actions/workflows/ci.yml)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2.svg)](https://dart.dev)

Skeletal (bone-based) animation for **Dart**, **Flutter**, **Flame** and
**Bonfire**, from animations exported by **DragonBones** — the free, MIT
alternative to Spine and Rive.

> **Status: 0.1.0 — feature-complete for the common case, not for everything.**
> Both packages are publishable (`--dry-run` clean) but deliberately
> unpublished. See [Limitations](#limitations) for exactly what is missing —
> it is a short, specific list, not a vague disclaimer.

DragonBones is a 2D skeletal animation tool whose runtimes are MIT and exist
officially for TypeScript/JS, C++, C#, Java, Haxe and ActionScript — but **never
for Dart or Flutter**. This repository closes that gap.

## Why this exists

- Flame has `flame_spine`, `flame_rive` and `flame_lottie`, but **no
  DragonBones** bridge. `flame_spine` and `flame_rive` require paid tooling;
  DragonBones is free and MIT.
- There is an open Flame issue asking for exactly this, and the maintainers
  answered with an explicit invitation:

  > "We're not planning on implementing this from the core team, but if anyone
  > feels like creating a bridge package to live in the monorepo we're more than
  > happy to review it and take it in."
  > — [flame-engine/flame#3788](https://github.com/flame-engine/flame/issues/3788)

- For a real game the win is not "prettier sprites", it is **slot/skin swapping**
  (equip armour and weapons without authoring N sprites per combination),
  **deform meshes**, **bone attachment** (hitboxes, effect spawn points) and
  **animation events** (drive damage, sounds and projectiles from the
  animation itself).

## The two packages

| Package | What it is | Depends on |
| --- | --- | --- |
| [`dragonbones`](packages/dragonbones) | The runtime. Parses and evaluates the format, exposes the pose as a **framework-agnostic draw list**. | Nothing. Zero dependencies. |
| [`dragonbones_flutter`](packages/dragonbones_flutter) | The renderer. Turns that draw list into `Canvas` calls. | Flutter only — **not Flame**. |

The split is the whole point. The runtime has no Flutter in it, so its maths can
be verified with a **bare Dart SDK** — no GPU, no device, no eyeballing pixels.
Flutter is only needed for the layer that genuinely needs eyes.

The renderer is deliberately not coupled to any engine. It is two methods:

```dart
player.update(dt);     // advance the animation
player.render(canvas); // draw the pose
```

| Where you are | How you use it |
| --- | --- |
| Plain Flutter app | `DragonBonesWidget`, or your own `CustomPainter` |
| Flame game | call the two methods from a `Component` |
| Bonfire | call them from a `GameComponent` |
| Headless test / server | assert on `armature.buildDrawList()` — no Flutter at all |

The renderer never mutates engine objects: the runtime is driven through a
renderer-less factory and the pose is read back as a plain `SlotDrawData` list.
That is also why the geometry can be verified without a GPU.

## Quick start

Not on pub.dev yet (see [Publishing](#publishing)). For now, depend on it by
path or by git:

```yaml
dependencies:
  dragonbones_flutter:
    git:
      url: https://github.com/RafaelBarbosatec/dragonbones_flutter
      path: packages/dragonbones_flutter
```

```dart
final assets = await DragonBonesAssets.loadAsset(
  bundle: rootBundle,
  skeleton: 'assets/dragon/ske.json',
  texture: 'assets/dragon/tex.json',
  image: 'assets/dragon/tex.png',
);

final armature = assets.buildArmature('Dragon')!;
final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
player.play('walk');
```

Then, once per frame:

```dart
player.update(dt);
player.render(canvas);
```

Or skip the wiring entirely:

```dart
DragonBonesWidget(player: player, animation: 'walk', fit: DragonBonesFit.contain)
```

Full walkthrough: **[Getting started](https://docs.page/RafaelBarbosatec/dragonbones_flutter/getting-started)**.
Engine-specific recipes:
**[Integration](https://docs.page/RafaelBarbosatec/dragonbones_flutter/integration)**.

📖 **Documentation site: <https://docs.page/RafaelBarbosatec/dragonbones_flutter>**

## Verification is the point of this repository

The hard part of a port is not writing it, it is **being sure the maths is
right**. Rendering is visible; skeletal maths silently drifts — a bone off by a
few thousandths looks fine until a foot slides through the floor.

So correctness is not argued, it is **diffed against the official runtime**:

```
tool/ground_truth/     a node harness wrapping the OFFICIAL DragonBones runtime
                       (headless, no renderer) which dumps the armature state
                       frame by frame as JSON  ==  the oracle
packages/dragonbones/  the pure-Dart port; a test replays the same frames and
                       asserts every bone matrix, every slot draw datum, every
                       posed mesh vertex and every nested-armature slot matches
```

Measured on the current commit:

```
757701 numeric comparisons over 51 assets (51 clean, 0 failing)
74245 mesh values, 1228 nested-armature slots
RESULT: PASS
```

| What the sweep covers | How much |
| --- | ---: |
| Assets replayed, frame by frame | 51 |
| **Numeric assertions compared** | **757,701** |
| Mesh values (posed vertices, UVs, triangle indices) | 74,245 |
| Nested child-armature slots, with the parent slot's matrix composed on | 1,228 |
| Worst relative error anywhere | ~5e-5 |

Checked per frame: every bone's global matrix, every slot's draw data (world
matrix, pivot, quad size, atlas region, z-order, visibility, blend mode, colour),
every mesh's posed vertices, UVs and triangle indices, and every nested
armature's slots.

~5e-7 is the rounding precision of the reference dumps themselves, so the port
is effectively exact. The few values that peak higher (`mecha` at 5.2e-5) are the
assets with nested armatures, where composing two matrices per child slot
compounds the dumps' own rounding.

Three things this does **not** prove, stated plainly so they are not mistaken for
coverage — see
**[Limitations](https://docs.page/RafaelBarbosatec/dragonbones_flutter/limitations)**:

1. **It does not judge appearance.** CI runners have no GPU. The renderer tests
   rasterise and count painted pixels, which catches "wired wrong and drew
   nothing", not "drew it wrong". Eyes are still required for that.
2. **It only proves the features the assets use.** The 51 assets exercise
   sprites, skinned and FFD meshes, nested armatures, static IK and skin
   swapping. A feature no asset uses is a feature no test covers.
3. **The mesh oracle is the Egret binding, not the core runtime.** In
   DragonBones the per-vertex deformation lives in the *engine binding*:
   `Slot._updateMesh` is abstract and the core never implements it. The
   reference is therefore the official Egret binding, transcribed verbatim into
   both sides. This is documented in
   [Investigation findings](https://docs.page/RafaelBarbosatec/dragonbones_flutter/findings).

### Coverage

51 assets, deliberately a ladder rather than a random dump:

| Fixture | Bones | Slots | What it brings |
| --- | ---: | ---: | --- |
| `Dragon` | 19 | 18 | sprites only, 4 animations (`stand`/`walk`/`jump`/`fall`) |
| `龙` | 60 | 29 | 5 deform meshes (2 skinned), FFD timeline, IK |
| `mecha_1004d` | 20 | 18 | 4 armatures in one file, 3 nested in slots, 10 animations |
| `unity/*` (44 assets) | 1–70 | 1–96 | the whole DragonBones Unity SDK demo set: nested armatures, skinned meshes, FFD, **active IK**, skin swapping |

The first three come from [Godot-DragonBones](https://github.com/DragonBones/Godot-DragonBones);
the 44 come from the
[DragonBones Unity SDK](https://github.com/DragonBones/DragonBonesUnity)
(`Assets/DragonBones/Demos/Resources`). Both are animation *data*, MIT-licensed.

Notably, `you_xin/body` alone is 71 frames, 70 bones, 6,816 slot draw data and
47,357 mesh values in a single asset.

## Limitations

The honest list, for 0.1.0. Everything here is *parsed* but not *evaluated* —
which means a file using it will load and mostly animate, then be subtly wrong
rather than crash loudly. That is the dangerous kind, so it is spelled out.

### Not evaluated

| Feature | Status | What breaks |
| --- | --- | --- |
| **Animation events** (`EventObject`) | not ported | No `loopComplete` / `complete` / frame events. You cannot drive damage, sounds or projectiles from the animation. Callbacks fire nowhere. |
| **IK constraint timelines** (`IKConstraintTimelineState`) | not ported | **Static** IK is applied and verified. **Animated** IK weight/bend is ignored — a rig that animates its IK targets will drift. `_updateTimelines()` is a no-op. |
| **Path constraints** (`PathConstraint`) | data parsed, never built | Bones meant to follow a path do not. |
| **`Surface` bones** (`SurfaceTimelineState`) | model only | `SurfaceData`/`Surface` exist; the timeline is never created, so surfaces do not deform. |
| **`SlotZIndex` timeline** | not ported | Static z-order from the armature data works. A timeline animating z-index is ignored, so draw order will be wrong mid-animation. |
| **`BoneAlpha` / `SlotAlpha` timelines** | not ported | `AlphaTimelineState` exists but the timeline switch never instantiates it. The `SlotColor` timeline (which carries an alpha multiplier) *does* work. |
| **Animation blend timelines** (`AnimationProgress`, `AnimationWeight`, `AnimationParameter`) | not ported | Blending between animations (`AnimationBlendType`) is not evaluated. |
| **Binary `.dragonbones` input** (`BinaryDataParser`) | not ported | JSON export only. |

### Approximated in the renderer

| Item | Detail |
| --- | --- |
| **5 blend modes** | `Alpha`, `Erase`, `Invert`, `Layer`, `Subtract` have no exact Flutter counterpart and use the closest match. The other 9 map cleanly. No fixture in the test set uses the approximated five, so they are **unverified**. |
| **Rotated atlas entries** | The code path exists and is commented as untested — no fixture uses a rotated region. Treat as unverified. |

### Not verifiable here

| Item | Detail |
| --- | --- |
| **Appearance** | CI proves pixels are produced, not that they look right. |
| **Performance** | No benchmarks yet. Pooling was dropped (see *Deviations*), so allocation behaviour differs from upstream and has not been measured. |

### Deliberate deviations from upstream

- **No object pooling.** Upstream implements a per-class pool
  (`BaseObject.borrowObject`). Dart's GC handles this, so objects are constructed
  directly. This is the single biggest structural difference from the reference
  implementation.
- **An upstream bug was NOT transcribed.** `Slot.set displayFrameCount` reads
  `for (let i = prevCount - 1; i < value; --i)` — the condition is never true, so
  the loop body never runs upstream. The port uses `i >= value` so the removal
  actually happens.

## Roadmap

Ordered by what a real game project would hit first.

**Before 1.0 — the gaps that bite**

- [ ] **`EventObject` / animation events.** The highest-value missing piece: it
      is what turns an animation from decoration into gameplay. Needs the event
      dispatcher, `bufferEvent`, and the action/loop/complete/fade hooks.
- [ ] **`IKConstraintTimelineState`.** Static IK is verified; animated IK is not.
      Until this lands, a rig that animates IK weight is silently wrong.
- [ ] **`SlotZIndex` timeline.** Draw order is a correctness issue, not a polish
      one.
- [ ] **`SlotAlpha` / `BoneAlpha` timelines.** Per-slot fade without touching the
      colour timeline.
- [ ] **`PathConstraint` and `Surface` bones.** Completes the constraint model.

**Wanted, not blocking**

- [ ] **A `flame_dragonbones` convenience component** — a `PositionComponent`
      that owns an `Animation` and exposes it through Flame's lifecycle. The
      renderer already drops in; this is sugar, not capability.
- [ ] **A `Bonfire` adapter** with the `GameComponent` wiring and a hitbox from
      the armature's bounding box.
- [ ] **Better `computeBounds()`** for placement and hitboxes from the skeleton
      rather than re-measuring each frame.
- [ ] **Performance work and benchmarks**, including whether a light pool is
      worth reintroducing.
- [ ] **Binary `.dragonbones` support.**

**Correctness/process**

- [ ] Golden-image tests, if a GPU-less rasteriser can produce stable output.
      Right now appearance is the one thing CI cannot check.
- [ ] Expand the sweep to the DragonBones *Egret* demo set for more format
      coverage.

## Layout

```
tool/ground_truth/dump.js            headless oracle: official runtime -> JSON
tool/ground_truth/fetch_runtime.sh   fetches + compiles the official TS runtime
tool/ground_truth/fetch_fixtures.sh  fetches the Unity SDK demo assets
tool/ground_truth/run_all.sh         regenerates every reference dump
tool/ground_truth/out/*.json         committed reference dumps (the whole sweep)
test/fixtures/                       hand-picked assets used by both sides
test/fixtures/unity/                 Unity SDK sweep (JSON committed, PNGs not)
packages/dragonbones/                pure Dart runtime (no deps, no Flutter)
packages/dragonbones_flutter/        Canvas renderer: update() + render()
example/                             minimal Flutter app (Dragon / mecha / 龙)
docs.json                            docs.page configuration
docs/                                documentation site (docs.page)
docs/architecture.mdx                how it works + how it is verified
docs/limitations.mdx                 the honest gap list
docs/findings.mdx                    investigation notes + evidence
docs/publishing.mdx                  the exact release sequence
```

## Running the verification yourself

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
runtime. It exits non-zero on the first asset that drifts, or is missing a dump,
and prints one line per asset so a slow one never looks like a hang.

CI (`.github/workflows/ci.yml`) runs four jobs on every push: the dumps must be
**reproducible** from the official runtime, the runtime is analysed and diffed,
and the renderer plus the example app are analysed and tested under Flutter.

The atlas **images** are fetched, not vendored: the geometry oracle reads regions
and names out of the texture JSON and never opens the PNGs, so the 11 MB of
images stay out of the repository. `--with-images` grabs them when you want
pixels.

## Publishing

Both pubspecs carry `publish_to: none`. That is **deliberate**: a pub.dev release
cannot be deleted, only retracted, so the trigger is a human decision, not a CI
side effect. The current state:

| Package | `--dry-run` | Version |
| --- | --- | --- |
| `dragonbones` | clean — verified locally, gated in CI | 0.1.0 |
| `dragonbones_flutter` | cannot pass yet, **by design** — `pub publish` rejects its `path:` dependency on `dragonbones` until the runtime is on pub.dev | 0.1.0 |

[Publishing](https://docs.page/RafaelBarbosatec/dragonbones_flutter/publishing)
has the exact sequence and the reason for the order — the runtime must go out
first, because the renderer depends on it by `path:` and that has to become a
version constraint.

## Licence

MIT (this repository). The DragonBones runtime and format are MIT
(© DragonBones team and contributors). Bundled DragonBones animation assets
remain under their original licence.
