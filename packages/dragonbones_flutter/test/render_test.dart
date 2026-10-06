import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the renderer: load the real fixture, drive it, draw it.
///
/// It does not check pixels (a golden would need a baseline this repository
/// cannot generate yet). What it does prove is that every slot finds its atlas,
/// nothing is silently skipped, and drawing a full loop raises no exception —
/// the failures that actually happen when wiring a renderer up.
///
/// The geometry itself is verified numerically against the official runtime in
/// `packages/dragonbones/tool/check_against_oracle.dart`.
void main() {
  test('draws a full walk cycle without skipping any slot', () async {
    final assets = await _loadDragon();
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
      expect(player.drawList, isNotEmpty, reason: 'frame $i has nothing to draw');
    }

    recorder.endRecording().dispose();

    expect(framesDrawn, 21);
    expect(player.skippedMissingTexture, 0,
        reason: 'every slot must resolve an atlas image');
    expect(player.skippedMeshSlots, 0,
        reason: 'the Dragon fixture has no mesh slots');
  });

  test('exposes the animation list and poses at rest', () async {
    final assets = await _loadDragon();
    final armature = assets.buildArmature('Dragon')!;

    expect(armature.armatureData.animationNames,
        containsAll(<String>['stand', 'walk', 'jump', 'fall']));

    final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
    final bounds = player.computeBounds();

    expect(bounds, isNotNull);
    expect(bounds!.width, greaterThan(0));
    expect(bounds.height, greaterThan(0));
  });
}

Future<DragonBonesAssets> _loadDragon() async {
  final directory = Directory('test/fixtures');
  final skeleton = File('${directory.path}/Dragon_ske.json');
  if (!skeleton.existsSync()) {
    throw StateError(
      'fixture not found at ${skeleton.absolute.path} — run the test from the '
      'package root (packages/dragonbones_flutter)',
    );
  }

  return DragonBonesAssets.fromDecoded(
    skeletonJson: jsonDecode(skeleton.readAsStringSync()),
    textureJson: jsonDecode(
      File('${directory.path}/Dragon_tex.json').readAsStringSync(),
    ),
    image: await DragonBonesAssets.decodeImageBytes(
      File('${directory.path}/Dragon_tex.png').readAsBytesSync(),
    ),
  );
}
