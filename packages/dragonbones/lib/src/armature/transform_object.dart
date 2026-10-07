part of '../../dragonbones.dart';

/// - The base class of the transform object.
///
/// Faithful port of `.ref/dragonBones-ts/armature/TransformObject.ts`.
/// @private
abstract class TransformObject extends BaseObject {
  static final Matrix _helpMatrix = Matrix();
  static final Transform _helpTransform = Transform();
  static final Point _helpPoint = Point();

  /// - A matrix relative to the armature coordinate system.
  final Matrix globalTransformMatrix = Matrix();

  /// - A transform relative to the armature coordinate system.
  final Transform global = Transform();

  /// - The offset transform relative to the armature or the parent bone coordinate system.
  final Transform offset = Transform();

  /// @private
  Transform? origin;

  /// @private
  Object? userData;

  bool _globalDirty = false;

  /// @internal
  double _alpha = 1.0;

  /// @internal
  double _globalAlpha = 1.0;

  /// @internal
  Armature? _armature;

  @override
  void _onClear() {
    this.globalTransformMatrix.identity();
    this.global.identity();
    this.offset.identity();
    this.origin = null;
    this.userData = null;

    this._globalDirty = false;
    this._alpha = 1.0;
    this._globalAlpha = 1.0;
    this._armature = null;
  }

  /// - Ensures that [global]'s rotation/scale are correct after a matrix update.
  void updateGlobalTransform() {
    if (this._globalDirty) {
      this._globalDirty = false;
      this.global.fromMatrix(this.globalTransformMatrix);
    }
  }

  /// - The armature to which it belongs.
  Armature get armature => this._armature!;
}
