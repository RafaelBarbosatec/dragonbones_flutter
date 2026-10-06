/// Draw DragonBones skeletal animations on a Flutter [Canvas].
///
/// This package deliberately does **not** depend on Flame (or any game engine).
/// Everything hangs off two methods, so it works anywhere:
///
/// ```dart
/// final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
/// player.play('walk');
///
/// // in your frame loop / ticker
/// player.update(dt);
/// player.render(canvas);
/// ```
///
/// * a plain Flutter app — wrap it in [DragonBonesWidget], or call the two
///   methods from your own `CustomPainter`;
/// * a Flame game — call `update`/`render` from a `Component`;
/// * Bonfire — same, from a `GameComponent`;
/// * a headless test — the geometry is already verified against the official
///   runtime, so you can assert on `armature.buildDrawList()`.
library dragonbones_flutter;

// Re-exported so callers get the runtime types without importing two packages.
// `BlendMode` is hidden because it collides with `dart:ui`'s.
export 'package:dragonbones/dragonbones.dart' hide BlendMode;

export 'src/assets.dart';
export 'src/player.dart';
export 'src/widget.dart';
