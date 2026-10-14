import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter/widgets.dart' show Alignment;
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

  test('fit maps an explicit bounds rect into a box', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);

    // A 60x80 pose at (-30, -40).
    const bounds = ui.Rect.fromLTWH(-30, -40, 60, 80);
    const box = ui.Size(200, 100);

    player.fit(size: box, bounds: bounds, fit: DragonBonesFit.contain);
    expect(player.scale, closeTo(100 / 80, 1e-9),
        reason: 'contain is height-limited here');

    player.fit(size: box, bounds: bounds, fit: DragonBonesFit.cover);
    expect(player.scale, closeTo(200 / 60, 1e-9),
        reason: 'cover is width-limited here');

    player.fit(size: box, bounds: bounds, fit: DragonBonesFit.fitWidth);
    expect(player.scale, closeTo(200 / 60, 1e-9));

    player.fit(size: box, bounds: bounds, fit: DragonBonesFit.fitHeight);
    expect(player.scale, closeTo(100 / 80, 1e-9));
  });

  test('fit aligns the content inside the box without overflowing', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);

    // A 40x40 pose whose top-left is (10, 20).
    const bounds = ui.Rect.fromLTWH(10, 20, 40, 40);
    const box = ui.Size(200, 100);
    const fittedScale = 2.5; // min(200/40, 100/40)

    // topLeft: the box's top-left is the pose's top-left.
    player.fit(size: box, bounds: bounds, align: Alignment.topLeft);
    expect(player.scale, closeTo(fittedScale, 1e-9));
    expect(player.offset.dx + bounds.left * fittedScale, closeTo(0, 1e-9));
    expect(player.offset.dy + bounds.top * fittedScale, closeTo(0, 1e-9));

    // bottomRight: the pose's bottom-right is the box's bottom-right.
    player.fit(size: box, bounds: bounds, align: Alignment.bottomRight);
    expect(player.offset.dx + bounds.right * fittedScale, closeTo(200, 1e-9));
    expect(player.offset.dy + bounds.bottom * fittedScale, closeTo(100, 1e-9));

    // bottomCenter: feet on the bottom edge, horizontally centred, and the
    // whole pose stays inside the box (the old bug put half of it below).
    player.fit(size: box, bounds: bounds, align: Alignment.bottomCenter);
    final left = player.offset.dx + bounds.left * fittedScale;
    final right = player.offset.dx + bounds.right * fittedScale;
    final top = player.offset.dy + bounds.top * fittedScale;
    final bottom = player.offset.dy + bounds.bottom * fittedScale;
    expect(bottom, closeTo(100, 1e-9), reason: 'feet on the bottom edge');
    expect(top, greaterThanOrEqualTo(-1e-6), reason: 'stays inside');
    expect(left, greaterThanOrEqualTo(-1e-6), reason: 'stays inside');
    expect(right, lessThanOrEqualTo(200 + 1e-6), reason: 'stays inside');
    expect((left + right) / 2, closeTo(100, 1e-9),
        reason: 'horizontally centred');
  });

  test('fit leaves a manual placement alone when it cannot fit', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor)
      ..scale = 7
      ..offset = const ui.Offset(3, 4);

    player.fit(size: const ui.Size(100, 100), fit: DragonBonesFit.none);
    expect(player.scale, 7);
    expect(player.offset, const ui.Offset(3, 4));

    player.fit(size: ui.Size.zero, fit: DragonBonesFit.contain);
    expect(player.scale, 7, reason: 'an empty box cannot be fitted');

    player.fit(
      size: const ui.Size(100, 100),
      bounds: ui.Rect.zero,
      fit: DragonBonesFit.contain,
    );
    expect(player.scale, 7, reason: 'an empty pose cannot be fitted');
  });

  test('fit contains the live pose in the box', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor)
      ..play('walk')
      ..update(1 / 24);

    const box = ui.Size(120, 120);
    final fitted = player.fit(size: box);
    expect(fitted, isNotNull);

    final w = fitted!.width * player.scale;
    final h = fitted.height * player.scale;
    expect(w, lessThanOrEqualTo(box.width + 1e-6));
    expect(h, lessThanOrEqualTo(box.height + 1e-6));

    final drawnCenter = ui.Offset(
      player.offset.dx + fitted.center.dx * player.scale,
      player.offset.dy + fitted.center.dy * player.scale,
    );
    expect(
      (drawnCenter - ui.Offset(box.width / 2, box.height / 2)).distance,
      lessThan(1e-6),
    );
  });

  test('measureBounds encloses every pose of every animation', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final bounds = assets.measureBounds(armatureName: 'Dragon');
    if (bounds == null) {
      fail('measureBounds returned null for Dragon');
    }

    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);

    for (final animation in armature.armatureData.animationNames) {
      player.play(animation);
      for (var frame = 0; frame < 30; frame++) {
        player.update(1 / 24);
        final pose = player.computeBounds();
        if (pose == null) {
          continue;
        }
        expect(bounds.left, lessThanOrEqualTo(pose.left + 1e-3),
            reason: '$animation frame $frame: left');
        expect(bounds.top, lessThanOrEqualTo(pose.top + 1e-3),
            reason: '$animation frame $frame: top');
        expect(bounds.right, greaterThanOrEqualTo(pose.right - 1e-3),
            reason: '$animation frame $frame: right');
        expect(bounds.bottom, greaterThanOrEqualTo(pose.bottom - 1e-3),
            reason: '$animation frame $frame: bottom');
      }
    }
  });

  test('skeletonBounds makes fit independent of the current pose', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor)
      // A 2:1 stable box, so contain fills the width exactly.
      ..skeletonBounds = const ui.Rect.fromLTWH(0, 0, 200, 100);

    player.fit(size: const ui.Size(200, 100), fit: DragonBonesFit.contain);
    expect(player.scale, closeTo(1.0, 1e-9));

    // Moving the animation must not move the placement.
    player.play('walk');
    player.update(1 / 24);
    player.fit(size: const ui.Size(200, 100), fit: DragonBonesFit.contain);
    expect(player.scale, closeTo(1.0, 1e-9));

    // `useCurrentPose` opts back into measuring the frame being drawn.
    final pose = player.computeBounds()!;
    player.fit(
      size: const ui.Size(200, 100),
      fit: DragonBonesFit.contain,
      useCurrentPose: true,
    );
    expect(
      player.scale,
      closeTo(math.min(200 / pose.width, 100 / pose.height), 1e-9),
    );
  });

  test('building with assets measures the skeleton bounds on first fit',
      () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, assets: assets);

    expect(player.skeletonBounds, isNull,
        reason: 'measuring is lazy, not a constructor cost');

    player.play('walk');
    player.update(1 / 24);
    player.fit(size: const ui.Size(200, 200), fit: DragonBonesFit.contain);
    expect(player.skeletonBounds, isNotNull,
        reason: 'the first fit measures it behind the scenes');

    // Once measured, the placement no longer depends on the animation played.
    final scale = player.scale;
    player.play('stand');
    player.update(1 / 24);
    player.fit(size: const ui.Size(200, 200), fit: DragonBonesFit.contain);
    expect(player.scale, scale);
  });

  test('createPlayer wires the image resolver and the bounds', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final player = assets.createPlayer('Dragon');

    expect(player.armature.armatureData.name, 'Dragon');

    player.play('stand');
    player.update(0);
    final atlas = player.drawList
        .firstWhere((data) => data.texture != null)
        .texture!
        .parent!;
    expect(player.resolveImage(atlas), isNotNull,
        reason: 'assets.imageFor should have been wired in');

    player.fit(size: const ui.Size(200, 200));
    expect(player.skeletonBounds, isNotNull);
    expect(player.scale, greaterThan(0));

    expect(() => assets.createPlayer('does_not_exist'), throwsStateError);
  });

  test('measureBounds leaves a live armature untouched', () async {
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    armature.animation.play('walk', 1);
    armature.advanceTime(1 / 24);

    final before = armature.animation.lastAnimationState!;
    final name = before.name;
    final time = before.currentTime;

    assets.measureBounds(armatureName: 'Dragon');

    final after = armature.animation.lastAnimationState!;
    expect(after.name, name, reason: 'the live animation must not switch');
    expect(after.currentTime, time, reason: 'the live playhead must not move');
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

  test('reports complete when an animation ends', () async {
    // The event path end-to-end through the renderer: the player advances the
    // hub (which is what dispatches), the headless display behind the assets
    // delivers, and the listener runs.
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);

    final completed = <String>[];
    armature.eventDispatcher.addDBEventListener(
      EventObject.COMPLETE,
      (event) => completed.add(event.animationState?.name ?? ''),
    );

    // playTimes 1: played through once, so `complete` fires at the end.
    final state = armature.animation.play('stand', 1)!;
    final frames = (state.totalTime * 24).ceil() + 4;
    for (var i = 0; i < frames; i++) {
      player.update(1 / 24);
    }

    expect(completed, <String>['stand']);
  });

  test('a zero step refreshes the pose without advancing time', () async {
    // `update(0)` means "recompute the pose now" — the head-following example
    // uses it right after flipping the character. The hub's clock ignores a
    // zero step, so the player takes the direct path for it.
    final assets = await _loadFixture('Dragon', local: true);
    final armature = assets.buildArmature('Dragon')!;
    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);

    player.play('walk');
    player.update(1 / 24);
    final before = armature.animation.lastAnimationState!.currentTime;

    player.update(0);

    expect(armature.animation.lastAnimationState!.currentTime, before,
        reason: 'a zero step must not move the playhead');
    expect(player.drawList, isNotEmpty);
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
