// A runnable example of the headless runtime: no Flutter, no assets on disk,
// no GPU. The DragonBones Pro export is embedded below so the file is
// self-contained.
//
// Run it with:
//   dart run example/example.dart
//
// The interesting part is the last step. `Armature.buildDrawList()` is the seam
// a renderer consumes: the runtime resolves every bone matrix, every display
// and every mesh vertex, and hands back plain numbers. The Flutter renderer in
// `packages/dragonbones_flutter` turns that list into canvas calls; a game
// engine component would turn the same list into components. Nothing here (and
// nothing in the runtime) imports `dart:ui`.
import 'dart:convert';
import 'dart:math' as math;

import 'package:dragonbones/dragonbones.dart';

/// A minimal DragonBones 5.5 skeleton: two bones (`root` -> `arm`), one image
/// slot, and a looping animation that swings the arm from 0 to 60 degrees over
/// one second.
///
/// The display sits 10px out along the `arm` bone, so the rotation is visible
/// in the numbers: the sprite orbits the bone origin.
const String skeletonJson = '''
{
  "frameRate": 24,
  "name": "Example",
  "version": "5.5",
  "compatibleVersion": "5.5",
  "armature": [
    {
      "type": "Armature",
      "frameRate": 24,
      "name": "Armature",
      "aabb": { "x": -20, "y": -20, "width": 40, "height": 40 },
      "bone": [
        { "name": "root" },
        { "name": "arm", "parent": "root", "transform": { "x": 0, "y": 0 } }
      ],
      "slot": [
        { "name": "box", "parent": "arm" }
      ],
      "skin": [
        {
          "name": "",
          "slot": [
            {
              "name": "box",
              "display": [
                { "type": "image", "name": "box", "transform": { "x": 10, "y": 0 } }
              ]
            }
          ]
        }
      ],
      "animation": [
        {
          "duration": 24,
          "playTimes": 0,
          "name": "wave",
          "bone": [
            {
              "name": "arm",
              "rotateFrame": [
                { "duration": 12, "tweenEasing": 0, "rotate": 0, "transform": { "x": 0, "y": 0 } },
                { "duration": 12, "tweenEasing": 0, "rotate": 60, "transform": { "x": 0, "y": 0 } }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

/// The matching texture atlas: a single 10x10 region called `box`.
///
/// The runtime never touches an image — it only resolves *which* atlas region a
/// slot should sample, and where it lands. Loading the pixels is the caller's
/// job, which is what makes the runtime usable headlessly.
const String atlasJson = '''
{
  "name": "Example",
  "imagePath": "example.png",
  "width": 20,
  "height": 20,
  "SubTexture": [
    { "name": "box", "x": 0, "y": 0, "width": 10, "height": 10 }
  ]
}
''';

/// The rotation baked into a 2D transform matrix, in degrees.
double _rotationDegrees(Matrix m) => math.atan2(m.b, m.a) * 180.0 / math.pi;

void main() {
  // 1. Parse the export. `HeadlessFactory` builds slots whose engine-side render
  //    hooks are no-ops, so nothing here needs a canvas.
  final factory = HeadlessFactory();
  final data = factory.parseDragonBonesData(jsonDecode(skeletonJson));
  if (data == null) {
    throw StateError('the skeleton JSON could not be parsed');
  }
  factory.parseTextureAtlasData(jsonDecode(atlasJson), null, 'Example');

  print('parsed "${data.name}": armatures=${data.armatureNames}');

  // 2. Build an armature and start an animation.
  final armature = factory.buildArmature('Armature', 'Example');
  if (armature == null) {
    throw StateError('the armature could not be built');
  }
  armature.animation.play('wave');

  final arm = armature.getBone('arm')!;
  print('bones=${armature.getBones().map((b) => b.name).toList()}');

  // 3. Advance one frame at a time. `advanceTime` is the whole API surface a
  //    game engine needs to drive: one call per frame with the elapsed seconds.
  //    (Right after `buildArmature` the armature is still in its bind pose — the
  //    animation only takes effect once time is advanced.)
  const frameRate = 24;
  for (var frame = 3; frame <= 12; frame += 3) {
    for (var i = 0; i < 3; i++) {
      armature.advanceTime(1.0 / frameRate);
    }
    final m = arm.globalTransformMatrix;
    final draw = armature.buildDrawList().single;
    print(
      'frame ${frame.toString().padLeft(2)}  '
      't=${(frame / frameRate).toStringAsFixed(3)}s  '
      'arm rotation=${_rotationDegrees(m).toStringAsFixed(2).padLeft(6)}°  '
      'sprite at (${draw.matrix.tx.toStringAsFixed(3)}, '
      '${draw.matrix.ty.toStringAsFixed(3)})',
    );
  }

  // 4. Read the posed result back as a framework-agnostic draw list. This is
  //    what a binding iterates over; every number below is in armature space.
  for (final item in armature.buildDrawList()) {
    final region = item.texture;
    print(
      'draw "${item.slotName}" '
      'quad=${item.quadWidth}x${item.quadHeight} '
      'texture=${region?.name} '
      'region=(${region?.region.x}, ${region?.region.y}) '
      'zOrder=${item.zOrder} visible=${item.visible} '
      'mesh=${item.mesh == null ? 'no' : 'yes'}',
    );
  }
}
