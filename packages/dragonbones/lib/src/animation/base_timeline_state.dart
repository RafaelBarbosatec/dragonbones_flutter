part of dragonbones;

/// @internal
///
/// Faithful port of `.ref/dragonBones-ts/animation/BaseTimelineState.ts`.
///
/// The binary arrays are typed `List<num>` here because Dart's typed lists
/// (`Int16List`, `Uint16List`, `Float32List`) all implement `List<num>`.
abstract class TimelineState extends BaseObject {
  bool dirty = false;

  /// -1: start, 0: play, 1: complete;
  int playState = -1;
  int currentPlayTimes = 0;
  double currentTime = -1.0;
  BaseObject? target;

  bool _isTween = false;
  int _valueOffset = 0;
  int _frameValueOffset = 0;
  int _frameOffset = 0;
  double _frameRate = 0.0;
  int _frameCount = 0;
  int _frameIndex = -1;
  double _frameRateR = 0.0;
  double _position = 0.0;
  double _duration = 0.0;
  double _timeScale = 1.0;
  double _timeOffset = 0.0;
  AnimationData? _animationData;
  TimelineData? _timelineData;
  Armature? _armature;
  AnimationState? _animationState;
  TimelineState? _actionTimeline;
  List<num>? _timelineArray;
  List<num>? _frameArray;
  List<num>? _valueArray;
  List<int>? _frameIndices;

  @override
  void _onClear() {
    this.dirty = false;
    this.playState = -1;
    this.currentPlayTimes = 0;
    this.currentTime = -1.0;
    this.target = null;

    this._isTween = false;
    this._valueOffset = 0;
    this._frameValueOffset = 0;
    this._frameOffset = 0;
    this._frameRate = 0.0;
    this._frameCount = 0;
    this._frameIndex = -1;
    this._frameRateR = 0.0;
    this._position = 0.0;
    this._duration = 0.0;
    this._timeScale = 1.0;
    this._timeOffset = 0.0;
    this._animationData = null;
    this._timelineData = null;
    this._armature = null;
    this._animationState = null;
    this._actionTimeline = null;
    this._frameArray = null;
    this._valueArray = null;
    this._timelineArray = null;
    this._frameIndices = null;
  }

  void _onArriveAtFrame();
  void _onUpdateFrame();

  bool _setCurrentTime(double passedTime) {
    final int prevState = this.playState;
    final int prevPlayTimes = this.currentPlayTimes;
    final double prevTime = this.currentTime;

    if (this._actionTimeline != null && this._frameCount <= 1) {
      // No frame or only one frame.
      this.playState = this._actionTimeline!.playState >= 0 ? 1 : -1;
      this.currentPlayTimes = 1;
      this.currentTime = this._actionTimeline!.currentTime;
    } else if (this._actionTimeline == null || this._timeScale != 1.0 || this._timeOffset != 0.0) {
      // Action timeline or has scale and offset.
      final int playTimes = this._animationState!.playTimes;
      final double totalTime = playTimes * this._duration;

      passedTime *= this._timeScale;
      if (this._timeOffset != 0.0) {
        passedTime += this._timeOffset * this._animationData!.duration;
      }

      if (playTimes > 0 && (passedTime >= totalTime || passedTime <= -totalTime)) {
        if (this.playState <= 0 && this._animationState!._playheadState == 3) {
          this.playState = 1;
        }

        this.currentPlayTimes = playTimes;
        if (passedTime < 0.0) {
          this.currentTime = 0.0;
        } else {
          this.currentTime = this.playState == 1 ? this._duration + 0.000001 : this._duration; // Precision problem
        }
      } else {
        if (this.playState != 0 && this._animationState!._playheadState == 3) {
          this.playState = 0;
        }

        if (passedTime < 0.0) {
          passedTime = -passedTime;
          this.currentPlayTimes = (passedTime / this._duration).floor();
          this.currentTime = this._duration - _jsMod(passedTime, this._duration);
        } else {
          this.currentPlayTimes = (passedTime / this._duration).floor();
          this.currentTime = _jsMod(passedTime, this._duration);
        }
      }

      this.currentTime += this._position;
    } else {
      // Multi frames.
      this.playState = this._actionTimeline!.playState;
      this.currentPlayTimes = this._actionTimeline!.currentPlayTimes;
      this.currentTime = this._actionTimeline!.currentTime;
    }

    if (this.currentPlayTimes == prevPlayTimes && this.currentTime == prevTime) {
      return false;
    }

    // Clear frame flag when timeline start or loopComplete.
    if ((prevState < 0 && this.playState != prevState) ||
        (this.playState <= 0 && this.currentPlayTimes != prevPlayTimes)) {
      this._frameIndex = -1;
    }

    return true;
  }

  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    this._armature = armature;
    this._animationState = animationState;
    this._timelineData = timelineData;
    this._actionTimeline = this._animationState!._actionTimeline;

    if (identical(this, this._actionTimeline)) {
      this._actionTimeline = null;
    }

    this._animationData = this._animationState!.animationData;
    this._frameRate = this._animationData!.parent!.frameRate;
    this._frameRateR = 1.0 / this._frameRate;
    this._position = this._animationState!._position;
    this._duration = this._animationState!._duration;

    if (this._timelineData != null) {
      final dragonBonesData = this._animationData!.parent!.parent!;
      this._frameArray = dragonBonesData.frameArray;
      this._timelineArray = dragonBonesData.timelineArray;
      this._frameIndices = dragonBonesData.frameIndices;
      //
      this._frameCount = this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineKeyFrameCount] as int;
      this._frameValueOffset =
          this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineFrameValueOffset] as int;
      this._timeScale =
          100.0 / (this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineScale] as num).toDouble();
      this._timeOffset =
          (this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineOffset] as num).toDouble() * 0.01;
    }
  }

  void fadeOut() {
    this.dirty = false;
  }

  void update(double passedTime) {
    if (this._setCurrentTime(passedTime)) {
      if (this._frameCount > 1) {
        final int timelineFrameIndex = (this.currentTime * this._frameRate).floor(); // uint
        final int frameIndex = this._frameIndices![this._timelineData!.frameIndicesOffset + timelineFrameIndex];

        if (this._frameIndex != frameIndex) {
          this._frameIndex = frameIndex;
          this._frameOffset = this._animationData!.frameOffset +
              (this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineFrameOffset + this._frameIndex] as int);
          this._onArriveAtFrame();
        }
      } else if (this._frameIndex < 0) {
        this._frameIndex = 0;

        if (this._timelineData != null) {
          this._frameOffset = this._animationData!.frameOffset +
              (this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineFrameOffset] as int);
        }

        this._onArriveAtFrame();
      }

      if (this._isTween || this.dirty) {
        this._onUpdateFrame();
      }
    }
  }

  void blend(bool _isDirty) {}
}

/// @internal
abstract class TweenTimelineState extends TimelineState {
  static double _getEasingValue(int tweenType, double progress, double easing) {
    double value = progress;

    switch (tweenType) {
      case TweenType.QuadIn:
        value = math.pow(progress, 2.0).toDouble();
        break;

      case TweenType.QuadOut:
        value = 1.0 - math.pow(1.0 - progress, 2.0).toDouble();
        break;

      case TweenType.QuadInOut:
        value = 0.5 * (1.0 - math.cos(progress * math.pi));
        break;
    }

    return (value - progress) * easing + progress;
  }

  static double _getEasingCurveValue(double progress, List<num> samples, int count, int offset) {
    if (progress <= 0.0) {
      return 0.0;
    } else if (progress >= 1.0) {
      return 1.0;
    }

    final bool isOmited = count > 0;
    final int segmentCount = count + 1; // + 2 - 1
    final int valueIndex = (progress * segmentCount).floor();
    double fromValue;
    double toValue;

    if (isOmited) {
      fromValue = valueIndex == 0 ? 0.0 : samples[offset + valueIndex - 1].toDouble();
      toValue = (valueIndex == segmentCount - 1) ? 10000.0 : samples[offset + valueIndex].toDouble();
    } else {
      fromValue = samples[offset + valueIndex - 1].toDouble();
      toValue = samples[offset + valueIndex].toDouble();
    }

    return (fromValue + (toValue - fromValue) * (progress * segmentCount - valueIndex)) * 0.0001;
  }

  int _tweenType = TweenType.None;
  int _curveCount = 0;
  double _framePosition = 0.0;
  double _frameDurationR = 0.0;
  double _tweenEasing = 0.0;
  double _tweenProgress = 0.0;
  double _valueScale = 1.0;

  @override
  void _onClear() {
    super._onClear();

    this._tweenType = TweenType.None;
    this._curveCount = 0;
    this._framePosition = 0.0;
    this._frameDurationR = 0.0;
    this._tweenEasing = 0.0;
    this._tweenProgress = 0.0;
    this._valueScale = 1.0;
  }

  @override
  void _onArriveAtFrame() {
    if (this._frameCount > 1 &&
        (this._frameIndex != this._frameCount - 1 ||
            this._animationState!.playTimes == 0 ||
            this._animationState!.currentPlayTimes < this._animationState!.playTimes - 1)) {
      this._tweenType = this._frameArray![this._frameOffset + BinaryOffset.FrameTweenType] as int;
      this._isTween = this._tweenType != TweenType.None;

      if (this._isTween) {
        if (this._tweenType == TweenType.Curve) {
          this._curveCount =
              this._frameArray![this._frameOffset + BinaryOffset.FrameTweenEasingOrCurveSampleCount] as int;
        } else if (this._tweenType != TweenType.None && this._tweenType != TweenType.Line) {
          this._tweenEasing =
              (this._frameArray![this._frameOffset + BinaryOffset.FrameTweenEasingOrCurveSampleCount] as num).toDouble() *
                  0.01;
        }
      } else {
        this.dirty = true;
      }

      this._framePosition = (this._frameArray![this._frameOffset] as num).toDouble() * this._frameRateR;

      if (this._frameIndex == this._frameCount - 1) {
        this._frameDurationR = 1.0 / (this._animationData!.duration - this._framePosition);
      } else {
        final int nextFrameOffset = this._animationData!.frameOffset +
            (this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineFrameOffset + this._frameIndex + 1]
                as int);
        final double frameDuration = (this._frameArray![nextFrameOffset] as num).toDouble() * this._frameRateR - this._framePosition;

        if (frameDuration > 0.0) {
          this._frameDurationR = 1.0 / frameDuration;
        } else {
          this._frameDurationR = 0.0;
        }
      }
    } else {
      this.dirty = true;
      this._isTween = false;
    }
  }

  @override
  void _onUpdateFrame() {
    if (this._isTween) {
      this.dirty = true;
      this._tweenProgress = (this.currentTime - this._framePosition) * this._frameDurationR;

      if (this._tweenType == TweenType.Curve) {
        this._tweenProgress = TweenTimelineState._getEasingCurveValue(
            this._tweenProgress, this._frameArray!, this._curveCount, this._frameOffset + BinaryOffset.FrameCurveSamples);
      } else if (this._tweenType != TweenType.Line) {
        this._tweenProgress = TweenTimelineState._getEasingValue(this._tweenType, this._tweenProgress, this._tweenEasing);
      }
    }
  }
}

/// @internal
abstract class SingleValueTimelineState extends TweenTimelineState {
  double _current = 0.0;
  double _difference = 0.0;
  double _result = 0.0;

  @override
  void _onClear() {
    super._onClear();

    this._current = 0.0;
    this._difference = 0.0;
    this._result = 0.0;
  }

  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._timelineData != null) {
      final double valueScale = this._valueScale;
      final List<num> valueArray = this._valueArray!;
      //
      final int valueOffset = this._valueOffset + this._frameValueOffset + this._frameIndex;

      if (this._isTween) {
        final int nextValueOffset = this._frameIndex == this._frameCount - 1
            ? this._valueOffset + this._frameValueOffset
            : valueOffset + 1;

        if (valueScale == 1.0) {
          this._current = valueArray[valueOffset].toDouble();
          this._difference = valueArray[nextValueOffset].toDouble() - this._current;
        } else {
          this._current = valueArray[valueOffset].toDouble() * valueScale;
          this._difference = valueArray[nextValueOffset].toDouble() * valueScale - this._current;
        }
      } else {
        this._result = valueArray[valueOffset].toDouble() * valueScale;
      }
    } else {
      this._result = 0.0;
    }
  }

  @override
  void _onUpdateFrame() {
    super._onUpdateFrame();

    if (this._isTween) {
      this._result = this._current + this._difference * this._tweenProgress;
    }
  }
}

/// @internal
abstract class DoubleValueTimelineState extends TweenTimelineState {
  double _currentA = 0.0;
  double _currentB = 0.0;
  double _differenceA = 0.0;
  double _differenceB = 0.0;
  double _resultA = 0.0;
  double _resultB = 0.0;

  @override
  void _onClear() {
    super._onClear();

    this._currentA = 0.0;
    this._currentB = 0.0;
    this._differenceA = 0.0;
    this._differenceB = 0.0;
    this._resultA = 0.0;
    this._resultB = 0.0;
  }

  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._timelineData != null) {
      final double valueScale = this._valueScale;
      final List<num> valueArray = this._valueArray!;
      //
      final int valueOffset = this._valueOffset + this._frameValueOffset + this._frameIndex * 2;

      if (this._isTween) {
        final int nextValueOffset = this._frameIndex == this._frameCount - 1
            ? this._valueOffset + this._frameValueOffset
            : valueOffset + 2;

        if (valueScale == 1.0) {
          this._currentA = valueArray[valueOffset].toDouble();
          this._currentB = valueArray[valueOffset + 1].toDouble();
          this._differenceA = valueArray[nextValueOffset].toDouble() - this._currentA;
          this._differenceB = valueArray[nextValueOffset + 1].toDouble() - this._currentB;
        } else {
          this._currentA = valueArray[valueOffset].toDouble() * valueScale;
          this._currentB = valueArray[valueOffset + 1].toDouble() * valueScale;
          this._differenceA = valueArray[nextValueOffset].toDouble() * valueScale - this._currentA;
          this._differenceB = valueArray[nextValueOffset + 1].toDouble() * valueScale - this._currentB;
        }
      } else {
        this._resultA = valueArray[valueOffset].toDouble() * valueScale;
        this._resultB = valueArray[valueOffset + 1].toDouble() * valueScale;
      }
    } else {
      this._resultA = 0.0;
      this._resultB = 0.0;
    }
  }

  @override
  void _onUpdateFrame() {
    super._onUpdateFrame();

    if (this._isTween) {
      this._resultA = this._currentA + this._differenceA * this._tweenProgress;
      this._resultB = this._currentB + this._differenceB * this._tweenProgress;
    }
  }
}

/// @internal
abstract class MutilpleValueTimelineState extends TweenTimelineState {
  int _valueCount = 0;
  final List<double> _rd = <double>[];

  @override
  void _onClear() {
    super._onClear();

    this._valueCount = 0;
    this._rd.length = 0;
  }

  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    final int valueCount = this._valueCount;
    final List<double> rd = this._rd;

    if (this._timelineData != null) {
      final double valueScale = this._valueScale;
      final List<num> valueArray = this._valueArray!;
      //
      final int valueOffset = this._valueOffset + this._frameValueOffset + this._frameIndex * valueCount;

      if (this._isTween) {
        final int nextValueOffset = this._frameIndex == this._frameCount - 1
            ? this._valueOffset + this._frameValueOffset
            : valueOffset + valueCount;

        if (valueScale == 1.0) {
          for (var i = 0; i < valueCount; ++i) {
            rd[valueCount + i] = valueArray[nextValueOffset + i].toDouble() - valueArray[valueOffset + i].toDouble();
          }
        } else {
          for (var i = 0; i < valueCount; ++i) {
            rd[valueCount + i] =
                (valueArray[nextValueOffset + i].toDouble() - valueArray[valueOffset + i].toDouble()) * valueScale;
          }
        }
      } else if (valueScale == 1.0) {
        for (var i = 0; i < valueCount; ++i) {
          rd[i] = valueArray[valueOffset + i].toDouble();
        }
      } else {
        for (var i = 0; i < valueCount; ++i) {
          rd[i] = valueArray[valueOffset + i].toDouble() * valueScale;
        }
      }
    } else {
      for (var i = 0; i < valueCount; ++i) {
        rd[i] = 0.0;
      }
    }
  }

  @override
  void _onUpdateFrame() {
    super._onUpdateFrame();

    if (this._isTween) {
      final int valueCount = this._valueCount;
      final double valueScale = this._valueScale;
      final double tweenProgress = this._tweenProgress;
      final List<num> valueArray = this._valueArray!;
      final List<double> rd = this._rd;
      //
      final int valueOffset = this._valueOffset + this._frameValueOffset + this._frameIndex * valueCount;

      if (valueScale == 1.0) {
        for (var i = 0; i < valueCount; ++i) {
          rd[i] = valueArray[valueOffset + i].toDouble() + rd[valueCount + i] * tweenProgress;
        }
      } else {
        for (var i = 0; i < valueCount; ++i) {
          rd[i] = valueArray[valueOffset + i].toDouble() * valueScale + rd[valueCount + i] * tweenProgress;
        }
      }
    }
  }
}
