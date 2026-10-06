part of dragonbones;

/// One thing to draw for one slot at the armature's current pose.
///
/// Framework-agnostic on purpose: it carries plain numbers, no `dart:ui`, no
/// Flame. A renderer turns this into a canvas call; a Flame component turns the
/// same data into a component. This is the seam that keeps the runtime usable
/// from any Flutter project, a Flame game, Bonfire, or a headless test.
///
/// A sprite is drawn as the quad
/// `(-pivot.x, -pivot.y) .. (quadWidth - pivot.x, quadHeight - pivot.y)`
/// in slot-local space, transformed by [matrix]. That is exactly the anchor
/// maths an engine performs: `tx - (a * pivotX + c * pivotY)`, and so on.
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
    this.isMesh = false,
    this.displayIndex = 0,
  });

  /// The slot this comes from.
  final String slotName;

  /// The slot's world transform.
  final Matrix matrix;

  /// The point of the display that sits on the slot origin.
  final double pivotX;
  final double pivotY;

  /// Size of the sprite quad, already scaled by atlas scale x armature scale.
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

  /// True when this slot holds a deformable mesh (milestone 2 renders those).
  final bool isMesh;

  final int displayIndex;

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
      'mesh=$isMesh, quad=$quadWidth x $quadHeight)';
}

/// Builds the ordered draw list for the armature's current pose.
///
/// Separated from the runtime so that the runtime stays renderer-agnostic, and
/// so the list itself can be diffed against the official runtime.
extension ArmatureDrawList on Armature {
  /// Every visible slot, sorted by z-order — the order a renderer must draw in.
  List<SlotDrawData> buildDrawList() {
    final list = <SlotDrawData>[];
    for (final slot in this.getSlots()) {
      final textureData = slot.textureData;
      final geometry = slot.geometryData;
      if (geometry == null && textureData == null) {
        continue; // nothing to draw
      }

      final atlasScale = textureData?.parent?.scale ?? 1.0;
      final scale = atlasScale * this.armatureData.scale;
      final rotated = textureData?.rotated ?? false;
      final region = textureData?.region;
      final regionW = region?.width ?? 0.0;
      final regionH = region?.height ?? 0.0;

      list.add(SlotDrawData(
        slotName: slot.name,
        matrix: slot.globalTransformMatrix,
        pivotX: slot.pivotX,
        pivotY: slot.pivotY,
        quadWidth: (rotated ? regionH : regionW) * scale,
        quadHeight: (rotated ? regionW : regionH) * scale,
        zOrder: slot.zOrder,
        blendMode: slot.blendMode,
        visible: slot.isVisible,
        color: slot.colorValues,
        texture: textureData,
        isMesh: geometry != null,
        displayIndex: slot.displayIndex,
      ));
    }

    list.sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return list;
  }
}
