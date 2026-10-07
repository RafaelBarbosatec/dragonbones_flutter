part of dragonbones;

/// One thing to draw for one slot at the armature's current pose.
///
/// Framework-agnostic on purpose: it carries plain numbers and no `dart:ui`. A
/// renderer turns this into canvas calls; a game-engine component turns the same
/// data into a component. This is the seam that keeps the runtime usable from
/// any Flutter project, any game engine, or a headless test.
///
/// Two shapes are possible, and they are drawn differently:
///
/// * **Sprite** ([mesh] is null) — the quad
///   `(-pivot.x, -pivot.y) .. (quadWidth - pivot.x, quadHeight - pivot.y)` in
///   slot-local space, transformed by [matrix]. That is exactly the anchor
///   maths an engine performs: `tx - (a * pivotX + c * pivotY)`, and so on.
/// * **Mesh** ([mesh] is not null) — a triangle list whose vertices are already
///   posed in armature space by [buildMeshGeometry]; draw them with [matrix]
///   and the mesh's own UVs.
class SlotDrawData {
  SlotDrawData({
    required this.slotName,
    required this.matrix,
    required this.pivotX,
    required this.pivotY,
    required this.quadWidth,
    required this.quadHeight,
    required this.zOrder,
    required this.blendMode,
    required this.visible,
    required this.color,
    this.texture,
    this.mesh,
    this.displayIndex = 0,
  });

  /// The slot this comes from (or the owning child-armature slot, when this
  /// entry was produced by a nested armature).
  final String slotName;

  /// The slot's world transform.
  final Matrix matrix;

  /// The point of the display that sits on the slot origin.
  ///
  /// Always 0 for meshes: vertex positions already carry any offset.
  final double pivotX;
  final double pivotY;

  /// Size of the sprite quad, already scaled by atlas scale x armature scale.
  /// Meaningless for meshes (use [mesh]); zero.
  final double quadWidth;
  final double quadHeight;

  /// Draw order. Lower first.
  final int zOrder;

  /// DragonBones blend mode enum value (`BlendMode.Normal` is 0).
  final int blendMode;

  final bool visible;

  /// Slot colour: `[aM, rM, gM, bM, aO, rO, gO, bO]`.
  final List<double> color;

  /// The atlas entry to sample, or null when nothing should be drawn.
  final TextureData? texture;

  /// Posed triangle mesh, or null when this is a plain sprite.
  final MeshGeometry? mesh;

  final int displayIndex;

  /// True when this slot holds a triangle mesh rather than a quad.
  bool get isMesh => this.mesh != null;

  /// Atlas rectangle to sample: `[x, y, width, height]`, or null.
  List<double>? get region {
    final data = this.texture;
    if (data == null) return null;
    final r = data.region;
    return <double>[r.x, r.y, r.width, r.height];
  }

  /// Whether the atlas entry is stored rotated 90° and must be un-rotated.
  bool get rotated => this.texture?.rotated ?? false;

  /// The four corners of the quad, in slot-local space, winding clockwise from
  /// the top-left. Callers transform them by [matrix].
  List<List<double>> get localQuad {
    final left = -this.pivotX;
    final top = -this.pivotY;
    final right = left + this.quadWidth;
    final bottom = top + this.quadHeight;
    return <List<double>>[
      <double>[left, top],
      <double>[right, top],
      <double>[right, bottom],
      <double>[left, bottom],
    ];
  }

  @override
  String toString() => 'SlotDrawData($slotName, z=$zOrder, '
      '${isMesh ? '$mesh' : 'quad=$quadWidth x $quadHeight'})';
}

/// Builds the ordered draw list for the armature's current pose.
///
/// Separated from the runtime so that the runtime stays renderer-agnostic, and
/// so the list itself can be diffed against the official runtime.
///
/// Nested armatures are flattened: a slot holding a child armature contributes
/// no draw of its own, but the child's slots are emitted in its place, with
/// their transforms composed onto the parent slot's. That mirrors what an
/// engine does by parenting the child's display object to the slot's, and it
/// means a renderer never has to know child armatures exist.
extension ArmatureDrawList on Armature {
  /// Every visible slot, sorted by z-order — the order a renderer must draw in.
  List<SlotDrawData> buildDrawList() {
    final entries = <_SortableDraw>[];
    _collect(this, null, null, entries);

    // Tie-break on insertion order so a flattened child armature keeps its own
    // z-order instead of being reshuffled by an unstable sort.
    entries.sort((a, b) {
      final byZ = a.data.zOrder.compareTo(b.data.zOrder);
      return byZ != 0 ? byZ : a.sequence.compareTo(b.sequence);
    });

    return <SlotDrawData>[for (final entry in entries) entry.data];
  }

  void _collect(
    Armature armature,
    Matrix? parentMatrix,
    int? zOverride,
    List<_SortableDraw> out,
  ) {
    final armatureScale = armature.armatureData.scale;

    for (final slot in armature.getSlots()) {
      final matrix = parentMatrix == null
          ? slot.globalTransformMatrix
          : _concat(parentMatrix, slot.globalTransformMatrix);

      final childArmature = slot.childArmature;
      if (childArmature != null) {
        // A slot with a nested armature draws nothing itself; the child's slots
        // take its place in the order.
        _collect(childArmature, matrix, zOverride ?? slot.zOrder, out);
        continue;
      }

      final textureData = slot.textureData;
      final geometry = slot.geometryData;

      MeshGeometry? mesh;
      if (geometry != null) {
        mesh = buildMeshGeometry(
          geometry: geometry,
          bones: slot.geometryBones,
          deformVertices: slot.deformVertices,
          scale: armatureScale,
        );
      }

      if (mesh == null && textureData == null) {
        continue; // nothing to draw
      }

      final atlasScale = textureData?.parent?.scale ?? 1.0;
      final scale = atlasScale * armatureScale;
      final rotated = textureData?.rotated ?? false;
      final region = textureData?.region;
      final regionW = region?.width ?? 0.0;
      final regionH = region?.height ?? 0.0;

      out.add(_SortableDraw(
        out.length,
        SlotDrawData(
          slotName: slot.name,
          matrix: matrix,
          // A mesh carries its own offsets; upstream zeroes the pivot for it.
          pivotX: mesh != null ? 0.0 : slot.pivotX,
          pivotY: mesh != null ? 0.0 : slot.pivotY,
          quadWidth: mesh != null ? 0.0 : (rotated ? regionH : regionW) * scale,
          quadHeight:
              mesh != null ? 0.0 : (rotated ? regionW : regionH) * scale,
          zOrder: zOverride ?? slot.zOrder,
          blendMode: slot.blendMode,
          visible: slot.isVisible,
          color: slot.colorValues,
          texture: textureData,
          mesh: mesh,
          displayIndex: slot.displayIndex,
        ),
      ));
    }
  }

  /// Composes a child slot's matrix onto its parent slot's.
  ///
  /// `Matrix.concat` means "apply self, then the argument" (that is how bone
  /// chains compose: `global.copyFrom(local); global.concat(parent)`), so the
  /// child goes in first. Getting this backwards silently mirrors the child
  /// armature about the origin.
  static Matrix _concat(Matrix parent, Matrix child) {
    final result = Matrix();
    result.copyFrom(child);
    result.concat(parent);
    return result;
  }
}

/// A draw entry plus its insertion index, used only for stable ordering.
class _SortableDraw {
  _SortableDraw(this.sequence, this.data);

  final int sequence;
  final SlotDrawData data;
}
