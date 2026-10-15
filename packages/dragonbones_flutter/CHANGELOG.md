# Changelog

## 0.4.0

**Stable placement, and the newer timelines reach the Canvas.**

- Build a `DragonBonesPlayer` with `DragonBonesAssets` —
  `DragonBonesPlayer(armature, assets: assets)` — and the image resolver is wired
  for you; `DragonBonesAssets.createPlayer(name)` builds the armature too. No
  manual `resolveImage:` or `measureBounds` call.
- `DragonBonesPlayer.skeletonBounds` + `DragonBonesAssets.measureBounds`: the
  first `fit` measures the union across every animation **once** (using a
  throwaway armature, so the live one is never disturbed) and caches it.
  Placement then stops depending on the current frame, and `fit` no longer builds
  a draw list just to place the character.
- `fit` resolves bounds as: explicit `bounds`, then `skeletonBounds`, then the
  current pose — `useCurrentPose: true` forces the last.
- `fit`'s `align` now positions the scaled art inside the leftover space
  (Flutter `Align` semantics), so it touches the aligned edge without leaving the
  box: `Alignment.bottomCenter` is feet on the bottom, not half the character
  below.
- Depend on `dragonbones: ^0.3.0`, so `SlotAlpha` / `BoneAlpha` and `SlotZIndex`
  reach the Canvas (the effective alpha rides in the slot colour, the draw list
  arrives pre-sorted). No renderer code changed for those.

Requires `dragonbones: ^0.3.0`.

## 0.3.0

**Placement is now the player's job.** `DragonBonesPlayer.fit` measures the
current pose and writes `scale`/`offset` from the box you render into, so a
Flame/Bonfire component no longer computes them by hand:

```dart
player
  ..play('idle')
  ..update(0)
  ..fit(
    size: Size(size.x, size.y),
    fit: DragonBonesFit.contain,
    align: Alignment.bottomCenter,
  );
```

- `DragonBonesFit` gains `cover`, `fitWidth` and `fitHeight` alongside
  `contain` and `none`. `fit` also takes an optional `bounds` to pin a clip
  whose silhouette changes (a sword swing), and returns the bounds it fitted.
- `computeBounds()` moves from the `DragonBonesPlayerGeometry` extension onto
  `DragonBonesPlayer` itself; the call site (`player.computeBounds()`) is
  unchanged.
- `DragonBonesWidget` delegates its own fit to `player.fit`, so the widget and a
  hand-written engine component place an armature with the same numbers.
- The Bonfire example drops its manual `min(...)`/`abs()` placement in favour of
  the method.

Requires `dragonbones: ^0.2.0`.

## 0.2.0

**Animation events reach the player.** `dragonbones` gained a full event system
(see its changelog); this release wires it up, so a Flutter app can react to a
footstep or to an animation finishing.

```dart
player.armature.eventDispatcher.addDBEventListener(
  EventObject.COMPLETE,
  (event) => setState(() => _state = 'idle'),
);
```

- `DragonBonesPlayer.update` now advances the **hub** (`DragonBones.advanceTime`)
  rather than the armature. That is what makes buffered events dispatch, and it
  is what the official bindings do. Behaviour is unchanged for a non-zero step;
  a zero step (`update(0)`, used to recompute the pose without advancing time)
  still takes the direct path, because the hub's clock ignores a zero step.
- The headless display behind `DragonBonesAssets` now carries a real dispatcher,
  so `player.armature.eventDispatcher` works with no Flutter binding involved.
- A `soundEvent` is delivered twice — once on the armature and once on the hub's
  `eventManager`. Hook audio in **one** of the two.

Requires `dragonbones: ^0.2.0`.

Also in this release: the arms of the 46 bundled example characters are wired to
the events, and `update(0)` is covered by a test.

## 0.1.1

Packaging and hygiene release after the first publish. No change to the drawing:
the tests that replay every runtime fixture through the real renderer behave
exactly as they did in 0.1.0.

**pub.dev score fixes.** The 0.1.0 archive lost 30 of its 160 pub points, all of
it recoverable:

- `description` shortened from 216 to 142 characters. Pub.dev rejects anything
  over 180, and that single field cost the whole 10-point "valid `pubspec.yaml`"
  section.
- Added `example/example.dart`, a small app that draws an armature with no asset
  files at all — the skeleton and atlas are embedded and the raster is generated
  in memory. That is the 10-point "package has an example" section, and it gives
  `DragonBonesWidget` a copy-pasteable entry point.
- `analysis_options.yaml` now also carries `package:lints/core.yaml`, the set
  pub.dev's `pana` merges *over* a package's own options, plus
  `formatter: page_width: 120`. Two rules existed on pub.dev's side and nowhere
  on ours — `strict_top_level_inference` and `unintended_html_in_doc_comment`,
  both newer than `flutter_lints` 4.x — so they were unreachable from CI. They
  are checked now.
- CI gates formatting, because pub.dev scores it.

**Fixed:** the README's opening `DragonBones` link was malformed — a duplicated
closing bracket made the destination a URL containing `](`. It rendered as
broken text on the pub.dev page.

## 0.1.0

First release. Draws DragonBones skeletal animations on a Flutter `Canvas`
through two methods, `update(dt)` and `render(canvas)` — with no dependency on
any game engine, so the same code drops into a plain Flutter app, an engine
component, or a `CustomPainter`.

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
