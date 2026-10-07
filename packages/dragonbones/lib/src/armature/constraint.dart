part of '../../dragonbones.dart';

/// @internal
///
/// Inverse kinematics: bends a bone (and optionally its parent) so the target
/// bone's position is reached. Ported from
/// `.ref/dragonBones-ts/armature/Constraint.ts` (`IKConstraint`).
///
/// This is the piece that made `mecha_1406`, `skin_1502b` and the `you_xin`
/// characters diverge from the official runtime: their `ik` entries omit
/// `weight`, which the parser defaults to `1.0` — active. `龙`'s IK entries set
/// `weight: 0`, which is exactly why it matched while these did not.
///
/// Nothing calls this directly: [Bone.update] is what drives it. A bone whose
/// `_hasConstraint` is set walks the armature's constraints and updates the ones
/// rooted at it, which is how the result lands in the global transforms.
class IKConstraint extends Constraint {
  /// @internal
  bool _bendPositive = false;

  /// @internal
  double _weight = 1.0;

  @override
  void _onClear() {
    super._onClear();

    this._bendPositive = false;
    this._weight = 1.0;
  }

  @override
  void init(ConstraintData constraintData, Armature armature) {
    if (this._constraintData != null) {
      return;
    }

    this._constraintData = constraintData;
    this._armature = armature;
    // The parser refuses to build an IK constraint whose bones are missing
    // (`_parseIKConstraint` returns null), so these resolve.
    this._target = this._armature!.getBone(this._constraintData!.target!.name);
    this._root = this._armature!.getBone(this._constraintData!.root!.name);
    this._bone = this._constraintData!.bone != null ? this._armature!.getBone(this._constraintData!.bone!.name) : null;

    final ikConstraintData = this._constraintData as IKConstraintData;
    this._bendPositive = ikConstraintData.bendPositive;
    this._weight = ikConstraintData.weight;

    this._root!._hasConstraint = true;
  }

  @override
  void update() {
    this._root!.updateByConstraint();

    if (this._bone != null) {
      this._bone!.updateByConstraint();
      this._computeB();
    } else {
      this._computeA();
    }
  }

  @override
  void invalidUpdate() {
    this._root!.invalidUpdate();

    if (this._bone != null) {
      this._bone!.invalidUpdate();
    }
  }

  /// Single-bone IK: just aim the root at the target.
  void _computeA() {
    final ikGlobal = this._target!.global;
    final global = this._root!.global;
    final globalTransformMatrix = this._root!.globalTransformMatrix;

    var radian = math.atan2(ikGlobal.y - global.y, ikGlobal.x - global.x);
    if (global.scaleX < 0.0) {
      radian += math.pi;
    }

    global.rotation += Transform.normalizeRadian(radian - global.rotation) * this._weight;
    global.toMatrix(globalTransformMatrix);
  }

  /// Two-bone IK: solve the triangle formed by root, bone and target, then place
  /// both bones along it.
  void _computeB() {
    final boneLength = this._bone!._boneData!.length;
    final parent = this._root!;
    final ikGlobal = this._target!.global;
    final parentGlobal = parent.global;
    final global = this._bone!.global;
    final globalTransformMatrix = this._bone!.globalTransformMatrix;

    final x = globalTransformMatrix.a * boneLength;
    final y = globalTransformMatrix.b * boneLength;
    final lLL = x * x + y * y;
    final lL = math.sqrt(lLL);
    var dX = global.x - parentGlobal.x;
    var dY = global.y - parentGlobal.y;
    final lPP = dX * dX + dY * dY;
    final lP = math.sqrt(lPP);
    final rawRadian = global.rotation;
    final rawParentRadian = parentGlobal.rotation;
    final rawRadianA = math.atan2(dY, dX);

    dX = ikGlobal.x - parentGlobal.x;
    dY = ikGlobal.y - parentGlobal.y;
    final lTT = dX * dX + dY * dY;
    final lT = math.sqrt(lTT);

    var radianA = 0.0;

    if (lL + lP <= lT || lT + lL <= lP || lT + lP <= lL) {
      // Out of reach: point straight at the target. The first case needs no
      // adjustment, which is why upstream leaves that branch empty.
      radianA = math.atan2(ikGlobal.y - parentGlobal.y, ikGlobal.x - parentGlobal.x);
      if (lL + lP <= lT) {
        // Unreachable — nothing to do.
      } else if (lP < lL) {
        radianA += math.pi;
      }
    } else {
      final h = (lPP - lLL + lTT) / (2.0 * lTT);
      final r = math.sqrt(lPP - h * h * lTT) / lT;
      final hX = parentGlobal.x + (dX * h);
      final hY = parentGlobal.y + (dY * h);
      final rX = -dY * r;
      final rY = dX * r;

      var isPPR = false;
      final parentParent = parent.parent;
      if (parentParent != null) {
        final parentParentMatrix = parentParent.globalTransformMatrix;
        isPPR = parentParentMatrix.a * parentParentMatrix.d - parentParentMatrix.b * parentParentMatrix.c < 0.0;
      }

      if (isPPR != this._bendPositive) {
        global.x = hX - rX;
        global.y = hY - rY;
      } else {
        global.x = hX + rX;
        global.y = hY + rY;
      }

      radianA = math.atan2(global.y - parentGlobal.y, global.x - parentGlobal.x);
    }

    final dR = Transform.normalizeRadian(radianA - rawRadianA);
    parentGlobal.rotation = rawParentRadian + dR * this._weight;
    parentGlobal.toMatrix(parent.globalTransformMatrix);

    final currentRadianA = rawRadianA + dR * this._weight;
    global.x = parentGlobal.x + math.cos(currentRadianA) * lP;
    global.y = parentGlobal.y + math.sin(currentRadianA) * lP;

    var radianB = math.atan2(ikGlobal.y - global.y, ikGlobal.x - global.x);
    if (global.scaleX < 0.0) {
      radianB += math.pi;
    }

    global.rotation = parentGlobal.rotation +
        rawRadian -
        rawParentRadian +
        Transform.normalizeRadian(radianB - dR - rawRadian) * this._weight;
    global.toMatrix(globalTransformMatrix);
  }
}
