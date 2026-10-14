import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dragonbones/dragonbones.dart' as db;
import 'package:flutter/services.dart' show AssetBundle, ByteData;

import 'player.dart';

/// A loaded DragonBones asset: the skeleton data, the atlas data, and the raster
/// the atlas points at.
///
/// Deliberately thin — it parses, wires the atlas to an image, and builds
/// armatures. It does not load from a fixed location: pass bytes, or let
/// [DragonBonesAssets.loadAsset] read from an [AssetBundle].
class DragonBonesAssets {
  DragonBonesAssets._(this.factory, this.name, this._images);

  /// The factory holding the parsed data.
  final db.HeadlessFactory factory;

  /// Cache name the data is registered under; also the default for
  /// [buildArmature]'s `dragonBonesName`.
  final String name;

  final Map<db.TextureAtlasData, ui.Image> _images;

  /// The raster backing [atlas], or null if none was registered.
  ui.Image? imageFor(db.TextureAtlasData atlas) => _images[atlas];

  /// Builds an armature from the loaded data.
  ///
  /// The armature is not driven by anything: advance it yourself via
  /// [DragonBonesPlayer.update].
  db.Armature? buildArmature(String armatureName, {String? skinName}) =>
      factory.buildArmature(armatureName, name, skinName ?? '');

  /// Builds an armature **and** a [DragonBonesPlayer] wired to it — the image
  /// resolver and a stable skeleton-bounds measurement come for free:
  ///
  /// ```dart
  /// final player = assets.createPlayer('mecha_2903d');
  /// player.fit(
  ///   size: size,
  ///   fit: DragonBonesFit.contain,
  ///   align: Alignment.topLeft,
  /// );
  /// ```
  ///
  /// The bounds are measured lazily on the first [DragonBonesPlayer.fit]. Throws
  /// a [StateError] if the armature does not exist. The armature is available as
  /// [DragonBonesPlayer.armature] if you need it for bones or hitboxes.
  DragonBonesPlayer createPlayer(
    String armatureName, {
    String? skinName,
    double scale = 1.0,
    ui.Offset offset = ui.Offset.zero,
  }) {
    final armature = buildArmature(armatureName, skinName: skinName);
    if (armature == null) {
      throw StateError('armature "$armatureName" not found');
    }
    return DragonBonesPlayer(
      armature,
      assets: this,
      skinName: skinName,
      scale: scale,
      offset: offset,
    );
  }

  /// Bounds of [armatureName] across **every** animation, in armature
  /// coordinates — a stable box for [DragonBonesPlayer.fit].
  ///
  /// Builds a throwaway armature (the live one is never touched), poses each of
  /// its animations at the authored frame rate, unions the extents and disposes
  /// it again. That is far more work than measuring one frame, so it is done
  /// once and cached — a [DragonBonesPlayer] built with `assets:` calls this on
  /// the first [DragonBonesPlayer.fit]. You only need it directly for a
  /// hand-authored [DragonBonesPlayer.skeletonBounds] or a re-measure after a
  /// skin swap:
  ///
  /// ```dart
  /// player.skeletonBounds = assets.measureBounds(armatureName: 'mecha_2903d');
  /// ```
  ///
  /// Returns null when the armature has no drawable extent (or does not exist).
  ui.Rect? measureBounds({
    required String armatureName,
    String? skinName,
  }) {
    final armature = buildArmature(armatureName, skinName: skinName);
    if (armature == null) {
      return null;
    }

    final frameRate = armature.armatureData.frameRate > 0.0
        ? armature.armatureData.frameRate
        : 24.0;
    final step = 1.0 / frameRate;

    ui.Rect? result;
    for (final animationName in armature.armatureData.animationNames) {
      final state = armature.animation.play(animationName, 1);
      if (state == null) {
        continue;
      }

      // Sample every authored frame, plus a couple to land past the last one.
      // The scratch armature is advanced directly, not through the hub, so the
      // live armature sharing that hub never moves.
      final frames = (state.totalTime / step).ceil() + 2;
      for (var frame = 0; frame < frames; frame++) {
        armature.advanceTime(step);
        final bounds = boundsOfDrawList(armature.buildDrawList());
        if (bounds == null) {
          continue;
        }
        result = result == null ? bounds : result.expandToInclude(bounds);
      }
    }

    // The scratch armature is buffered and cleared on the next hub advance, so
    // it never renders or dispatches anything.
    armature.dispose();
    return result;
  }

  /// Assembles already-decoded pieces. Useful in tests, where the raster can be
  /// produced without touching the file system.
  static DragonBonesAssets fromDecoded({
    required Object skeletonJson,
    required Object textureJson,
    required ui.Image image,
    String? name,
  }) {
    final factory = db.HeadlessFactory();
    final data = factory.parseDragonBonesData(skeletonJson, name);
    if (data == null) {
      throw ArgumentError('skeleton JSON could not be parsed');
    }
    final atlas = factory.parseTextureAtlasData(textureJson, null, data.name);
    return DragonBonesAssets._(
        factory, data.name, <db.TextureAtlasData, ui.Image>{
      atlas: image,
    });
  }

  /// Loads `<name>_ske.json`, `<name>_tex.json` and the atlas image from
  /// [bundle].
  static Future<DragonBonesAssets> loadAsset({
    required AssetBundle bundle,
    required String skeleton,
    required String texture,
    required String image,
    String? name,
  }) async {
    final skeletonBytes = await bundle.load(skeleton);
    final textureBytes = await bundle.load(texture);
    final imageBytes = await bundle.load(image);

    return fromDecoded(
      skeletonJson: jsonDecode(
        utf8.decode(skeletonBytes.buffer.asUint8List(
          skeletonBytes.offsetInBytes,
          skeletonBytes.lengthInBytes,
        )),
      ),
      textureJson: jsonDecode(
        utf8.decode(textureBytes.buffer.asUint8List(
          textureBytes.offsetInBytes,
          textureBytes.lengthInBytes,
        )),
      ),
      image: await decodeImageData(imageBytes),
      name: name,
    );
  }

  /// Decodes PNG/JPEG bytes into a [ui.Image].
  static Future<ui.Image> decodeImageData(ByteData data) async {
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return decodeImageBytes(bytes);
  }

  /// Decodes PNG/JPEG [bytes] into a [ui.Image].
  static Future<ui.Image> decodeImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }
}
