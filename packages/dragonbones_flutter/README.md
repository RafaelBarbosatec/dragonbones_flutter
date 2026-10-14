# dragonbones_flutter

[![pub package](https://img.shields.io/pub/v/dragonbones_flutter.svg)](https://pub.dev/packages/dragonbones_flutter)

Draw [DragonBones](https://dragonbones.github.io/en/animation.html) skeletal
animations on a Flutter `Canvas` — the free, MIT alternative to Spine and Rive.

The runtime lives in [`dragonbones`](https://pub.dev/packages/dragonbones) (pure
Dart, zero dependencies). This package is **only the renderer**.

> Available on pub.dev as
> [`dragonbones_flutter`](https://pub.dev/packages/dragonbones_flutter). Full
> docs: <https://docs.page/RafaelBarbosatec/dragonbones_flutter>.

## It is not coupled to any engine

Two methods:

```dart
player.update(dt);     // advance the animation
player.render(canvas); // draw the current pose
```

That is the whole contract. It depends on Flutter, **not on any game engine** — so
it drops into anything that hands you a `Canvas`:

| Where you are | How you use it |
| --- | --- |
| Plain Flutter app | `DragonBonesWidget`, or your own `CustomPainter` |
| Any game engine | call the two methods from its component/frame hook |
| Headless test / server | assert on `armature.buildDrawList()` — the runtime alone, no Flutter |

The renderer never mutates engine objects. The runtime is driven through a
renderer-less factory and the pose is read back as a plain `SlotDrawData` list —
which is also why every number it draws can be verified without a GPU.

## Installing

```yaml
dependencies:
  dragonbones_flutter: ^0.3.0
```

This pulls in [`dragonbones`](https://pub.dev/packages/dragonbones), the runtime,
as a transitive dependency — you do not add it yourself.

## Usage

```dart
final assets = await DragonBonesAssets.loadAsset(
  bundle: rootBundle,
  skeleton: 'assets/dragon/ske.json',
  texture: 'assets/dragon/tex.json',
  image: 'assets/dragon/tex.png',
);

final armature = assets.buildArmature('Dragon')!;
final player = DragonBonesPlayer(armature, assets: assets);

player.play('walk');

// Once per frame — from a widget, a Ticker, a game loop, wherever:
player.update(dt);
player.render(canvas);
```

Or skip the wiring with the widget, which owns a `Ticker` for you:

```dart
DragonBonesWidget(
  player: player,
  animation: 'walk',
  fit: DragonBonesFit.contain,
)
```

`fit` handles placement: `player.fit(size: size, fit: DragonBonesFit.contain,
align: Alignment.topLeft)` writes `scale`/`offset`, so an engine component only
has to pass its box. The modes are `contain`, `cover`, `fitWidth`, `fitHeight`
and `none`. Build the player with `assets:` (or `assets.createPlayer(...)`) and
the first `fit` measures a stable box across every clip once — placement then
does not move with the animation, and `fit` does not measure per frame. Without
`assets`, `fit` uses the current pose, and `computeBounds()` gives you that
pose's bounds for hitboxes. For a fully manual placement, set `player.scale` and
`player.offset`, or pass them per call to `render()`.

## What it draws

Sprites (`drawImageRect`) **and** deformable meshes (`drawVertices` +
`ImageShader`), including skinned meshes driven by bone weights and animated FFD.
Nested child armatures — a weapon or an effect armature mounted on a slot — are
flattened into the draw list with the parent slot's transform composed onto them,
so the renderer never has to know they exist.

Slot colour transforms, including per-channel **offsets**, are applied through a
`ColorFilter.matrix`; the common identity case costs nothing.

## Verification

This package is the thin part on purpose: the geometry it draws is not
hand-waved. The runtime underneath is diffed frame by frame against the
**official DragonBones runtime**, across the hand-picked ladder and all 44 demo
assets from the DragonBones Unity SDK — bone matrices, slot transforms, atlas
regions, posed mesh vertices, UVs, triangle indices and nested-armature
composition:

```
757701 numeric comparisons over 51 assets (51 clean, 0 failing)
74245 mesh values, 1228 nested-armature slots
RESULT: PASS
```

On top of that, this package's own tests replay **every one of the fixtures
through the real renderer** with a synthetic atlas, proving that the sprite and
mesh paths survive every asset in the set — and that no asset is silently
skipped. The tests assert that meshes were actually drawn, so the coverage cannot
quietly rot.

### What CI does not judge

**How it looks.** Runners have no GPU. The tests rasterise and count painted
pixels, which catches "wired wrong and drew nothing" — not "drew it wrong".
Eyeballs are still required for that.

## Animation events

The runtime reports what happens on the timeline — a footstep the animator
placed, or simply that an animation ended — and this package wires that through,
so a widget can react:

```dart
player.armature.eventDispatcher.addDBEventListener(
  EventObject.COMPLETE,
  (event) => setState(() => _state = 'idle'),
);
```

`FRAME_EVENT` and `SOUND_EVENT` come from the timeline; `START`,
`LOOP_COMPLETE`, `COMPLETE`, `FADE_IN` / `FADE_OUT` and their `...Complete`
counterparts come from the animation itself. They arrive **after** the frame is
posed, so a listener may play another animation. A `soundEvent` is delivered
twice — once on the armature and once on the hub's `eventManager` — so hook audio
in one place only. The runtime never plays audio; it reports names.

Full reference — `removeDBEventListener`, the event-type table, custom payloads
and the global `eventManager`:
**[Animation events](https://docs.page/RafaelBarbosatec/dragonbones_flutter/events)**.

## Known limitations

Inherited from the runtime (the renderer cannot draw what is not evaluated):

- **Animated IK is ignored** — static IK works.
- **`SlotZIndex` timeline** is not evaluated, so animated draw order will be
  wrong.
- **Path constraints and `Surface` bones** are not evaluated.

(`SlotAlpha` / `BoneAlpha` — per-slot and per-bone fade — **are** evaluated as
of `[NEXT]`; the effective alpha is folded into the slot colour.)

Specific to this package:

| Item | Detail |
| --- | --- |
| **5 blend modes approximated** | `Alpha`, `Erase`, `Invert`, `Layer` and `Subtract` have no exact Flutter counterpart, so the closest `ui.BlendMode` is used. The other 9 map cleanly. No fixture in the test set uses the approximated five — treat them as **unverified**. |
| **Rotated atlas entries** | The code path exists and is commented in-source as untested; no fixture uses a rotated region. Treat as unverified. |
| **No benchmarks** | Allocation behaviour differs from upstream because object pooling was dropped. Unmeasured. |

The full list, including what is verified and how, is on the documentation site:
**[Limitations](https://docs.page/RafaelBarbosatec/dragonbones_flutter/limitations)**
and
**[Architecture & verification](https://docs.page/RafaelBarbosatec/dragonbones_flutter/architecture)**.

## Licence

MIT. The DragonBones runtime and format are MIT (© DragonBones team and
contributors).