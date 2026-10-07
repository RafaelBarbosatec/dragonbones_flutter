// A runnable example of the renderer: one armature drawn on a Flutter Canvas,
// with no asset files at all.
//
// The skeleton and atlas are embedded as strings and the atlas image is
// generated in memory, so this file is self-contained — no `assets:` section, no
// PNG to ship, nothing to fetch. A real app loads them from its bundle instead
// (`DragonBonesAssets.loadAsset(bundle: rootBundle, ...)`); everything after that
// call is identical.
//
// Run it with:
//   flutter run -t example/example.dart
//
// Note the imports: this package re-exports the whole runtime, and the runtime
// has its own `Transform` and `Animation` classes, so those two names would be
// ambiguous next to `package:flutter/widgets.dart`. The example simply does not
// use them.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter/widgets.dart';

/// A minimal DragonBones 5.5 skeleton: two bones (`root` -> `arm`), one image
/// slot, and a looping animation that swings the arm from 0 to 60 degrees.
///
/// The display sits 10px out along the `arm` bone, so the rotation is visible:
/// the sprite orbits the bone origin.
const String _skeletonJson = '''
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

/// The matching texture atlas: a single 10x10 region called `box`. The renderer
/// only needs to know *which* region to sample and where it lands; the pixels
/// come from the `ui.Image` below.
const String _atlasJson = '''
{
  "name": "Example",
  "imagePath": "example.png",
  "width": 16,
  "height": 16,
  "SubTexture": [
    { "name": "box", "x": 0, "y": 0, "width": 10, "height": 10 }
  ]
}
''';

/// The raster the atlas points at, drawn in memory: a 16x16 checker, so the
/// rotation is visible on screen.
///
/// A real app would use `DragonBonesAssets.decodeImageBytes` on the exported
/// PNG instead.
Future<ui.Image> _atlasImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 16, 16),
    ui.Paint()..color = const ui.Color(0xFF3A7BD5),
  );

  final light = ui.Paint()..color = const ui.Color(0xFFCFE0F7);
  const cell = 4.0;
  for (var y = 0; y < 4; y++) {
    for (var x = 0; x < 4; x++) {
      if ((x + y).isEven) {
        canvas.drawRect(
          ui.Rect.fromLTWH(x * cell, y * cell, cell, cell),
          light,
        );
      }
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(16, 16);
  picture.dispose();
  return image;
}

Future<void> main() async {
  // `Picture.toImage` above needs the engine, so the binding comes up first.
  WidgetsFlutterBinding.ensureInitialized();

  final assets = DragonBonesAssets.fromDecoded(
    skeletonJson: jsonDecode(_skeletonJson),
    textureJson: jsonDecode(_atlasJson),
    image: await _atlasImage(),
  );

  final armature = assets.buildArmature('Armature');
  if (armature == null) {
    throw StateError('the armature could not be built');
  }

  // `scale` and `offset` are only used by `DragonBonesFit.none`; with `contain`
  // the widget fits the armature to its box instead.
  final player = DragonBonesPlayer(
    armature,
    resolveImage: assets.imageFor,
    scale: 12,
    offset: const Offset(160, 160),
  );

  runApp(
    ColoredBox(
      color: const Color(0xFF101418),
      child: DragonBonesWidget(
        player: player,
        animation: 'wave',
        fit: DragonBonesFit.none,
      ),
    ),
  );
}
