import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every DragonBones Unity SDK demo asset, driven through the real renderer.
///
/// The atlas PNGs are not committed (11 MB, and the geometry oracle never opens
/// them), so each atlas is backed by a tiny synthetic image. That is plenty for
/// what this test is for: proving the canvas path — `drawImageRect` for sprites,
/// `drawVertices` + `ImageShader` for meshes, and the flattened child armatures —
/// survives every asset in the set, including the skinned meshes and the
/// IK-driven chains.
///
/// Pixel *appearance* is still only eyeballed, and geometry correctness is a
/// separate, stronger check:
/// `packages/dragonbones/tool/check_against_oracle.dart`.
void main() {
  final fixtures = _discoverFixtures();
  var meshSlotsSeen = 0;
  var assetsWithMeshes = 0;
  var assetsWithNestedArmatures = 0;

  test('the sweep found fixtures', () {
    expect(fixtures, isNotEmpty,
        reason: 'run tool/ground_truth/fetch_fixtures.sh first');
  });

  for (final fixture in fixtures) {
    test('renders ${fixture.id}', () async {
      final assets = await fixture.load();
      final data = assets.factory.getDragonBonesData(assets.name)!;
      final armature = assets.buildArmature(data.armatureNames.first);
      expect(armature, isNotNull, reason: 'the first armature must build');

      // What the asset contains, observed from the runtime side…
      if (armature!.getSlots().any((s) => s.geometryData != null)) {
        assetsWithMeshes++;
      }
      if (armature.getSlots().any((s) => s.childArmature != null)) {
        assetsWithNestedArmatures++;
      }

      final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
      final animations = armature.armatureData.animationNames;
      if (animations.isNotEmpty) {
        player.play(animations.first);
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 256, 256));

      // A handful of frames: enough to move past the pose and exercise the
      // mesh/child paths without turning the sweep into a slow test.
      final frames = animations.isEmpty ? 2 : 8;
      for (var i = 0; i < frames; i++) {
        player.update(1 / 24);
        player.render(canvas);

        // …and what actually reached the canvas, observed from the draw side.
        for (final draw in player.drawList) {
          if (draw.mesh != null) meshSlotsSeen++;
        }
      }

      recorder.endRecording().dispose();

      expect(player.skippedMeshSlots, 0,
          reason: 'meshes are enabled — nothing should be skipped as a mesh');
      expect(player.skippedMissingTexture, 0,
          reason: 'every slot must resolve its atlas to an image');
    });
  }

  test('the sweep actually covered meshes and nested armatures', () {
    expect(meshSlotsSeen, greaterThan(0),
        reason: 'the set has mesh slots; if this is 0 the mesh path is untested');
    expect(assetsWithMeshes, greaterThan(0),
        reason: 'no asset reported a mesh slot');
    expect(assetsWithNestedArmatures, greaterThan(0),
        reason: 'the set has nested armatures; if this is 0 that path is untested');
  });
}

/// One asset directory under `test/fixtures/unity`, plus its skeleton/atlas.
class _Fixture {
  _Fixture(this.id, this.skeleton, this.texture);

  final String id;
  final File skeleton;
  final File texture;

  Future<DragonBonesAssets> load() async {
    return DragonBonesAssets.fromDecoded(
      skeletonJson: jsonDecode(skeleton.readAsStringSync()),
      textureJson: jsonDecode(texture.readAsStringSync()),
      image: await _syntheticAtlas(),
    );
  }

  @override
  String toString() => id;
}

/// A 4x4 opaque image standing in for the real atlas. Sampling it through an
/// `ImageShader` with UVs beyond its bounds exercises `TileMode.clamp`, which is
/// exactly what the renderer relies on.
Future<ui.Image> _syntheticAtlas() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF808080),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  picture.dispose();
  return image;
}

/// Every `<name>_ske.json` under `test/fixtures/unity`, paired with its atlas.
///
/// Fixture names are globbed rather than listed: some assets are named
/// differently from their directory, and the set is meant to grow without
/// touching this file.
List<_Fixture> _discoverFixtures() {
  final root = Directory('../../test/fixtures/unity');
  if (!root.existsSync()) return const <_Fixture>[];

  final skeletons = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_ske.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final fixtures = <_Fixture>[];
  for (final skeleton in skeletons) {
    final stem = skeleton.path.substring(0, skeleton.path.length - '_ske.json'.length);
    final texture = File('${stem}_tex.json');
    if (!texture.existsSync()) continue;

    final id = skeleton.path
        .replaceFirst(root.path, '')
        .replaceFirst(RegExp(r'^[/\\]'), '')
        .replaceAll(RegExp(r'[/\\]'), '/')
        .replaceAll('_ske.json', '');

    fixtures.add(_Fixture(id, skeleton, texture));
  }
  return fixtures;
}
