import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dragonbones/dragonbones.dart' as db;
import 'package:flutter/services.dart' show AssetBundle, ByteData;

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
