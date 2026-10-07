part of '../../dragonbones.dart';

/// @internal
///
/// Faithful port of `.ref/dragonBones-ts/animation/TimelineState.ts`.
/// The playhead (`_setCurrentTime`) path is transcribed verbatim.

/// @internal
class ActionTimelineState extends TimelineState {
  /// - Fires every action the playhead just crossed.
  ///
  /// Three kinds arrive here, and they are dispatched differently on purpose:
  ///
  /// - `Play` (a `gotoAndPlay` from the editor) is *not* dispatched to
  ///   listeners. It is queued on the armature ([Armature._bufferAction]) and
  ///   runs after the pose is settled, because it starts another animation.
  /// - `Frame` becomes a [EventObject.FRAME_EVENT] — but only when a listener
  ///   exists, so an app that listens to nothing pays nothing.
  /// - `Sound` becomes a [EventObject.SOUND_EVENT], and is buffered whether or
  ///   not anyone listens: sound is global, and the app-level dispatcher
  ///   (`DragonBones.eventManager`) is not known here.
  void _onCrossFrame(int frameIndex) {
    final eventDispatcher = this._armature!.eventDispatcher;

    if (this._animationState!.actionEnabled) {
      final int frameOffset = this._animationData!.frameOffset +
          (this._timelineArray![
              (this._timelineData as TimelineData).offset + BinaryOffset.TimelineFrameOffset + frameIndex] as int);
      final int actionCount = this._frameArray![frameOffset + 1] as int;
      // May be the animation data does not belong to this armature data.
      final actions = this._animationData!.parent!.actions;

      for (var i = 0; i < actionCount; ++i) {
        final int actionIndex = this._frameArray![frameOffset + 2 + i] as int;
        final action = actions[actionIndex];

        if (action.type == ActionType.Play) {
          final eventObject = EventObject();
          // `frameArray[frameOffset] / frameRate` rather than
          // `* frameRateR`: upstream comments that the latter loses precision.
          eventObject.time = (this._frameArray![frameOffset] as num).toDouble() / this._frameRate;
          eventObject.animationState = this._animationState;
          EventObject.actionDataToInstance(action, eventObject, this._armature!);
          this._armature!._bufferAction(eventObject, true);
        } else {
          final eventType = action.type == ActionType.Frame ? EventObject.FRAME_EVENT : EventObject.SOUND_EVENT;

          if (action.type == ActionType.Sound || eventDispatcher.hasDBEventListener(eventType)) {
            final eventObject = EventObject();
            eventObject.time = (this._frameArray![frameOffset] as num).toDouble() / this._frameRate;
            eventObject.animationState = this._animationState;
            EventObject.actionDataToInstance(action, eventObject, this._armature!);
            this._armature!._dragonBones!.bufferEvent(eventObject);
          }
        }
      }
    }
  }

  @override
  void _onArriveAtFrame() {}

  @override
  void _onUpdateFrame() {}

  @override
  void update(double passedTime) {
    final int prevState = this.playState;
    final int prevPlayTimes = this.currentPlayTimes;
    final double prevTime = this.currentTime;

    if (this._setCurrentTime(passedTime)) {
      final bool eventActive = this._animationState!._parent == null && this._animationState!.actionEnabled;
      final eventDispatcher = this._armature!.eventDispatcher;
      if (prevState < 0) {
        if (this.playState != prevState) {
          if (this._animationState!.displayControl && this._animationState!.resetToPose) {
            // Reset zorder to pose.
            this._armature!._sortZOrder(null, 0);
          }

          if (eventActive && eventDispatcher.hasDBEventListener(EventObject.START)) {
            final eventObject = EventObject();
            eventObject.type = EventObject.START;
            eventObject.armature = this._armature;
            eventObject.animationState = this._animationState;
            this._armature!._dragonBones!.bufferEvent(eventObject);
          }
        } else {
          return;
        }
      }

      final bool isReverse = this._animationState!.timeScale < 0.0;
      EventObject? loopCompleteEvent;
      EventObject? completeEvent;

      if (eventActive && this.currentPlayTimes != prevPlayTimes) {
        if (eventDispatcher.hasDBEventListener(EventObject.LOOP_COMPLETE)) {
          loopCompleteEvent = EventObject();
          loopCompleteEvent.type = EventObject.LOOP_COMPLETE;
          loopCompleteEvent.armature = this._armature;
          loopCompleteEvent.animationState = this._animationState;
        }

        if (this.playState > 0) {
          if (eventDispatcher.hasDBEventListener(EventObject.COMPLETE)) {
            completeEvent = EventObject();
            completeEvent.type = EventObject.COMPLETE;
            completeEvent.armature = this._armature;
            completeEvent.animationState = this._animationState;
          }
        }
      }

      if (this._frameCount > 1) {
        final timelineData = this._timelineData!;
        final int timelineFrameIndex = (this.currentTime * this._frameRate).floor(); // uint
        final int frameIndex = this._frameIndices![timelineData.frameIndicesOffset + timelineFrameIndex];

        if (this._frameIndex != frameIndex) {
          // Arrive at frame.
          int crossedFrameIndex = this._frameIndex;
          this._frameIndex = frameIndex;

          if (this._timelineArray != null) {
            this._frameOffset = this._animationData!.frameOffset +
                (this._timelineArray![timelineData.offset + BinaryOffset.TimelineFrameOffset + this._frameIndex]
                    as int);

            if (isReverse) {
              if (crossedFrameIndex < 0) {
                final int prevFrameIndex = (prevTime * this._frameRate).floor();
                crossedFrameIndex = this._frameIndices![timelineData.frameIndicesOffset + prevFrameIndex];

                if (this.currentPlayTimes == prevPlayTimes) {
                  // Start.
                  if (crossedFrameIndex == frameIndex) {
                    // Uncrossed.
                    crossedFrameIndex = -1;
                  }
                }
              }

              while (crossedFrameIndex >= 0) {
                final int frameOffset = this._animationData!.frameOffset +
                    (this._timelineArray![timelineData.offset + BinaryOffset.TimelineFrameOffset + crossedFrameIndex]
                        as int);
                final double framePosition = (this._frameArray![frameOffset] as num).toDouble() / this._frameRate;

                if (this._position <= framePosition && framePosition <= this._position + this._duration) {
                  this._onCrossFrame(crossedFrameIndex);
                }

                if (loopCompleteEvent != null && crossedFrameIndex == 0) {
                  // Add loop complete event after first frame.
                  this._armature!._dragonBones!.bufferEvent(loopCompleteEvent);
                  loopCompleteEvent = null;
                }

                if (crossedFrameIndex > 0) {
                  crossedFrameIndex--;
                } else {
                  crossedFrameIndex = this._frameCount - 1;
                }

                if (crossedFrameIndex == frameIndex) {
                  break;
                }
              }
            } else {
              if (crossedFrameIndex < 0) {
                final int prevFrameIndex = (prevTime * this._frameRate).floor();
                crossedFrameIndex = this._frameIndices![timelineData.frameIndicesOffset + prevFrameIndex];
                final int frameOffset = this._animationData!.frameOffset +
                    (this._timelineArray![timelineData.offset + BinaryOffset.TimelineFrameOffset + crossedFrameIndex]
                        as int);
                final double framePosition = (this._frameArray![frameOffset] as num).toDouble() / this._frameRate;

                if (this.currentPlayTimes == prevPlayTimes) {
                  // Start.
                  if (prevTime <= framePosition) {
                    // Crossed.
                    if (crossedFrameIndex > 0) {
                      crossedFrameIndex--;
                    } else {
                      crossedFrameIndex = this._frameCount - 1;
                    }
                  } else if (crossedFrameIndex == frameIndex) {
                    // Uncrossed.
                    crossedFrameIndex = -1;
                  }
                }
              }

              while (crossedFrameIndex >= 0) {
                if (crossedFrameIndex < this._frameCount - 1) {
                  crossedFrameIndex++;
                } else {
                  crossedFrameIndex = 0;
                }

                final int frameOffset = this._animationData!.frameOffset +
                    (this._timelineArray![timelineData.offset + BinaryOffset.TimelineFrameOffset + crossedFrameIndex]
                        as int);
                final double framePosition = (this._frameArray![frameOffset] as num).toDouble() / this._frameRate;

                if (this._position <= framePosition && framePosition <= this._position + this._duration) {
                  this._onCrossFrame(crossedFrameIndex);
                }

                if (loopCompleteEvent != null && crossedFrameIndex == 0) {
                  // Add loop complete event before first frame.
                  this._armature!._dragonBones!.bufferEvent(loopCompleteEvent);
                  loopCompleteEvent = null;
                }

                if (crossedFrameIndex == frameIndex) {
                  break;
                }
              }
            }
          }
        }
      } else if (this._frameIndex < 0) {
        this._frameIndex = 0;
        if (this._timelineData != null) {
          this._frameOffset = this._animationData!.frameOffset +
              (this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineFrameOffset] as int);
          // Arrive at frame.
          final double framePosition = (this._frameArray![this._frameOffset] as num).toDouble() / this._frameRate;

          if (this.currentPlayTimes == prevPlayTimes) {
            // Start.
            if (prevTime <= framePosition) {
              this._onCrossFrame(this._frameIndex);
            }
          } else if (this._position <= framePosition) {
            // Loop complete.
            if (!isReverse && loopCompleteEvent != null) {
              // Add loop complete event before first frame.
              this._armature!._dragonBones!.bufferEvent(loopCompleteEvent);
              loopCompleteEvent = null;
            }

            this._onCrossFrame(this._frameIndex);
          }
        }
      }

      // Whatever the playhead did not cross — or could not cross, because the
      // timeline has a single frame — is dispatched at the end of the update.
      if (loopCompleteEvent != null) {
        this._armature!._dragonBones!.bufferEvent(loopCompleteEvent);
      }

      if (completeEvent != null) {
        this._armature!._dragonBones!.bufferEvent(completeEvent);
      }
    }
  }

  void setCurrentTime(double value) {
    this._setCurrentTime(value);
    this._frameIndex = -1;
  }
}

/// @internal
class ZOrderTimelineState extends TimelineState {
  @override
  void _onArriveAtFrame() {
    if (this.playState >= 0) {
      final int count = this._frameArray![this._frameOffset + 1] as int;
      if (count > 0) {
        final values = <int>[];
        for (var i = 0; i < count; ++i) {
          values.add(this._frameArray![this._frameOffset + 2 + i] as int);
        }
        this._armature!._sortZOrder(values, 0);
      } else {
        this._armature!._sortZOrder(null, 0);
      }
    }
  }

  @override
  void _onUpdateFrame() {}
}

/// @internal
class BoneAllTimelineState extends MutilpleValueTimelineState {
  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._isTween && this._frameIndex == this._frameCount - 1) {
      this._rd[2] = Transform.normalizeRadian(this._rd[2]);
      this._rd[3] = Transform.normalizeRadian(this._rd[3]);
    }

    if (this._timelineData == null) {
      // Pose.
      this._rd[4] = 1.0;
      this._rd[5] = 1.0;
    }
  }

  @override
  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    super.init(armature, animationState, timelineData);

    this._valueOffset = this._animationData!.frameFloatOffset;
    this._valueCount = 6;
    // NOTE: upstream writes `this._rd.length = this._valueCount * 2` (JS fills
    // holes with undefined). Dart cannot grow a List<double> that way.
    this._rd.clear();
    for (var i = 0, l = this._valueCount * 2; i < l; ++i) {
      this._rd.add(0.0);
    }
    this._valueArray = this._animationData!.parent!.parent!.frameFloatArray;
  }

  @override
  void fadeOut() {
    this.dirty = false;
    this._rd[2] = Transform.normalizeRadian(this._rd[2]);
    this._rd[3] = Transform.normalizeRadian(this._rd[3]);
  }

  @override
  void blend(bool isDirty) {
    final double valueScale = this._armature!.armatureData.scale;
    final List<double> rd = this._rd;
    //
    final BlendState blendState = this.target as BlendState;
    final Bone bone = blendState.target as Bone;
    final double blendWeight = blendState.blendWeight;
    final Transform result = bone.animationPose;

    if (blendState.dirty > 1) {
      result.x += rd[0] * blendWeight * valueScale;
      result.y += rd[1] * blendWeight * valueScale;
      result.rotation += rd[2] * blendWeight;
      result.skew += rd[3] * blendWeight;
      result.scaleX += (rd[4] - 1.0) * blendWeight;
      result.scaleY += (rd[5] - 1.0) * blendWeight;
    } else {
      result.x = rd[0] * blendWeight * valueScale;
      result.y = rd[1] * blendWeight * valueScale;
      result.rotation = rd[2] * blendWeight;
      result.skew = rd[3] * blendWeight;
      result.scaleX = (rd[4] - 1.0) * blendWeight + 1.0;
      result.scaleY = (rd[5] - 1.0) * blendWeight + 1.0;
    }

    if (isDirty || this.dirty) {
      this.dirty = false;
      bone._transformDirty = true;
    }
  }
}

/// @internal
class BoneTranslateTimelineState extends DoubleValueTimelineState {
  @override
  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    super.init(armature, animationState, timelineData);

    this._valueOffset = this._animationData!.frameFloatOffset;
    this._valueScale = this._armature!.armatureData.scale;
    this._valueArray = this._animationData!.parent!.parent!.frameFloatArray;
  }

  @override
  void blend(bool isDirty) {
    final BlendState blendState = this.target as BlendState;
    final Bone bone = blendState.target as Bone;
    final double blendWeight = blendState.blendWeight;
    final Transform result = bone.animationPose;

    if (blendState.dirty > 1) {
      result.x += this._resultA * blendWeight;
      result.y += this._resultB * blendWeight;
    } else if (blendWeight != 1.0) {
      result.x = this._resultA * blendWeight;
      result.y = this._resultB * blendWeight;
    } else {
      result.x = this._resultA;
      result.y = this._resultB;
    }

    if (isDirty || this.dirty) {
      this.dirty = false;
      bone._transformDirty = true;
    }
  }
}

/// @internal
class BoneRotateTimelineState extends DoubleValueTimelineState {
  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._isTween && this._frameIndex == this._frameCount - 1) {
      this._differenceA = Transform.normalizeRadian(this._differenceA);
      this._differenceB = Transform.normalizeRadian(this._differenceB);
    }
  }

  @override
  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    super.init(armature, animationState, timelineData);

    this._valueOffset = this._animationData!.frameFloatOffset;
    this._valueArray = this._animationData!.parent!.parent!.frameFloatArray;
  }

  @override
  void fadeOut() {
    this.dirty = false;
    this._resultA = Transform.normalizeRadian(this._resultA);
    this._resultB = Transform.normalizeRadian(this._resultB);
  }

  @override
  void blend(bool isDirty) {
    final BlendState blendState = this.target as BlendState;
    final Bone bone = blendState.target as Bone;
    final double blendWeight = blendState.blendWeight;
    final Transform result = bone.animationPose;

    if (blendState.dirty > 1) {
      result.rotation += this._resultA * blendWeight;
      result.skew += this._resultB * blendWeight;
    } else if (blendWeight != 1.0) {
      result.rotation = this._resultA * blendWeight;
      result.skew = this._resultB * blendWeight;
    } else {
      result.rotation = this._resultA;
      result.skew = this._resultB;
    }

    if (isDirty || this.dirty) {
      this.dirty = false;
      bone._transformDirty = true;
    }
  }
}

/// @internal
class BoneScaleTimelineState extends DoubleValueTimelineState {
  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._timelineData == null) {
      // Pose.
      this._resultA = 1.0;
      this._resultB = 1.0;
    }
  }

  @override
  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    super.init(armature, animationState, timelineData);

    this._valueOffset = this._animationData!.frameFloatOffset;
    this._valueArray = this._animationData!.parent!.parent!.frameFloatArray;
  }

  @override
  void blend(bool isDirty) {
    final BlendState blendState = this.target as BlendState;
    final Bone bone = blendState.target as Bone;
    final double blendWeight = blendState.blendWeight;
    final Transform result = bone.animationPose;

    if (blendState.dirty > 1) {
      result.scaleX += (this._resultA - 1.0) * blendWeight;
      result.scaleY += (this._resultB - 1.0) * blendWeight;
    } else if (blendWeight != 1.0) {
      result.scaleX = (this._resultA - 1.0) * blendWeight + 1.0;
      result.scaleY = (this._resultB - 1.0) * blendWeight + 1.0;
    } else {
      result.scaleX = this._resultA;
      result.scaleY = this._resultB;
    }

    if (isDirty || this.dirty) {
      this.dirty = false;
      bone._transformDirty = true;
    }
  }
}

/// @internal
class AlphaTimelineState extends SingleValueTimelineState {
  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._timelineData == null) {
      // Pose.
      this._result = 1.0;
    }
  }

  @override
  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    super.init(armature, animationState, timelineData);

    this._valueOffset = this._animationData!.frameIntOffset;
    this._valueScale = 0.01;
    this._valueArray = this._animationData!.parent!.parent!.frameIntArray;
  }

  @override
  void blend(bool isDirty) {
    final BlendState blendState = this.target as BlendState;
    final TransformObject alphaTarget = blendState.target as TransformObject;
    final double blendWeight = blendState.blendWeight;

    if (blendState.dirty > 1) {
      alphaTarget._alpha += this._result * blendWeight;
      if (alphaTarget._alpha > 1.0) {
        alphaTarget._alpha = 1.0;
      }
    } else {
      alphaTarget._alpha = this._result * blendWeight;
    }

    if (isDirty || this.dirty) {
      this.dirty = false;
      this._armature!._alphaDirty = true;
    }
  }
}

/// @internal
class SlotDisplayTimelineState extends TimelineState {
  @override
  void _onArriveAtFrame() {
    if (this.playState >= 0) {
      final Slot slot = this.target as Slot;
      final int displayIndex =
          this._timelineData != null ? this._frameArray![this._frameOffset + 1] as int : slot._slotData!.displayIndex;

      if (slot.displayIndex != displayIndex) {
        slot._setDisplayIndex(displayIndex, true);
      }
    }
  }

  @override
  void _onUpdateFrame() {}
}

/// @internal
class SlotColorTimelineState extends TweenTimelineState {
  final List<double> _current = <double>[0, 0, 0, 0, 0, 0, 0, 0];
  final List<double> _difference = <double>[0, 0, 0, 0, 0, 0, 0, 0];
  final List<double> _result = <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  @override
  void _onArriveAtFrame() {
    super._onArriveAtFrame();

    if (this._timelineData != null) {
      final dragonBonesData = this._animationData!.parent!.parent!;
      final colorArray = dragonBonesData.colorArray!;
      final frameIntArray = dragonBonesData.frameIntArray!;
      final int valueOffset = this._animationData!.frameIntOffset + this._frameValueOffset + this._frameIndex;
      int colorOffset = frameIntArray[valueOffset];

      if (colorOffset < 0) {
        colorOffset += 65536; // Fixed out of bounds bug.
      }

      if (this._isTween) {
        this._current[0] = colorArray[colorOffset++].toDouble();
        this._current[1] = colorArray[colorOffset++].toDouble();
        this._current[2] = colorArray[colorOffset++].toDouble();
        this._current[3] = colorArray[colorOffset++].toDouble();
        this._current[4] = colorArray[colorOffset++].toDouble();
        this._current[5] = colorArray[colorOffset++].toDouble();
        this._current[6] = colorArray[colorOffset++].toDouble();
        this._current[7] = colorArray[colorOffset++].toDouble();

        if (this._frameIndex == this._frameCount - 1) {
          colorOffset = frameIntArray[this._animationData!.frameIntOffset + this._frameValueOffset];
        } else {
          colorOffset = frameIntArray[valueOffset + 1];
        }

        if (colorOffset < 0) {
          colorOffset += 65536; // Fixed out of bounds bug.
        }

        this._difference[0] = colorArray[colorOffset++].toDouble() - this._current[0];
        this._difference[1] = colorArray[colorOffset++].toDouble() - this._current[1];
        this._difference[2] = colorArray[colorOffset++].toDouble() - this._current[2];
        this._difference[3] = colorArray[colorOffset++].toDouble() - this._current[3];
        this._difference[4] = colorArray[colorOffset++].toDouble() - this._current[4];
        this._difference[5] = colorArray[colorOffset++].toDouble() - this._current[5];
        this._difference[6] = colorArray[colorOffset++].toDouble() - this._current[6];
        this._difference[7] = colorArray[colorOffset++].toDouble() - this._current[7];
      } else {
        this._result[0] = colorArray[colorOffset++].toDouble() * 0.01;
        this._result[1] = colorArray[colorOffset++].toDouble() * 0.01;
        this._result[2] = colorArray[colorOffset++].toDouble() * 0.01;
        this._result[3] = colorArray[colorOffset++].toDouble() * 0.01;
        this._result[4] = colorArray[colorOffset++].toDouble();
        this._result[5] = colorArray[colorOffset++].toDouble();
        this._result[6] = colorArray[colorOffset++].toDouble();
        this._result[7] = colorArray[colorOffset++].toDouble();
      }
    } else {
      // Pose.
      final Slot slot = this.target as Slot;
      final ColorTransform color = slot.slotData.color;
      this._result[0] = color.alphaMultiplier;
      this._result[1] = color.redMultiplier;
      this._result[2] = color.greenMultiplier;
      this._result[3] = color.blueMultiplier;
      this._result[4] = color.alphaOffset;
      this._result[5] = color.redOffset;
      this._result[6] = color.greenOffset;
      this._result[7] = color.blueOffset;
    }
  }

  @override
  void _onUpdateFrame() {
    super._onUpdateFrame();

    if (this._isTween) {
      this._result[0] = (this._current[0] + this._difference[0] * this._tweenProgress) * 0.01;
      this._result[1] = (this._current[1] + this._difference[1] * this._tweenProgress) * 0.01;
      this._result[2] = (this._current[2] + this._difference[2] * this._tweenProgress) * 0.01;
      this._result[3] = (this._current[3] + this._difference[3] * this._tweenProgress) * 0.01;
      this._result[4] = this._current[4] + this._difference[4] * this._tweenProgress;
      this._result[5] = this._current[5] + this._difference[5] * this._tweenProgress;
      this._result[6] = this._current[6] + this._difference[6] * this._tweenProgress;
      this._result[7] = this._current[7] + this._difference[7] * this._tweenProgress;
    }
  }

  @override
  void fadeOut() {
    this._isTween = false;
  }

  @override
  void update(double passedTime) {
    super.update(passedTime);
    // Fade animation.
    if (this._isTween || this.dirty) {
      final Slot slot = this.target as Slot;
      final ColorTransform result = slot._colorTransform;

      if (this._animationState!._fadeState != 0 || this._animationState!._subFadeState != 0) {
        if (result.alphaMultiplier != this._result[0] ||
            result.redMultiplier != this._result[1] ||
            result.greenMultiplier != this._result[2] ||
            result.blueMultiplier != this._result[3] ||
            result.alphaOffset != this._result[4] ||
            result.redOffset != this._result[5] ||
            result.greenOffset != this._result[6] ||
            result.blueOffset != this._result[7]) {
          final double fadeProgress = math.pow(this._animationState!._fadeProgress, 4).toDouble();
          result.alphaMultiplier += (this._result[0] - result.alphaMultiplier) * fadeProgress;
          result.redMultiplier += (this._result[1] - result.redMultiplier) * fadeProgress;
          result.greenMultiplier += (this._result[2] - result.greenMultiplier) * fadeProgress;
          result.blueMultiplier += (this._result[3] - result.blueMultiplier) * fadeProgress;
          result.alphaOffset += (this._result[4] - result.alphaOffset) * fadeProgress;
          result.redOffset += (this._result[5] - result.redOffset) * fadeProgress;
          result.greenOffset += (this._result[6] - result.greenOffset) * fadeProgress;
          result.blueOffset += (this._result[7] - result.blueOffset) * fadeProgress;
          slot._colorDirty = true;
        }
      } else if (this.dirty) {
        this.dirty = false;

        if (result.alphaMultiplier != this._result[0] ||
            result.redMultiplier != this._result[1] ||
            result.greenMultiplier != this._result[2] ||
            result.blueMultiplier != this._result[3] ||
            result.alphaOffset != this._result[4] ||
            result.redOffset != this._result[5] ||
            result.greenOffset != this._result[6] ||
            result.blueOffset != this._result[7]) {
          result.alphaMultiplier = this._result[0];
          result.redMultiplier = this._result[1];
          result.greenMultiplier = this._result[2];
          result.blueMultiplier = this._result[3];
          result.alphaOffset = this._result[4];
          result.redOffset = this._result[5];
          result.greenOffset = this._result[6];
          result.blueOffset = this._result[7];
          slot._colorDirty = true;
        }
      }
    }
  }
}

/// @internal
///
/// Animated FFD: writes per-vertex offsets into the display frame's
/// `deformVertices`, which the mesh deformer then adds on top of the rest
/// positions.
///
/// Ported from `.ref/dragonBones-ts/animation/TimelineState.ts`
/// (`DeformTimelineState`). Note that this is a *blend* timeline: its target is
/// a [BlendState], not the slot, because deform offsets accumulate across
/// animation layers.
class DeformTimelineState extends MutilpleValueTimelineState {
  DisplayFrame? displayFrame;

  int _deformCount = 0;
  int _deformOffset = 0;
  int _sameValueOffset = 0;

  @override
  void _onClear() {
    super._onClear();

    this.displayFrame = null;
    this._deformCount = 0;
    this._deformOffset = 0;
    this._sameValueOffset = 0;
  }

  @override
  void init(Armature armature, AnimationState animationState, TimelineData? timelineData) {
    super.init(armature, animationState, timelineData);

    if (this._timelineData != null) {
      final frameIntOffset = this._animationData!.frameIntOffset +
          this._timelineArray![this._timelineData!.offset + BinaryOffset.TimelineFrameValueCount] as int;
      final dragonBonesData = this._animationData!.parent!.parent!;
      final frameIntArray = dragonBonesData.frameIntArray!;

      this._valueOffset = this._animationData!.frameFloatOffset;
      this._valueCount = frameIntArray[frameIntOffset + BinaryOffset.DeformValueCount];
      this._deformCount = frameIntArray[frameIntOffset + BinaryOffset.DeformCount];
      this._deformOffset = frameIntArray[frameIntOffset + BinaryOffset.DeformValueOffset];
      this._sameValueOffset = frameIntArray[frameIntOffset + BinaryOffset.DeformFloatOffset];

      if (this._sameValueOffset < 0) {
        this._sameValueOffset += 65536; // Fixed out of bounds bug.
      }

      this._sameValueOffset += this._animationData!.frameFloatOffset;
      this._valueScale = this._armature!.armatureData.scale;
      this._valueArray = dragonBonesData.frameFloatArray;

      // NOTE: upstream does `this._rd.length = this._valueCount * 2`, which a
      // JS array tolerates. Dart needs the slots to exist before writing.
      this._rd.clear();
      for (var i = 0, l = this._valueCount * 2; i < l; ++i) {
        this._rd.add(0.0);
      }
    } else {
      this._deformCount = this.displayFrame!.deformVertices.length;
    }
  }

  @override
  void blend(bool isDirty) {
    final BlendState blendState = this.target as BlendState;
    final Slot slot = blendState.target as Slot;
    final double blendWeight = blendState.blendWeight;
    final List<double> result = this.displayFrame!.deformVertices;
    final List<num>? valueArray = this._valueArray;

    if (valueArray != null) {
      final int valueCount = this._valueCount;
      final int deformOffset = this._deformOffset;
      final int sameValueOffset = this._sameValueOffset;
      final List<double> rd = this._rd;

      for (var i = 0; i < this._deformCount; ++i) {
        double value;

        if (i < deformOffset) {
          value = valueArray[sameValueOffset + i].toDouble();
        } else if (i < deformOffset + valueCount) {
          value = rd[i - deformOffset];
        } else {
          value = valueArray[sameValueOffset + i - valueCount].toDouble();
        }

        if (blendState.dirty > 1) {
          result[i] += value * blendWeight;
        } else {
          result[i] = value * blendWeight;
        }
      }
    } else if (blendState.dirty == 1) {
      for (var i = 0; i < this._deformCount; ++i) {
        result[i] = 0.0;
      }
    }

    if (isDirty || this.dirty) {
      this.dirty = false;

      if (identical(slot.geometryData, this.displayFrame!.getGeometryData())) {
        slot._verticesDirty = true;
      }
    }
  }
}
