part of dragonbones;

/// - The DragonBones data.
/// A DragonBones data contains multiple armature data.
/// @see dragonBones.ArmatureData
/// @version DragonBones 3.0
///
/// Faithful port of `.ref/dragonBones-ts/model/DragonBonesData.ts`.
/// @private
class DragonBonesData extends BaseObject {
  /// @private
  bool autoSearch = false;

  /// - The animation frame rate.
  double frameRate = 0.0;

  /// - The data version.
  String version = '';

  /// - The DragonBones data name.
  String name = '';

  /// @private
  ArmatureData? stage;

  /// @internal
  final List<int> frameIndices = <int>[];

  /// @internal
  final List<int> cachedFrames = <int>[];

  /// - All armature data names.
  final List<String> armatureNames = <String>[];

  /// @private
  final Map<String, ArmatureData> armatures = <String, ArmatureData>{};

  /// @internal
  Uint8List? binary;

  /// @internal
  Int16List? intArray;

  /// @internal
  Float32List? floatArray;

  /// @internal
  Int16List? frameIntArray;

  /// @internal
  Float32List? frameFloatArray;

  /// @internal
  Int16List? frameArray;

  /// @internal
  Uint16List? timelineArray;

  /// @internal
  Int16List? colorArray;

  /// @private
  UserData? userData;

  @override
  void _onClear() {
    for (final key in this.armatures.keys.toList()) {
      this.armatures[key]!.returnToPool();
    }
    this.armatures.clear();

    if (this.userData != null) {
      this.userData!.returnToPool();
    }

    this.autoSearch = false;
    this.frameRate = 0.0;
    this.version = '';
    this.name = '';
    this.stage = null;
    this.frameIndices.length = 0;
    this.cachedFrames.length = 0;
    this.armatureNames.length = 0;
    this.binary = null;
    this.intArray = null;
    this.floatArray = null;
    this.frameIntArray = null;
    this.frameFloatArray = null;
    this.frameArray = null;
    this.timelineArray = null;
    this.colorArray = null;
    this.userData = null;
  }

  /// @internal
  void addArmature(ArmatureData value) {
    if (this.armatures.containsKey(value.name)) {
      // Upstream warns "Same armature: <name>" and returns.
      return;
    }

    value.parent = this;
    this.armatures[value.name] = value;
    this.armatureNames.add(value.name);
  }

  /// - Get a specific armature data.
  ArmatureData? getArmature(String armatureName) {
    return this.armatures.containsKey(armatureName) ? this.armatures[armatureName] : null;
  }
}
