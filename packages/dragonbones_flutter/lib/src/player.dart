import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dragonbones/dragonbones.dart' as db;
import 'package:flutter/widgets.dart';

import 'assets.dart';

/// Resolves the atlas image that backs a texture.
///
/// The renderer never loads files itself — it just asks where the pixels for a
/// given atlas are, which keeps it usable with any asset pipeline.
typedef AtlasImageResolver = ui.Image? Function(db.TextureAtlasData atlas);

/// How [DragonBonesPlayer.fit] places the armature inside a box.
///
/// Every mode except [none] is a uniform scale (the player has a single
/// [DragonBonesPlayer.scale]), so a non-uniform `fill` is deliberately absent:
/// stretching an armature would shear the bone hierarchy.
enum DragonBonesFit {
  /// Leave [DragonBonesPlayer.scale] and [DragonBonesPlayer.offset] alone.
  ///
  /// Use this when the placement is hand-authored, as the plain-Flutter
  /// example does.
  none,

  /// Scale up or down so the whole pose fits inside the box, preserving the
  /// aspect ratio (the largest scale that fits).
  contain,

  /// Scale so the pose covers the whole box, preserving the aspect ratio (the
  /// smallest scale that covers). Parts of the pose may stick out.
  cover,

  /// Match the box width; the height follows the aspect ratio.
  fitWidth,

  /// Match the box height; the width follows the aspect ratio.
  fitHeight,
}

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
/// [fit] is the optional third piece: it measures the pose and writes [scale]
/// and [offset] so an engine component does not have to.
///
/// Nothing here mutates engine objects: the runtime is driven through
/// [db.HeadlessFactory] and the pose is read back as a [db.SlotDrawData] list.
/// That is also why the geometry is verifiable without a GPU — see
/// `tool/check_against_oracle.dart` in the runtime package.
class DragonBonesPlayer {
  DragonBonesPlayer(
    this.armature, {
    AtlasImageResolver? resolveImage,
    DragonBonesAssets? assets,
    this.skinName,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.skeletonBounds,
  })  : assert(resolveImage != null || assets != null,
            'Pass resolveImage, or assets to resolve it from'),
        resolveImage = resolveImage ?? assets!.imageFor,
        _assets = assets;

  /// The armature being drawn. Owned by the caller.
  final db.Armature armature;

  /// Where the atlas pixels come from.
  ///
  /// Defaults to [DragonBonesAssets.imageFor] when the player is built with
  /// [assets]; pass an explicit resolver to draw from somewhere else.
  final AtlasImageResolver resolveImage;

  final DragonBonesAssets? _assets;

  /// Whether [_stableBounds] already ran; separate from [skeletonBounds] being
  /// non-null so a measurement that found nothing is not repeated every frame.
  bool _boundsMeasured = false;

  /// The skin the armature was built with, if any.
  ///
  /// Only used to measure [skeletonBounds] from [DragonBonesAssets]; the live
  /// armature is what is drawn.
  final String? skinName;

  /// Extra uniform scale applied on top of the armature's own scale.
  double scale;

  /// Translation applied before drawing, in canvas units.
  Offset offset;

  /// Stable bounds to place against, independent of the current frame.
  ///
  /// When set, [fit] uses these instead of measuring the pose, so an animated
  /// silhouette cannot make the placement jump and no draw list is built just
  /// to place the character.
  ///
  /// You normally do not set this yourself: build the player with
  /// [DragonBonesAssets] (or use [DragonBonesAssets.createPlayer]) and the
  /// first [fit] measures it once, across every animation, using a throwaway
  /// armature. Assign it explicitly only when you need a different box — a
  /// hand-authored one, or a re-measure after a skin swap.
  Rect? skeletonBounds;

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

  /// Bounding box of the current pose, in armature coordinates.
  ///
  /// Computed from the sprite quads and the posed mesh vertices, so it moves
  /// with the animation. Returns null when there is nothing to draw.
  ///
  /// For a box that does **not** move with the animation, use [skeletonBounds]
  /// (see [fit]) — this method rebuilds the draw list on every call, which is
  /// exactly why placement should not depend on it once a stable box exists.
  Rect? computeBounds() => boundsOfDrawList(drawList);

  /// [skeletonBounds], measured from [DragonBonesAssets] on first use.
  ///
  /// Lazy on purpose: a player placed by hand never pays for the sweep, and a
  /// player that is placed measures exactly once.
  Rect? _stableBounds() {
    if (skeletonBounds != null) {
      return skeletonBounds;
    }
    if (_boundsMeasured) {
      return null;
    }
    final assets = _assets;
    if (assets == null) {
      return null;
    }
    _boundsMeasured = true;
    return skeletonBounds = assets.measureBounds(
      armatureName: armature.armatureData.name,
      skinName: skinName,
    );
  }

  /// Places the armature inside a `size` box and writes the result to [scale]
  /// and [offset].
  ///
  /// This is the bridge the engine examples need: an engine component knows the
  /// box it occupies (`size`) and where inside it the art should sit ([align]),
  /// but not the armature's extent or its origin. Rather than recompute
  /// `scale`/`offset` by hand every time:
  ///
  /// ```dart
  /// // Flame / Bonfire component
  /// @override
  /// Future<void> onLoad() async {
  ///   _player = DragonBonesPlayer(armature, assets: assets)
  ///     ..play('idle')
  ///     ..fit(
  ///       size: Size(size.x, size.y),
  ///       fit: DragonBonesFit.contain,
  ///       align: Alignment.topLeft,
  ///     );
  /// }
  ///
  /// @override
  /// void render(Canvas canvas) => _player.render(canvas);
  /// ```
  ///
  /// Because the player was built with [DragonBonesAssets], the first `fit`
  /// measures a stable box across every clip (a throwaway armature, so the live
  /// one is never disturbed) and caches it in [skeletonBounds]. The box then
  /// never moves, and no draw list is built just to place the character.
  ///
  /// The bounds are resolved in this order:
  ///
  /// 1. an explicit [bounds] argument,
  /// 2. [skeletonBounds] — the stable box, measured on first use when the
  ///    player was built with [DragonBonesAssets],
  /// 3. the **current** pose ([computeBounds]) unless [useCurrentPose] forces it.
  ///
  /// With a stable box the placement is computed once and never again, which is
  /// what a game component wants. Without [DragonBonesAssets] (a hand-built
  /// armature), `fit` falls back to the pose, so a clip whose silhouette differs
  /// a lot can make the box jump — pass a fixed [bounds] (the union of the
  /// clips), or build the player with `assets:` so it measures one. Use
  /// [useCurrentPose] when you specifically want the box of the frame being
  /// drawn (a tight hitbox, say).
  ///
  /// [align] positions the scaled art inside the box the way Flutter's `Align`
  /// does: the content is placed in whatever space is left over, so it touches
  /// the aligned edge and never leaves the box. `Alignment.bottomCenter`, for
  /// example, puts the character's feet on the bottom edge — not half of it
  /// below the box. With `cover` (which overflows an axis) the crop is centred
  /// on the alignment instead.
  ///
  /// Nothing happens when [fit] is [DragonBonesFit.none], when [size] is empty,
  /// or when the bounds have no extent — the existing [scale]/[offset] are left
  /// untouched, which is what lets a widget opt out and keep a manual placement.
  ///
  /// Returns the bounds that were fitted, or null when there were none.
  Rect? fit({
    required Size size,
    DragonBonesFit fit = DragonBonesFit.contain,
    Alignment align = Alignment.center,
    Rect? bounds,
    bool useCurrentPose = false,
  }) {
    final rect = bounds ??
        (useCurrentPose
            ? computeBounds()
            : (_stableBounds() ?? computeBounds()));

    if (fit == DragonBonesFit.none ||
        size.isEmpty ||
        rect == null ||
        rect.isEmpty) {
      return rect;
    }

    // `Alignment` runs -1..1 on each axis; the placement below remaps it to
    // 0..1 and applies it to the free space left after scaling.
    final sx = size.width / rect.width;
    final sy = size.height / rect.height;
    final s = switch (fit) {
      DragonBonesFit.cover => math.max(sx, sy),
      DragonBonesFit.fitWidth => sx,
      DragonBonesFit.fitHeight => sy,
      DragonBonesFit.contain || DragonBonesFit.none => math.min(sx, sy),
    };

    scale = s;

    // Place the scaled bounds inside the box. `align` runs -1..1 on each axis;
    // remap it to 0..1 and apply it to the *free space* left over after
    // scaling, so the content touches the aligned edge without leaving the box
    // — the same semantics as Flutter's `Align`/`FittedBox`. When `cover`
    // overflows an axis the free space is negative, and the content crops
    // symmetrically around the alignment instead.
    final freeX = size.width - rect.width * s;
    final freeY = size.height - rect.height * s;
    final alignX = (align.x + 1) / 2;
    final alignY = (align.y + 1) / 2;

    offset = Offset(
      freeX * alignX - rect.left * s,
      freeY * alignY - rect.top * s,
    );

    return rect;
  }

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

/// Bounding box of a draw list, in armature coordinates.
///
/// Sprites contribute their posed quad; deformable meshes contribute their
/// posed triangle vertices. Slots that are invisible, or that have no texture,
/// are skipped. Returns null when nothing is drawable.
///
/// This is the geometry behind [DragonBonesPlayer.computeBounds], exposed so a
/// throwaway armature can be measured without going through a player.
Rect? boundsOfDrawList(List<db.SlotDrawData> drawList) {
  Rect? result;

  void include(double x, double y) {
    result = result == null
        ? Rect.fromLTWH(x, y, 0, 0)
        : result!.expandToInclude(Rect.fromLTWH(x, y, 0, 0));
  }

  for (final data in drawList) {
    if (!data.visible || data.texture == null) {
      continue;
    }
    final m = data.matrix;

    final mesh = data.mesh;
    if (mesh != null) {
      // A mesh has no quad: its extent is the posed triangle list, already in
      // armature space but still to be transformed by the slot matrix.
      for (var i = 0; i < mesh.vertices.length; i += 2) {
        final px = mesh.vertices[i];
        final py = mesh.vertices[i + 1];
        include(m.a * px + m.c * py + m.tx, m.b * px + m.d * py + m.ty);
      }
      continue;
    }

    for (final corner in data.localQuad) {
      include(m.a * corner[0] + m.c * corner[1] + m.tx,
          m.b * corner[0] + m.d * corner[1] + m.ty);
    }
  }
  return result;
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
