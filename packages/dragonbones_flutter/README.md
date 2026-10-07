# dragonbones_flutter

Draw [DragonBones](https://github.com/DragonBones/DragonBones) skeletal animations
on a Flutter `Canvas` — the free, MIT alternative to Spine and Rive.

The runtime lives in [`dragonbones`](https://pub.dev/packages/dragonbones) (pure
Dart, zero dependencies). This package is only the renderer.

## It is not coupled to any engine

Two methods:

```dart
player.update(dt);     // advance the animation
player.render(canvas); // draw the current pose
```

That is the whole contract. It depends on Flutter, **not on Flame** — so it drops
into anything that hands you a `Canvas`:

| Where | How |
| --- | --- |
| Plain Flutter app | `DragonBonesWidget`, or your own `CustomPainter` |
| Flame game | call the two methods from a `Component` |
| Bonfire | call them from a `GameComponent` |
| Headless test | assert on `armature.buildDrawList()` |

The renderer never mutates engine objects. The runtime is driven through a
renderer-less factory and the pose is read back as a plain `SlotDrawData` list —
which is also why every number it draws can be verified without a GPU.

## Usage

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

// In a widget or your own painter:
player.update(dt);
player.render(canvas);
```

Or skip the wiring with the widget:

```dart
DragonBonesWidget(
  player: player,
  animation: 'walk',
  fit: DragonBonesFit.contain,
)
```

## What it draws

Sprites (`drawImageRect`) **and** deformable meshes (`drawVertices` +
`ImageShader`), including skinned meshes driven by bone weights and animated FFD.
Nested child armatures — a weapon or effect armature mounted on a slot — are
flattened into the draw list with the parent slot's transform composed onto them,
so a renderer never has to know they exist.

## Verification

This package is the thin part on purpose: the geometry it draws is not
hand-waved. The runtime is diffed frame by frame against the **official
DragonBones runtime**, across three hand-picked fixtures and all 44 demo assets
from the DragonBones Unity SDK — bone matrices, slot transforms, atlas regions,
posed mesh vertices, UVs, triangle indices and nested-armature composition:

```
757701 numeric comparisons over 51 assets (51 clean, 0 failing)
74245 mesh values, 1228 nested-armature slots
RESULT: PASS
```

The harness, the reference dumps and the notes on what is *not* covered live in the
repository: <https://github.com/RafaelBarbosatec/flame_dragon_bones>.

What CI does not judge: how it *looks*. Runners have no GPU. The tests rasterise
and count painted pixels, which catches "wired wrong and drew nothing" — not "drew
it wrong". Eyeballs still required for that.

## Licence

MIT. The DragonBones runtime and format are MIT (© DragonBones team and
contributors).
