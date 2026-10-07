part of '../../dragonbones.dart';

/// @private
class ConstraintData extends BaseObject {
  int order = 0;
  String name = '';
  int type = ConstraintType.IK;
  BoneData? target;
  BoneData? bone;
  BoneData? root;

  @override
  void _onClear() {
    this.order = 0;
    this.name = '';
    this.type = ConstraintType.IK;
    this.target = null;
    this.bone = null;
    this.root = null;
  }
}

/// @private
class CanvasData extends BaseObject {
  bool hasBackground = false;
  int color = 0;
  double x = 0.0;
  double y = 0.0;
  double width = 0.0;
  double height = 0.0;

  @override
  void _onClear() {
    this.hasBackground = false;
    this.color = 0;
    this.x = 0.0;
    this.y = 0.0;
    this.width = 0.0;
    this.height = 0.0;
  }
}

/// @private
class ArmatureData extends BaseObject {
  int type = ArmatureType.Armature;
  double frameRate = 0.0;
  double cacheFrameRate = 0.0;
  double scale = 1.0;
  String name = '';
  final Rectangle aabb = Rectangle();
  final List<String> animationNames = <String>[];
  final List<BoneData> sortedBones = <BoneData>[];
  final List<SlotData> sortedSlots = <SlotData>[];
  final List<ActionData> defaultActions = <ActionData>[];
  final List<ActionData> actions = <ActionData>[];
  final Map<String, BoneData> bones = <String, BoneData>{};
  final Map<String, SlotData> slots = <String, SlotData>{};
  final Map<String, ConstraintData> constraints = <String, ConstraintData>{};
  final Map<String, SkinData> skins = <String, SkinData>{};
  final Map<String, AnimationData> animations = <String, AnimationData>{};
  SkinData? defaultSkin;
  AnimationData? defaultAnimation;
  CanvasData? canvas;
  UserData? userData;
  DragonBonesData? parent;

  @override
  void _onClear() {
    this.defaultActions.clear();
    this.actions.clear();
    this.bones.clear();
    this.slots.clear();
    this.constraints.clear();
    this.skins.clear();
    this.animations.clear();
    this.type = ArmatureType.Armature;
    this.frameRate = 0.0;
    this.cacheFrameRate = 0.0;
    this.scale = 1.0;
    this.name = '';
    this.aabb.clear();
    this.animationNames.length = 0;
    this.sortedBones.length = 0;
    this.sortedSlots.length = 0;
    this.defaultSkin = null;
    this.defaultAnimation = null;
    this.canvas = null;
    this.userData = null;
    this.parent = null;
  }

  void sortBones() {
    final total = this.sortedBones.length;
    if (total <= 0) {
      return;
    }

    final sortHelper = this.sortedBones.toList();
    var index = 0;
    var count = 0;
    this.sortedBones.length = 0;
    while (count < total) {
      final bone = sortHelper[index++];
      if (index >= total) {
        index = 0;
      }

      if (this.sortedBones.indexOf(bone) >= 0) {
        continue;
      }

      var flag = false;
      for (final constraint in this.constraints.values) {
        if (constraint.root == bone && this.sortedBones.indexOf(constraint.target!) < 0) {
          flag = true;
          break;
        }
      }

      if (flag) {
        continue;
      }

      if (bone.parent != null && this.sortedBones.indexOf(bone.parent!) < 0) {
        continue;
      }

      this.sortedBones.add(bone);
      count++;
    }
  }

  void cacheFrames(double frameRate) {
    if (this.cacheFrameRate > 0.0) {
      return;
    }
    this.cacheFrameRate = frameRate;
    for (final animation in this.animations.values) {
      animation.cacheFrameRate = 0.0; // Caching not used by this port.
    }
  }

  /// @internal
  ///
  /// Animation caching is not used by this port (`cacheFrameRate` stays 0, so
  /// `Bone.update`/`Slot.update` are always called with `cacheFrameIndex < 0`).
  /// These two entry points exist so the armature layer can transcribe the
  /// upstream cache branches verbatim; they are never reached.
  int setCacheFrame(Matrix globalTransformMatrix, Transform transform) => 0;

  /// @internal
  void getCacheFrame(Matrix globalTransformMatrix, Transform transform, int arrayOffset) {}

  void addBone(BoneData value) {
    if (this.bones.containsKey(value.name)) {
      return;
    }
    this.bones[value.name] = value;
    this.sortedBones.add(value);
  }

  void addSlot(SlotData value) {
    if (this.slots.containsKey(value.name)) {
      return;
    }
    this.slots[value.name] = value;
    this.sortedSlots.add(value);
  }

  void addConstraint(ConstraintData value) {
    if (this.constraints.containsKey(value.name)) {
      return;
    }
    this.constraints[value.name] = value;
  }

  void addSkin(SkinData value) {
    if (this.skins.containsKey(value.name)) {
      return;
    }
    value.parent = this;
    this.skins[value.name] = value;
    if (this.defaultSkin == null) {
      this.defaultSkin = value;
    }
    if (value.name == 'default') {
      this.defaultSkin = value;
    }
  }

  void addAnimation(AnimationData value) {
    if (this.animations.containsKey(value.name)) {
      return;
    }
    value.parent = this;
    this.animations[value.name] = value;
    this.animationNames.add(value.name);
    if (this.defaultAnimation == null) {
      this.defaultAnimation = value;
    }
  }

  void addAction(ActionData value, bool isDefault) {
    if (isDefault) {
      this.defaultActions.add(value);
    } else {
      this.actions.add(value);
    }
  }

  BoneData? getBone(String boneName) => this.bones[boneName];
  SlotData? getSlot(String slotName) => this.slots[slotName];
  ConstraintData? getConstraint(String constraintName) => this.constraints[constraintName];
  SkinData? getSkin(String skinName) => this.skins[skinName];
  AnimationData? getAnimation(String animationName) => this.animations[animationName];

  MeshDisplayData? getMesh(String skinName, String slotName, String meshName) {
    final skin = this.getSkin(skinName);
    if (skin == null) {
      return null;
    }
    return skin.getDisplay(slotName, meshName) as MeshDisplayData?;
  }
}

/// @private
class BoneData extends BaseObject {
  bool inheritTranslation = false;
  bool inheritRotation = false;
  bool inheritScale = false;
  bool inheritReflection = false;
  int type = BoneType.Bone;
  double length = 0.0;
  double alpha = 1.0;
  String name = '';
  final Transform transform = Transform();
  UserData? userData;
  BoneData? parent;

  @override
  void _onClear() {
    this.inheritTranslation = false;
    this.inheritRotation = false;
    this.inheritScale = false;
    this.inheritReflection = false;
    this.type = BoneType.Bone;
    this.length = 0.0;
    this.alpha = 1.0;
    this.name = '';
    this.transform.identity();
    this.userData = null;
    this.parent = null;
  }
}

/// @private
class SlotData extends BaseObject {
  static final ColorTransform defaultColor = ColorTransform();

  static ColorTransform createColor() => ColorTransform();

  int blendMode = BlendMode.Normal;
  int displayIndex = 0;
  int zOrder = 0;
  int zIndex = 0;
  double alpha = 1.0;
  String name = '';
  ColorTransform color = defaultColor;
  UserData? userData;
  BoneData? parent;

  @override
  void _onClear() {
    this.blendMode = BlendMode.Normal;
    this.displayIndex = 0;
    this.zOrder = 0;
    this.zIndex = 0;
    this.alpha = 1.0;
    this.name = '';
    this.color = defaultColor;
    this.userData = null;
    this.parent = null;
  }
}

/// @private
class SurfaceData extends BoneData {
  int segmentX = 0;
  int segmentY = 0;
  final GeometryData geometry = GeometryData();

  @override
  void _onClear() {
    super._onClear();
    this.type = BoneType.Surface;
    this.segmentX = 0;
    this.segmentY = 0;
    this.geometry.clear();
  }
}

/// @private
class IKConstraintData extends ConstraintData {
  bool scaleEnabled = false;
  bool bendPositive = false;
  double weight = 1.0;

  @override
  void _onClear() {
    super._onClear();
    this.scaleEnabled = false;
    this.bendPositive = false;
    this.weight = 1.0;
  }
}

/// @private
class PathConstraintData extends ConstraintData {
  SlotData? pathSlot;
  PathDisplayData? pathDisplayData;
  final List<BoneData> bones = <BoneData>[];
  int positionMode = PositionMode.Fixed;
  int spacingMode = SpacingMode.Fixed;
  int rotateMode = RotateMode.Chain;
  double position = 0.0;
  double spacing = 0.0;
  double rotateOffset = 0.0;
  double rotateMix = 0.0;
  double translateMix = 0.0;

  @override
  void _onClear() {
    super._onClear();
    this.pathSlot = null;
    this.pathDisplayData = null;
    this.bones.length = 0;
    this.positionMode = PositionMode.Fixed;
    this.spacingMode = SpacingMode.Fixed;
    this.rotateMode = RotateMode.Chain;
    this.position = 0.0;
    this.spacing = 0.0;
    this.rotateOffset = 0.0;
    this.rotateMix = 0.0;
    this.translateMix = 0.0;
  }

  void addBone(BoneData value) {
    this.bones.add(value);
  }
}
