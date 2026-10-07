# Example — DragonBones on a plain Flutter Canvas

Draws the `Dragon` fixture and lets you switch between its animations
(`stand`, `walk`, `jump`, `fall`).

There is **no game engine here**. The renderer is driven by two calls:

```dart
player.update(dt);     // advance the animation
player.render(canvas); // draw the pose
```

## Running it

Flutter apps need their platform folders (`android/`, `ios/`, `linux/`, …),
which are not committed. Generate them once, then run:

```bash
cd example
flutter create .                    # generates the platform folders
git checkout -- lib/main.dart       # flutter create overwrites it — this committed
                                    # example is the one you want
rm -f test/widget_test.dart         # boilerplate that flutter create adds
flutter run                         # pick a device, or: flutter run -d linux / -d macos
```

## Interactive posing — head follows the pointer

The `mouse` button in the app bar opens `lib/head_follow_page.dart`, which makes
the `Dragon`'s `head` bone look towards the mouse / finger while the animation
keeps playing, and mirrors the head when the pointer crosses to the other side.
It shows the runtime's external-control hook: the final local transform of a
bone is

```text
global = setup(origin) + offset(external) + animationPose(animation)
```

The animation writes `animationPose`; the app writes `head.offset.rotation` every
frame and calls `head.invalidUpdate()`. Because the offset is additive, the head
can be aimed at any point without disturbing the rest of the animation, and the
child bones (`eyeR` / `eyeL`) and slots follow automatically.

Two pitfalls to avoid:

- **Do not** compute `offset = target - head.global.rotation`. `global.rotation`
  already includes the offset from the previous frame, so this double-counts and
  the head oscillates. Recover the un-offset pose first:

```dart
final head = armature.getBone('head')!;
final desired = math.atan2(targetY - head.globalTransformMatrix.ty,
                          targetX - head.globalTransformMatrix.tx);

// `offset` acts on `global.rotation` with a fixed sign; strip it to get the
// pose the animation produced, then aim that at the target.
final base = head.global.rotation - head.offset.rotation;
head.offset.rotation = Transform.normalizeRadian(desired - base);
head.invalidUpdate();
```

- **The bone's +x axis is not where the face points.** The Dragon's tail sticks
  out at +x (its back) and the head bone points up, so aiming the bone axis at
  the pointer makes the dragon look *away* (~172° off). The page calibrates the
  real face direction once, from the geometry (`mane` → `eyes`), and rotates
  that vector instead.

The flip mirrors **only the head**, not the whole body. The head bone points up,
so a left-right mirror is `scaleY = -1` (mirroring `scaleX` would flip it upside
down):

```dart
head.offset.scaleY = pointerIsToTheRight ? -1.0 : 1.0;
head.invalidUpdate();
```

The mirror is baked into the head's matrix, so the aim needs no extra sign
correction — only the base recovery above.

Use `DragonBonesFit.none` with a fixed `player.scale` / `player.offset` for this
kind of interaction: `DragonBonesFit.contain` recomputes the placement every
frame, so the screen-to-armature mapping would not be stable.

## Using the renderer in your own project

```dart
final assets = await DragonBonesAssets.loadAsset(
  bundle: rootBundle,
  skeleton: 'assets/Dragon_ske.json',
  texture: 'assets/Dragon_tex.json',
  image: 'assets/Dragon_tex.png',
);

final armature = assets.buildArmature('Dragon')!;
final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
player.play('walk');

// Option A — let the widget drive it:
DragonBonesWidget(player: player, fit: DragonBonesFit.contain)

// Option B — drive it yourself from your own frame loop
// (an engine component, a `CustomPainter`, …):
player.update(dt);
player.render(canvas);
```

The `dragonbones_flutter` package re-exports the runtime types, so
`import 'package:dragonbones_flutter/dragonbones_flutter.dart';` is enough.

## Assets

`assets/` holds the same DragonBones fixtures used by the tests and by the
oracle harness (exported with DragonBones Pro 5.6, format 5.5). They come from
the assets shipped with
[Godot-DragonBones](https://github.com/DragonBones/Godot-DragonBones)
(`demo/dragonbones_demo/assets`).

The `龙` fixture is present too: it has deformable meshes and IK, which the
renderer does **not** draw yet (mesh support is the next milestone). Loading it
works, and `DragonBonesPlayer.skippedMeshSlots` reports how many slots were
skipped — useful for checking exactly what is missing.
