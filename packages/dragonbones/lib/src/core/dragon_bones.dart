part of '../../dragonbones.dart';

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
  final List<EventObject> _events = <EventObject>[];
  final List<Object> _objects = <Object>[];
  IEventDispatcher? _eventManager;

  /// [eventManager] receives *global* events — in practice only
  /// [EventObject.SOUND_EVENT], because audio belongs to the application rather
  /// than to one armature.
  ///
  /// Upstream makes the argument required. Here it is optional, so a headless
  /// consumer that only cares about frame events can leave it out and still get
  /// every other event through the armature's own proxy.
  DragonBones([this._eventManager]);

  WorldClock get clock => _clock;

  IEventDispatcher? get eventManager => _eventManager;

  void advanceTime(double passedTime) {
    if (_objects.isNotEmpty) {
      _objects.clear();
    }

    _clock.advanceTime(passedTime);

    // Events are dispatched *after* the clock, never during it: a listener is
    // free to play an animation or dispose a child without mutating the
    // timeline that is still being walked.
    if (_events.isNotEmpty) {
      for (var i = 0; i < _events.length; ++i) {
        final eventObject = _events[i];
        final armature = eventObject.armature;

        if (armature != null && armature._armatureData != null) {
          // May be armature disposed before advanceTime.
          armature.eventDispatcher.dispatchDBEvent(eventObject.type, eventObject);

          if (eventObject.type == EventObject.SOUND_EVENT) {
            _eventManager?.dispatchDBEvent(eventObject.type, eventObject);
          }
        }

        bufferObject(eventObject);
      }

      _events.clear();
    }
  }

  /// - Queues [value] for dispatch at the end of the current [advanceTime].
  ///
  /// Note this is driven by *this* hub: an armature advanced directly through
  /// [Armature.advanceTime], bypassing the clock, buffers events that nobody
  /// will flush. Attach the armature to [clock] and advance this object, the
  /// way an engine binding does.
  void bufferEvent(EventObject value) {
    if (!_events.contains(value)) {
      _events.add(value);
    }
  }

  void bufferObject(BaseObject object) {
    if (!_objects.contains(object)) {
      _objects.add(object);
    }
  }
}

/// - The clock every armature of a hub is attached to, ported from
/// `.ref/dragonBones-ts/animation/WorldClock.ts`.
///
/// The list handling here is load-bearing, not bookkeeping. `remove` blanks an
/// entry instead of shifting the list, and [advanceTime] compacts it in place
/// while walking. That is because an armature can be disposed *during* the walk:
/// a `displayFrame` timeline that swaps a slot to a different child armature
/// drops the previous one, and its `_onClear` detaches it from this very clock.
/// A plain `removeAt` would shift the list under the running loop and walk off
/// the end.
abstract class IAnimatable {
  void advanceTime(double passedTime);
  WorldClock? get clock;
  set clock(WorldClock? value);
}

class WorldClock {
  double time;
  double timeScale = 1.0;

  final List<IAnimatable?> _animatebles = <IAnimatable?>[];

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

    // `l` is captured once; a disposal during the walk blanks an entry but never
    // changes the length, and `r` carries the gap left behind so entries can be
    // shifted down behind it.
    var i = 0, r = 0;
    var l = _animatebles.length;

    for (; i < l; ++i) {
      final animatable = _animatebles[i];

      if (animatable != null) {
        if (r > 0) {
          _animatebles[i - r] = animatable;
          _animatebles[i] = null;
        }

        animatable.advanceTime(passedTime);
      } else {
        r++;
      }
    }

    // Anything appended by the walk itself (a nested armature built during an
    // update) was not covered by the captured length, so it is compacted here.
    if (r > 0) {
      l = _animatebles.length;

      for (; i < l; ++i) {
        final animatable = _animatebles[i];

        if (animatable != null) {
          _animatebles[i - r] = animatable;
        } else {
          r++;
        }
      }

      _animatebles.length -= r;
    }
  }

  void add(IAnimatable value) {
    if (_animatebles.indexOf(value) < 0) {
      _animatebles.add(value);
      // Upstream sets this too, and the armature relies on it: a nested
      // armature inherits its parent's clock through `Slot._updateDisplay`.
      value.clock = this;
    }
  }

  void remove(IAnimatable value) {
    final index = _animatebles.indexOf(value);

    if (index >= 0) {
      // Blank, do not shift — and blank *before* clearing the back-reference,
      // which re-enters this method through the `clock` setter. The second
      // entry finds nothing (indexOf is now -1) and stops.
      _animatebles[index] = null;
      value.clock = null;
    }
  }

  /// - Detaches every instance, without touching the list.
  void clear() {
    for (final animatable in _animatebles) {
      if (animatable != null) {
        animatable.clock = null;
      }
    }
  }
}
