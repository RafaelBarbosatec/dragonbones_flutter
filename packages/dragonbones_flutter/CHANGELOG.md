# Changelog

## 0.1.0

First release. Draws DragonBones skeletal animations on a Flutter `Canvas`
through two methods, `update(dt)` and `render(canvas)` — with no dependency on
Flame or any other engine, so the same code drops into a plain Flutter app, a
Flame `Component`, a Bonfire `GameComponent`, or a `CustomPainter`.

- Sprites (`drawImageRect`) and deformable meshes (`drawVertices` +
  `ImageShader`), including skinned meshes with bone weights and animated FFD.
- Nested child armatures flattened into the draw list, with the parent slot's
  transform composed onto them.
- Slot colour transforms applied through `ColorFilter.matrix`, including
  per-channel offsets; the identity case is free.
- `DragonBonesWidget` with `DragonBonesFit`, and a `computeBounds()` extension
  for placement and hitboxes.

Built on [`dragonbones`](https://pub.dev/packages/dragonbones) 0.1.0, whose
geometry is diffed against the official DragonBones runtime across 51 assets —
757,701 numeric comparisons, 0 mismatches. This package's own tests replay every
one of those fixtures through the real renderer to prove no asset is silently
skipped.

### Known limitations in this release

Inherited from the runtime (the renderer cannot draw what is not evaluated):

- **No animation events** (`EventObject`) — nothing can be driven from the
  animation.
- **Animated IK is ignored** (static IK works).
- **`SlotZIndex` and `SlotAlpha` / `BoneAlpha` timelines** are not evaluated, so
  animated draw order and per-slot fade will be wrong.
- **Path constraints and `Surface` bones** are not evaluated.

Specific to this package:

- **`Alpha`, `Erase`, `Invert`, `Layer` and `Subtract`** blend modes have no
  exact Flutter counterpart and use the closest `ui.BlendMode`. The other nine
  map cleanly. No fixture uses the approximated five — unverified.
- **Rotated atlas entries** have a code path that no fixture exercises — unverified.
- **Appearance is not checked by CI.** Runners have no GPU; tests rasterise and
  count painted pixels, which catches "wired wrong and drew nothing", not "drew
  it wrong".
- **No benchmarks.** Allocation behaviour differs from upstream because pooling
  was dropped.
