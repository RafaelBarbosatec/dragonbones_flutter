import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dragonbones/dragonbones.dart' as db;
import 'package:flutter/widgets.dart';

/// Resolves the atlas image that backs a texture.
///
/// The renderer never loads files itself — it just asks where the pixels for a
/// given atlas are, which keeps it usable with any asset pipeline.
typedef AtlasImageResolver = ui.Image? Function(db.TextureAtlasData atlas);

/// Draws one DragonBones armature onto a [Canvas].
///
/// Two methods, no engine coupling:
///
/// ```dart
/// player.update(dt);     // advance the animation
/// player.render(canvas); // draw the current pose
/// ```
///
/// Hook it to whatever drives your frames — a `Ticker`, an engine component's
/// `update`/`render`, a Bonfire `GameComponent`, or a `CustomPainter`.
///
/// Nothing here mutates engine objects: the runtime is driven through
/// [db.HeadlessFactory] and the pose is read back as a [db.SlotDrawData] list.
/// That is also why the geometry is verifiable without a GPU — see
/// `tool/check_against_oracle.dart` in the runtime package.
class DragonBonesPlayer {
  DragonBonesPlayer(
    this.armature, {
    required this.resolveImage,
    this.scale = 1.0,
    this.offset = Offset.zero,
  });

  /// The armature being drawn. Owned by the caller.
  final db.Armature armature;

  /// Where the atlas pixels come from.
  final AtlasImageResolver resolveImage;

  /// Extra uniform scale applied on top of the armature's own scale.
  double scale;

  /// Translation applied before drawing, in canvas units.
  Offset offset;

  /// Whether to draw deformable meshes. Meshes are drawn as triangle lists via
  /// `Canvas.drawVertices`; turning this off skips them (and counts them in
  /// [skippedMeshSlots]) which is useful when debugging sprite-only renders.
  bool drawMeshes = true;

  /// Slots skipped during the last [render] because they hold a deformable mesh.
  int skippedMeshSlots = 0;

  /// Slots skipped during the last [render] because no atlas image was found.
  int skippedMissingTexture = 0;

  /// Advances the animation by [dt] seconds.
  ///
  /// A non-zero step goes through the hub ([db.DragonBones.advanceTime]), which
  /// is what makes buffered events reach their listeners — the frame is posed
  /// first and the events are dispatched afterwards, so a listener is free to
  /// play another animation from inside the callback. Register them on the
  /// armature:
  ///
  /// ```dart
  /// player.armature.eventDispatcher.addDBEventListener(
  ///   db.EventObject.COMPLETE,
  ///   (event) => print('${event.animationState!.name} finished'),
  /// );
  /// ```
  ///
  /// A zero step keeps the direct path: it means "recompute the pose without
  /// advancing time", which the hub's clock deliberately ignores.
  ///
  /// Note the hub is shared by every armature the factory built, so a player
  /// driven this way advances its siblings too — one hub per asset, as in the
  /// example, keeps that unambiguous.
  void update(double dt) {
    if (dt == 0.0) {
      armature.advanceTime(0.0);
      return;
    }

    armature.dragonBones.advanceTime(dt);
  }

  /// Starts [name] playing and returns its state, or null if unknown.
  db.AnimationState? play([String? name]) => armature.animation.play(name);

  /// The ordered list of things to draw at the current pose.
  List<db.SlotDrawData> get drawList => armature.buildDrawList();

  /// Draws the current pose.
  ///
  /// Call [update] first (or don't, for a static pose).
  void render(Canvas canvas, {double? scale, Offset? offset}) {
    final s = scale ?? this.scale;
    final o = offset ?? this.offset;

    skippedMeshSlots = 0;
    skippedMissingTexture = 0;

    final list = drawList;
    if (list.isEmpty) {
      return;
    }

    canvas.save();
    canvas.translate(o.dx, o.dy);
    if (s != 1.0) {
      canvas.scale(s);
    }

    for (final data in list) {
      if (!data.visible) {
        continue;
      }

      final texture = data.texture;
      final region = data.region;
      if (texture == null || region == null) {
        continue;
      }
      final atlas = texture.parent;
      final image = atlas == null ? null : resolveImage(atlas);
      if (image == null) {
        skippedMissingTexture++;
        continue;
      }

      final mesh = data.mesh;
      if (mesh != null) {
        if (!drawMeshes) {
          skippedMeshSlots++;
          continue;
        }
        _drawMesh(canvas, image, data, mesh, region);
        continue;
      }

      _drawSprite(canvas, image, data, region);
    }

    canvas.restore();
  }

  /// Draws a deformable mesh as a textured triangle list.
  ///
  /// Unlike a sprite, a mesh is not a quad, so `drawImageRect` cannot express
  /// it: the vertices come from the runtime already posed (rest positions,
  /// bone weights and FFD all resolved on the CPU — DragonBones does no
  /// per-vertex work on the GPU), and [Canvas.drawVertices] takes them as-is.
  ///
  /// The texture coordinates are in **atlas pixels**, because that is what an
  /// [ui.ImageShader] consumes. The runtime hands over UVs normalised to the
  /// atlas *sub-texture* (0..1 across `region`), which is also how the official
  /// Egret binding reads them (`MeshNode.drawMesh(bitmapX, bitmapY,
  /// bitmapWidth, bitmapHeight, ...)`), so they are mapped onto the region here.
  void _drawMesh(
    Canvas canvas,
    ui.Image image,
    db.SlotDrawData data,
    db.MeshGeometry mesh,
    List<double> region,
  ) {
    final m = data.matrix;

    canvas.save();
    canvas.transform(Float64List.fromList(<double>[
      m.a, m.b, 0, 0, //
      m.c, m.d, 0, 0, //
      0, 0, 1, 0, //
      m.tx, m.ty, 0, 1, //
    ]));

    // The pivot is always 0 for a mesh (the runtime zeroes it), but keep the
    // same anchor maths as the sprite path rather than assume it.
    canvas.translate(-data.pivotX, -data.pivotY);

    final count = mesh.vertexCount;
    final positions = Float32List(count * 2);
    final texCoords = Float32List(count * 2);
    for (var i = 0; i < count * 2; i += 2) {
      positions[i] = mesh.vertices[i];
      positions[i + 1] = mesh.vertices[i + 1];
      texCoords[i] = region[0] + mesh.uvs[i] * region[2];
      texCoords[i + 1] = region[1] + mesh.uvs[i + 1] * region[3];
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: Uint16List.fromList(mesh.triangles),
    );

    final paint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..isAntiAlias = true
      ..blendMode = _blendMode(data.blendMode)
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        // The vertex UVs are already in atlas pixels, so the shader needs no
        // extra transform.
        Float64List.fromList(<double>[
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]),
      );

    final filter = _colorFilter(data.color);
    if (filter != null) {
      paint.colorFilter = filter;
    }

    // No per-vertex colours are supplied, so the shader alone provides the
    // pixels and the blend mode is a formality.
    canvas.drawVertices(vertices, ui.BlendMode.srcOver, paint);

    vertices.dispose();
    canvas.restore();
  }

  void _drawSprite(
    Canvas canvas,
    ui.Image image,
    db.SlotDrawData data,
    List<double> region,
  ) {
    final m = data.matrix;

    canvas.save();

    // Slot world transform. Canvas.transform takes a column-major 4x4; a 2D
    // affine (a, b, c, d, tx, ty) maps onto it like this.
    canvas.transform(Float64List.fromList(<double>[
      m.a, m.b, 0, 0, //
      m.c, m.d, 0, 0, //
      0, 0, 1, 0, //
      m.tx, m.ty, 0, 1, //
    ]));

    // The pivot is the point of the display that sits on the slot origin, so
    // the quad is drawn shifted by it. This is the same anchor maths the
    // official engines do (`tx - (a * pivotX + c * pivotY)`).
    canvas.translate(-data.pivotX, -data.pivotY);

    final src = Rect.fromLTWH(region[0], region[1], region[2], region[3]);
    final dst = Rect.fromLTWH(0, 0, data.quadWidth, data.quadHeight);

    final paint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..isAntiAlias = true
      ..blendMode = _blendMode(data.blendMode);

    final filter = _colorFilter(data.color);
    if (filter != null) {
      paint.colorFilter = filter;
    }

    if (data.rotated) {
      // The atlas entry is stored rotated a quarter turn. UNVERIFIED: none of
      // the current fixtures use rotated entries, so this path has never been
      // exercised against the official runtime — treat it as untested.
      canvas.rotate(math.pi / 2);
      canvas.translate(0, -data.quadWidth);
      canvas.drawImageRect(image, src, dst, paint);
    } else {
      canvas.drawImageRect(image, src, dst, paint);
    }

    canvas.restore();
  }
}

/// Maps a DragonBones blend mode onto Flutter's.
///
/// `Normal`, `Add`, `Multiply`, `Screen`, `Darken`, `Lighten`, `Overlay`,
/// `HardLight` and `Difference` map cleanly. `Alpha`, `Erase`, `Invert`,
/// `Layer` and `Subtract` have no exact Flutter counterpart; the closest match
/// is used and marked — none of the current fixtures exercise them.
ui.BlendMode _blendMode(int value) {
  switch (value) {
    case db.BlendMode.Normal:
      return ui.BlendMode.srcOver;
    case db.BlendMode.Add:
      return ui.BlendMode.plus;
    case db.BlendMode.Alpha:
      return ui.BlendMode.dstIn; // approximate
    case db.BlendMode.Darken:
      return ui.BlendMode.darken;
    case db.BlendMode.Difference:
      return ui.BlendMode.difference;
    case db.BlendMode.Erase:
      return ui.BlendMode.dstOut; // approximate
    case db.BlendMode.HardLight:
      return ui.BlendMode.hardLight;
    case db.BlendMode.Invert:
      return ui.BlendMode.difference; // approximate
    case db.BlendMode.Layer:
      return ui.BlendMode.srcOver; // approximate
    case db.BlendMode.Lighten:
      return ui.BlendMode.lighten;
    case db.BlendMode.Multiply:
      return ui.BlendMode.multiply;
    case db.BlendMode.Overlay:
      return ui.BlendMode.overlay;
    case db.BlendMode.Screen:
      return ui.BlendMode.screen;
    case db.BlendMode.Subtract:
      return ui.BlendMode.difference; // approximate
    default:
      return ui.BlendMode.srcOver;
  }
}

/// Builds a colour filter from a slot colour transform.
///
/// DragonBones stores multipliers in 0..1 and offsets in 0..255, which is what
/// [ui.ColorFilter.matrix] expects. Returns null when the transform is the
/// identity, so the common case costs nothing.
ui.ColorFilter? _colorFilter(List<double> color) {
  const eps = 1e-6;
  final isIdentity = (color[0] - 1).abs() < eps &&
      (color[1] - 1).abs() < eps &&
      (color[2] - 1).abs() < eps &&
      (color[3] - 1).abs() < eps &&
      color[4].abs() < eps &&
      color[5].abs() < eps &&
      color[6].abs() < eps &&
      color[7].abs() < eps;
  if (isIdentity) {
    return null;
  }

  // [aM, rM, gM, bM, aO, rO, gO, bO]
  final aM = color[0], rM = color[1], gM = color[2], bM = color[3];
  final aO = color[4], rO = color[5], gO = color[6], bO = color[7];

  return ui.ColorFilter.matrix(<double>[
    rM, 0, 0, 0, rO, //
    0, gM, 0, 0, gO, //
    0, 0, bM, 0, bO, //
    0, 0, 0, aM, aO, //
  ]);
}
