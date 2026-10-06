part of dragonbones;

/// @private
class BinaryOffset {
  static const int WeigthBoneCount = 0;
  static const int WeigthFloatOffset = 1;
  static const int WeigthBoneIndices = 2;

  static const int GeometryVertexCount = 0;
  static const int GeometryTriangleCount = 1;
  static const int GeometryFloatOffset = 2;
  static const int GeometryWeightOffset = 3;
  static const int GeometryVertexIndices = 4;

  static const int TimelineScale = 0;
  static const int TimelineOffset = 1;
  static const int TimelineKeyFrameCount = 2;
  static const int TimelineFrameValueCount = 3;
  static const int TimelineFrameValueOffset = 4;
  static const int TimelineFrameOffset = 5;

  static const int FramePosition = 0;
  static const int FrameTweenType = 1;
  static const int FrameTweenEasingOrCurveSampleCount = 2;
  static const int FrameCurveSamples = 3;

  static const int DeformVertexOffset = 0;
  static const int DeformCount = 1;
  static const int DeformValueCount = 2;
  static const int DeformValueOffset = 3;
  static const int DeformFloatOffset = 4;
}

/// @private
class FrameValueType {
  static const int Step = 0;
  static const int Int = 1;
  static const int Float = 2;
}

/// @private
class ArmatureType {
  static const int Armature = 0;
  static const int MovieClip = 1;
  static const int Stage = 2;
}

/// @private
class BoneType {
  static const int Bone = 0;
  static const int Surface = 1;
}

/// @private
class DisplayType {
  static const int Image = 0;
  static const int Armature = 1;
  static const int Mesh = 2;
  static const int BoundingBox = 3;
  static const int Path = 4;
}

/// @private
class BoundingBoxType {
  static const int Rectangle = 0;
  static const int Ellipse = 1;
  static const int Polygon = 2;
}

/// @private
class ActionType {
  static const int Play = 0;
  static const int Frame = 10;
  static const int Sound = 11;
}

/// @private
class BlendMode {
  static const int Normal = 0;
  static const int Add = 1;
  static const int Alpha = 2;
  static const int Darken = 3;
  static const int Difference = 4;
  static const int Erase = 5;
  static const int HardLight = 6;
  static const int Invert = 7;
  static const int Layer = 8;
  static const int Lighten = 9;
  static const int Multiply = 10;
  static const int Overlay = 11;
  static const int Screen = 12;
  static const int Subtract = 13;
}

/// @private
class TweenType {
  static const int None = 0;
  static const int Line = 1;
  static const int Curve = 2;
  static const int QuadIn = 3;
  static const int QuadOut = 4;
  static const int QuadInOut = 5;
}

/// @private
class TimelineType {
  static const int Action = 0;
  static const int ZOrder = 1;

  static const int BoneAll = 10;
  static const int BoneTranslate = 11;
  static const int BoneRotate = 12;
  static const int BoneScale = 13;

  static const int Surface = 50;
  static const int BoneAlpha = 60;

  static const int SlotDisplay = 20;
  static const int SlotColor = 21;
  static const int SlotDeform = 22;
  static const int SlotZIndex = 23;
  static const int SlotAlpha = 24;

  static const int IKConstraint = 30;

  static const int AnimationProgress = 40;
  static const int AnimationWeight = 41;
  static const int AnimationParameter = 42;
}

/// @private
class OffsetMode {
  static const int None = 0;
  static const int Additive = 1;
  static const int Override = 2;
}

/// @private
class ConstraintType {
  static const int IK = 0;
  static const int Path = 1;
}

/// @private
class PositionMode {
  static const int Fixed = 0;
  static const int Percent = 1;
}

/// @private
class SpacingMode {
  static const int Length = 0;
  static const int Fixed = 1;
  static const int Percent = 2;
}

/// @private
class RotateMode {
  static const int Tangent = 0;
  static const int Chain = 1;
  static const int ChainScale = 2;
}

/// @private
class AnimationFadeOutMode {
  static const int SameLayer = 1;
  static const int SameGroup = 2;
  static const int SameLayerAndGroup = 3;
  static const int All = 4;
  static const int Single = 5;
}

/// @private
class AnimationBlendType {
  static const int None = 0;
  static const int E1D = 1;
}

/// The runtime singleton. Only the pieces needed by milestone 1 are ported.
class DragonBones {
  static const String VERSION = '5.7.000';
  static bool yDown = true;
  static bool debug = false;
  static bool debugDraw = false;

  final WorldClock _clock = WorldClock();
  final List<Object> _objects = <Object>[];

  WorldClock get clock => _clock;

  void advanceTime(double passedTime) {
    if (_objects.length > 0) {
      _objects.clear();
    }
    _clock.advanceTime(passedTime);
  }

  void bufferObject(BaseObject object) {
    if (!_objects.contains(object)) {
      _objects.add(object);
    }
  }
}

/// Minimal clock. The oracle harness advances the armature directly, so the
/// clock only needs to exist for API compatibility.
///
/// Faithful port of `.ref/dragonBones-ts/animation/WorldClock.ts` (the
/// clock-attached objects are advanced like upstream, though nothing attaches
/// to it in the headless harness).
abstract class IAnimatable {
  void advanceTime(double passedTime);
  WorldClock? get clock;
  set clock(WorldClock? value);
}

class WorldClock {
  double time;
  double timeScale = 1.0;

  final List<IAnimatable> _animatebles = <IAnimatable>[];

  WorldClock([this.time = 0.0]);

  void advanceTime(double passedTime) {
    if (passedTime != passedTime) {
      passedTime = 0.0;
    }
    if (timeScale != 1.0) {
      passedTime *= timeScale;
    }
    if (passedTime == 0.0) {
      return;
    }
    if (passedTime < 0.0) {
      time -= passedTime;
    } else {
      time += passedTime;
    }

    for (var i = 0, l = _animatebles.length; i < l; ++i) {
      final animateble = _animatebles[i];
      animateble.advanceTime(passedTime);
    }
  }

  void add(IAnimatable value) {
    if (_animatebles.indexOf(value) < 0 && value != this) {
      _animatebles.add(value);
    }
  }

  void remove(IAnimatable value) {
    final index = _animatebles.indexOf(value);
    if (index >= 0) {
      _animatebles.removeAt(index);
    }
  }
}
