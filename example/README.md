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
