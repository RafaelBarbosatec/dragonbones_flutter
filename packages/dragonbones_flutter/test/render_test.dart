import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the renderer: load the real fixtures, drive them, draw them.
///
/// It does not compare against a golden baseline (this repository cannot
/// generate one yet). What it does prove is that every slot finds its atlas,
/// nothing is silently skipped, and drawing a full animation loop raises no
/// exception — the failures that actually happen when wiring a renderer up.
///
/// The geometry itself is verified numerically against the official runtime in
/// `packages/dragonbones/tool/check_against_oracle.dart`.
///
/// The mesh test goes one step further and rasterises the canvas, because
/// `drawVertices` + `ImageShader` is exactly the kind of call that can be wired
/// wrong and still throw nothing while painting zero pixels.
void main() {
  test('draws a full walk cycle without skipping any slot', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon');
    expect(armature, isNotNull);

    final player = DragonBonesPlayer(armature!, resolveImage: assets.imageFor);
    player.play('walk');

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    var framesDrawn = 0;
    for (var i = 0; i < 21; i++) {
      player.update(1 / 24);
      player.render(canvas);
      framesDrawn++;
      expect(player.drawList, isNotEmpty,
          reason: 'frame $i has nothing to draw');
    }

    recorder.endRecording().dispose();

    expect(framesDrawn, 21);
    expect(player.skippedMissingTexture, 0,
        reason: 'every slot must resolve an atlas image');
    expect(player.skippedMeshSlots, 0,
        reason: 'the Dragon fixture has no mesh slots');
  });

  test('exposes the animation list and poses at rest', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;

    expect(armature.armatureData.animationNames,
        containsAll(<String>['stand', 'walk', 'jump', 'fall']));

    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
    final bounds = player.computeBounds();

    expect(bounds, isNotNull);
    expect(bounds!.width, greaterThan(0));
    expect(bounds.height, greaterThan(0));
  });

  test('poses and paints a deformable mesh (drawVertices)', () async {
    // 龙: 60 bones, 5 meshes — 2 of them skinned, and driven by FFD timelines.
    final assets = await _loadFixture('龙');
    final armature = assets.buildArmature('armatureName')!;

    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
    player.play('stand');
    player.update(1 / 24);

    final meshes =
        player.drawList.where((d) => d.mesh != null).toList(growable: false);
    expect(meshes, hasLength(5), reason: '龙 has five mesh slots');
    expect(meshes.fold<int>(0, (sum, d) => sum + d.mesh!.vertexCount), 339);
    expect(meshes.fold<int>(0, (sum, d) => sum + d.mesh!.triangleCount), 437);
    expect(player.skippedMeshSlots, 0);

    final painted = await _countPaintedPixels(player, const ui.Size(256, 256));

    // Not a pixel-perfect assertion — just proof that the triangle lists and the
    // atlas shader actually rasterised something substantial.
    expect(painted, greaterThan(2000),
        reason: 'drawVertices produced almost no pixels; the mesh path is not '
            'reaching the canvas');
    expect(player.skippedMissingTexture, 0);
  });

  test('turning drawMeshes off skips meshes instead of drawing them', () async {
    final assets = await _loadFixture('龙');
    final armature = assets.buildArmature('armatureName')!;

    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor)
      ..play('stand')
      ..drawMeshes = false
      ..update(1 / 24);

    final recorder = ui.PictureRecorder();
    player.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();

    expect(player.skippedMeshSlots, 5);
  });
}

/// Rasterises the player centred in a [size] box and counts pixels that differ
/// from the background.
Future<int> _countPaintedPixels(DragonBonesPlayer player, ui.Size size) async {
  const background = ui.Color(0xFF102030);
  // `Color.red`/`green`/`blue` are deprecated (Flutter 3.41), and infos are
  // fatal in `flutter analyze` — so compare the raw bytes against the literal
  // channels of the background instead.
  const backgroundR = 0x10;
  const backgroundG = 0x20;
  const backgroundB = 0x30;

  final recorder = ui.PictureRecorder();
  final canvas =
      ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.width, size.height),
    ui.Paint()..color = background,
  );

  final bounds = player.computeBounds();
  if (bounds == null || bounds.isEmpty) {
    throw StateError('nothing to draw');
  }

  final scale =
      math.min(size.width / bounds.width, size.height / bounds.height) * 0.9;
  player.render(
    canvas,
    scale: scale,
    offset: ui.Offset(
      size.width / 2 - bounds.center.dx * scale,
      size.height / 2 - bounds.center.dy * scale,
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();

  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) {
    throw StateError('could not read back the rendered image');
  }

  var painted = 0;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) != backgroundR ||
        data.getUint8(i + 1) != backgroundG ||
        data.getUint8(i + 2) != backgroundB) {
      painted++;
    }
  }
  return painted;
}

/// Loads `<name>_ske.json` / `_tex.json` / `_tex.png`.
///
/// [local] reads the copy inside this package; otherwise the repository-level
/// fixture directory is used, so the 1 MB 龙 atlas is not duplicated.
Future<DragonBonesAssets> _loadFixture(String name,
    {bool local = false}) async {
  final directory = Directory(local ? 'test/fixtures' : '../../test/fixtures');
  final skeleton = File('${directory.path}/${name}_ske.json');
  if (!skeleton.existsSync()) {
    throw StateError(
      'fixture not found at ${skeleton.absolute.path} — run the test from '
      'packages/dragonbones_flutter',
    );
  }

  return DragonBonesAssets.fromDecoded(
    skeletonJson: jsonDecode(skeleton.readAsStringSync()),
    textureJson: jsonDecode(
      File('${directory.path}/${name}_tex.json').readAsStringSync(),
    ),
    image: await DragonBonesAssets.decodeImageBytes(
      File('${directory.path}/${name}_tex.png').readAsBytesSync(),
    ),
  );
}
