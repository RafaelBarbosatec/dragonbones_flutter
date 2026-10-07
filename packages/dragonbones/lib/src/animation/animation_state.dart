part of '../../dragonbones.dart';

/// - The animation state is generated when the animation data is played.
///
/// Faithful port of `.ref/dragonBones-ts/animation/AnimationState.ts`.
class AnimationState extends BaseObject {
  /// @private
  bool actionEnabled = false;

  /// @private
  bool additive = false;

  /// - Whether the animation state has control over the display object properties of the slots.
  bool displayControl = false;

  /// - Whether to reset the objects without animation to the armature pose.
  bool resetToPose = false;

  /// @private
  int blendType = AnimationBlendType.None;

  /// - The play times. [0: Loop play, [1~N]: Play N times]
  int playTimes = 1;

  /// - The blend layer.
  int layer = 0;

  /// - The play speed.
  double timeScale = 1.0;

  /// @private
  double parameterX = 0.0;

  /// @private
  double parameterY = 0.0;

  /// @private
  double positionX = 0.0;

  /// @private
  double positionY = 0.0;

  /// - The auto fade out time when the animation state play completed.
  double autoFadeOutTime = 0.0;

  /// @private
  double fadeTotalTime = 0.0;

  /// - The name of the animation state.
  String name = '';

  /// - The blend group name of the animation state.
  String group = '';

  int _timelineDirty = 2;

  /// @internal
  int _playheadState = 0;

  /// @internal
  int _fadeState = -1;

  /// @internal
  int _subFadeState = -1;

  /// @internal
  double _position = 0.0;

  /// @internal
  double _duration = 0.0;

  double _weight = 1.0;
  double _fadeTime = 0.0;
  double _time = 0.0;

  /// @internal
  double _fadeProgress = 0.0;

  /// @internal
  double _weightResult = 0.0;

  final List<String> _boneMask = <String>[];
  final List<TimelineState> _boneTimelines = <TimelineState>[];
  final List<TimelineState> _boneBlendTimelines = <TimelineState>[];
  final List<TimelineState> _slotTimelines = <TimelineState>[];
  final List<TimelineState> _slotBlendTimelines = <TimelineState>[];
  final List<TimelineState> _constraintTimelines = <TimelineState>[];
  final List<TimelineState> _animationTimelines = <TimelineState>[];
  final List<TimelineState> _poseTimelines = <TimelineState>[];

  AnimationData? _animationData;
  Armature? _armature;

  /// @internal
  ActionTimelineState? _actionTimeline;

  ZOrderTimelineState? _zOrderTimeline;

  AnimationState? _activeChildA;
  AnimationState? _activeChildB;

  /// @internal
  AnimationState? _parent;

  @override
  void _onClear() {
    for (final timeline in this._boneTimelines) {
      timeline.returnToPool();
    }

    for (final timeline in this._boneBlendTimelines) {
      timeline.returnToPool();
    }

    for (final timeline in this._slotTimelines) {
      timeline.returnToPool();
    }

    for (final timeline in this._slotBlendTimelines) {
      timeline.returnToPool();
    }

    for (final timeline in this._constraintTimelines) {
      timeline.returnToPool();
    }

    for (final timeline in this._animationTimelines) {
      final animationState = timeline.target as AnimationState;
      if (animationState._parent == this) {
        animationState._fadeState = 1;
        animationState._subFadeState = 1;
        animationState._parent = null;
      }

      timeline.returnToPool();
    }

    if (this._actionTimeline != null) {
      this._actionTimeline!.returnToPool();
    }

    if (this._zOrderTimeline != null) {
      this._zOrderTimeline!.returnToPool();
    }

    this.actionEnabled = false;
    this.additive = false;
    this.displayControl = false;
    this.resetToPose = false;
    this.blendType = AnimationBlendType.None;
    this.playTimes = 1;
    this.layer = 0;
    this.timeScale = 1.0;
    this._weight = 1.0;
    this.parameterX = 0.0;
    this.parameterY = 0.0;
    this.positionX = 0.0;
    this.positionY = 0.0;
    this.autoFadeOutTime = 0.0;
    this.fadeTotalTime = 0.0;
    this.name = '';
    this.group = '';

    this._timelineDirty = 2;
    this._playheadState = 0;
    this._fadeState = -1;
    this._subFadeState = -1;
    this._position = 0.0;
    this._duration = 0.0;
    this._fadeTime = 0.0;
    this._time = 0.0;
    this._fadeProgress = 0.0;
    this._weightResult = 0.0;
    this._boneMask.length = 0;
    this._boneTimelines.length = 0;
    this._boneBlendTimelines.length = 0;
    this._slotTimelines.length = 0;
    this._slotBlendTimelines.length = 0;
    this._constraintTimelines.length = 0;
    this._animationTimelines.length = 0;
    this._poseTimelines.length = 0;
    this._animationData = null;
    this._armature = null;
    this._actionTimeline = null;
    this._zOrderTimeline = null;
    this._activeChildA = null;
    this._activeChildB = null;
    this._parent = null;
  }

  void _updateTimelines() {
    // Milestone 2: IK/path constraint timelines are not ported. The fixtures
    // used by milestone 1 declare no constraints, so this is a no-op.
  }

  void _updateBoneAndSlotTimelines() {
    {
      // Update bone and surface timelines.
      final boneTimelines = <String, List<TimelineState>>{};
      // Create bone timelines map.
      for (final timeline in this._boneTimelines) {
        final timelineName = ((timeline.target as BlendState).target as Bone).name;
        boneTimelines.putIfAbsent(timelineName, () => <TimelineState>[]).add(timeline);
      }

      for (final timeline in this._boneBlendTimelines) {
        final timelineName = ((timeline.target as BlendState).target as Bone).name;
        boneTimelines.putIfAbsent(timelineName, () => <TimelineState>[]).add(timeline);
      }

      for (final bone in this._armature!.getBones()) {
        final timelineName = bone.name;
        if (!this.containsBoneMask(timelineName)) {
          continue;
        }

        if (boneTimelines.containsKey(timelineName)) {
          // Remove bone timeline from map.
          boneTimelines.remove(timelineName);
        } else {
          // Create new bone timeline.
          final timelineDatas = this._animationData!.getBoneTimelines(timelineName);
          final blendState = this._armature!.animation.getBlendState(BlendState.BONE_TRANSFORM, bone.name, bone);

          if (timelineDatas != null) {
            for (final timelineData in timelineDatas) {
              switch (timelineData.type) {
                case TimelineType.BoneAll:
                  {
                    final timeline = BoneAllTimelineState();
                    timeline.target = blendState;
                    timeline.init(this._armature!, this, timelineData);
                    this._boneTimelines.add(timeline);
                    break;
                  }

                case TimelineType.BoneTranslate:
                  {
                    final timeline = BoneTranslateTimelineState();
                    timeline.target = blendState;
                    timeline.init(this._armature!, this, timelineData);
                    this._boneTimelines.add(timeline);
                    break;
                  }

                case TimelineType.BoneRotate:
                  {
                    final timeline = BoneRotateTimelineState();
                    timeline.target = blendState;
                    timeline.init(this._armature!, this, timelineData);
                    this._boneTimelines.add(timeline);
                    break;
                  }

                case TimelineType.BoneScale:
                  {
                    final timeline = BoneScaleTimelineState();
                    timeline.target = blendState;
                    timeline.init(this._armature!, this, timelineData);
                    this._boneTimelines.add(timeline);
                    break;
                  }

                // Milestone 2: BoneAlpha / Surface timelines are not ported.
                default:
                  break;
              }
            }
          } else if (this.resetToPose) {
            // Pose timeline.
            final timeline = BoneAllTimelineState();
            timeline.target = blendState;
            timeline.init(this._armature!, this, null);
            this._boneTimelines.add(timeline);
            this._poseTimelines.add(timeline);
          }
        }
      }

      for (final k in boneTimelines.keys.toList()) {
        // Remove bone timelines.
        for (final timeline in boneTimelines[k]!) {
          var index = this._boneTimelines.indexOf(timeline);
          if (index >= 0) {
            this._boneTimelines.removeAt(index);
            timeline.returnToPool();
          }

          index = this._boneBlendTimelines.indexOf(timeline);
          if (index >= 0) {
            this._boneBlendTimelines.removeAt(index);
            timeline.returnToPool();
          }
        }
      }
    }

    {
      // Update slot timelines.
      final slotTimelines = <String, List<TimelineState>>{};
      // Geometry offsets that already have an FFD timeline this pass, so the
      // pose fallback does not add a second one for the same mesh.
      final ffdFlags = <int>[];
      // Create slot timelines map.
      for (final timeline in this._slotTimelines) {
        final timelineName = (timeline.target as Slot).name;
        slotTimelines.putIfAbsent(timelineName, () => <TimelineState>[]).add(timeline);
      }

      for (final timeline in this._slotBlendTimelines) {
        final timelineName = ((timeline.target as BlendState).target as Slot).name;
        slotTimelines.putIfAbsent(timelineName, () => <TimelineState>[]).add(timeline);
      }

      for (final slot in this._armature!.getSlots()) {
        final boneName = slot.parent.name;
        if (!this.containsBoneMask(boneName)) {
          continue;
        }

        final timelineName = slot.name;
        if (slotTimelines.containsKey(timelineName)) {
          // Remove slot timeline from map.
          slotTimelines.remove(timelineName);
        } else {
          // Create new slot timeline.
          var displayIndexFlag = false;
          var colorFlag = false;
          ffdFlags.clear();

          final timelineDatas = this._animationData!.getSlotTimelines(timelineName);
          if (timelineDatas != null) {
            for (final timelineData in timelineDatas) {
              switch (timelineData.type) {
                case TimelineType.SlotDisplay:
                  {
                    final timeline = SlotDisplayTimelineState();
                    timeline.target = slot;
                    timeline.init(this._armature!, this, timelineData);
                    this._slotTimelines.add(timeline);
                    displayIndexFlag = true;
                    break;
                  }

                case TimelineType.SlotColor:
                  {
                    final timeline = SlotColorTimelineState();
                    timeline.target = slot;
                    timeline.init(this._armature!, this, timelineData);
                    this._slotTimelines.add(timeline);
                    colorFlag = true;
                    break;
                  }

                case TimelineType.SlotDeform:
                  {
                    final dragonBonesData = this._animationData!.parent!.parent!;
                    final timelineArray = dragonBonesData.timelineArray!;
                    final frameIntOffset = this._animationData!.frameIntOffset +
                        timelineArray[timelineData.offset + BinaryOffset.TimelineFrameValueCount] as int;
                    final frameIntArray = dragonBonesData.frameIntArray!;
                    var geometryOffset = frameIntArray[frameIntOffset + BinaryOffset.DeformVertexOffset];

                    if (geometryOffset < 0) {
                      geometryOffset += 65536; // Fixed out of bounds bug.
                    }

                    for (var i = 0, l = slot.displayFrameCount; i < l; ++i) {
                      final displayFrame = slot.getDisplayFrameAt(i);
                      final geometryData = displayFrame.getGeometryData();

                      if (geometryData == null) {
                        continue;
                      }

                      if (geometryData.offset == geometryOffset) {
                        final timeline = DeformTimelineState();
                        timeline.target = this
                            ._armature!
                            .animation
                            .getBlendState(BlendState.SLOT_DEFORM, displayFrame.rawDisplayData!.name, slot);
                        timeline.displayFrame = displayFrame;
                        timeline.init(this._armature!, this, timelineData);
                        this._slotBlendTimelines.add(timeline);

                        displayFrame.updateDeformVertices();
                        ffdFlags.add(geometryOffset);
                        break;
                      }
                    }
                    break;
                  }

                // Milestone 2: SlotZIndex / SlotAlpha timelines are not ported.
                default:
                  break;
              }
            }
          }

          if (this.resetToPose) {
            // Pose timeline.
            if (!displayIndexFlag) {
              final timeline = SlotDisplayTimelineState();
              timeline.target = slot;
              timeline.init(this._armature!, this, null);
              this._slotTimelines.add(timeline);
              this._poseTimelines.add(timeline);
            }

            if (!colorFlag) {
              final timeline = SlotColorTimelineState();
              timeline.target = slot;
              timeline.init(this._armature!, this, null);
              this._slotTimelines.add(timeline);
              this._poseTimelines.add(timeline);
            }

            // Pose deform timelines: a display frame that already has deform
            // vertices (from `updateDeformVertices`) needs one to zero them.
            for (var i = 0, l = slot.displayFrameCount; i < l; ++i) {
              final displayFrame = slot.getDisplayFrameAt(i);

              if (displayFrame.deformVertices.isEmpty) {
                continue;
              }

              final geometryData = displayFrame.getGeometryData();
              if (geometryData != null && !ffdFlags.contains(geometryData.offset)) {
                final timeline = DeformTimelineState();
                timeline.displayFrame = displayFrame;
                timeline.target = this._armature!.animation.getBlendState(BlendState.SLOT_DEFORM, slot.name, slot);
                timeline.init(this._armature!, this, null);
                this._slotBlendTimelines.add(timeline);
                this._poseTimelines.add(timeline);
              }
            }
          }
        }
      }

      for (final k in slotTimelines.keys.toList()) {
        // Remove slot timelines.
        for (final timeline in slotTimelines[k]!) {
          var index = this._slotTimelines.indexOf(timeline);
          if (index >= 0) {
            this._slotTimelines.removeAt(index);
            timeline.returnToPool();
          }

          index = this._slotBlendTimelines.indexOf(timeline);
          if (index >= 0) {
            this._slotBlendTimelines.removeAt(index);
            timeline.returnToPool();
          }
        }
      }
    }
  }

  void _advanceFadeTime(double passedTime) {
    final bool isFadeOut = this._fadeState > 0;

    if (this._subFadeState < 0) {
      // Fade start event.
      this._subFadeState = 0;

      final bool eventActive = this._parent == null && this.actionEnabled;
      if (eventActive) {
        final eventType = isFadeOut ? EventObject.FADE_OUT : EventObject.FADE_IN;
        if (this._armature!.eventDispatcher.hasDBEventListener(eventType)) {
          final eventObject = EventObject();
          eventObject.type = eventType;
          eventObject.armature = this._armature;
          eventObject.animationState = this;
          this._armature!._dragonBones!.bufferEvent(eventObject);
        }
      }
    }

    if (passedTime < 0.0) {
      passedTime = -passedTime;
    }

    this._fadeTime += passedTime;

    if (this._fadeTime >= this.fadeTotalTime) {
      // Fade complete.
      this._subFadeState = 1;
      this._fadeProgress = isFadeOut ? 0.0 : 1.0;
    } else if (this._fadeTime > 0.0) {
      // Fading.
      this._fadeProgress =
          isFadeOut ? (1.0 - this._fadeTime / this.fadeTotalTime) : (this._fadeTime / this.fadeTotalTime);
    } else {
      // Before fade.
      this._fadeProgress = isFadeOut ? 1.0 : 0.0;
    }

    if (this._subFadeState > 0) {
      // Fade complete event.
      if (!isFadeOut) {
        this._playheadState |= 1; // x1
        this._fadeState = 0;
      }

      final bool eventActive = this._parent == null && this.actionEnabled;
      if (eventActive) {
        final eventType = isFadeOut ? EventObject.FADE_OUT_COMPLETE : EventObject.FADE_IN_COMPLETE;
        if (this._armature!.eventDispatcher.hasDBEventListener(eventType)) {
          final eventObject = EventObject();
          eventObject.type = eventType;
          eventObject.armature = this._armature;
          eventObject.animationState = this;
          this._armature!._dragonBones!.bufferEvent(eventObject);
        }
      }
    }
  }

  /// @internal
  void init(Armature armature, AnimationData animationData, AnimationConfig animationConfig) {
    if (this._armature != null) {
      return;
    }

    this._armature = armature;
    this._animationData = animationData;
    //
    this.resetToPose = animationConfig.resetToPose;
    this.additive = animationConfig.additive;
    this.displayControl = animationConfig.displayControl;
    this.actionEnabled = animationConfig.actionEnabled;
    this.blendType = animationData.blendType;
    this.layer = animationConfig.layer;
    this.playTimes = animationConfig.playTimes;
    this.timeScale = animationConfig.timeScale;
    this.fadeTotalTime = animationConfig.fadeInTime;
    this.autoFadeOutTime = animationConfig.autoFadeOutTime;
    this.name = animationConfig.name.isNotEmpty ? animationConfig.name : animationConfig.animation;
    this.group = animationConfig.group;
    //
    this._weight = animationConfig.weight;

    if (animationConfig.pauseFadeIn) {
      this._playheadState = 2; // 10
    } else {
      this._playheadState = 3; // 11
    }

    if (animationConfig.duration < 0.0) {
      this._position = 0.0;
      this._duration = this._animationData!.duration;

      if (animationConfig.position != 0.0) {
        if (this.timeScale >= 0.0) {
          this._time = animationConfig.position;
        } else {
          this._time = animationConfig.position - this._duration;
        }
      } else {
        this._time = 0.0;
      }
    } else {
      this._position = animationConfig.position;
      this._duration = animationConfig.duration;
      this._time = 0.0;
    }

    if (this.timeScale < 0.0 && this._time == 0.0) {
      this._time = -0.000001; // Turn to end.
    }

    if (this.fadeTotalTime <= 0.0) {
      this._fadeProgress = 0.999999; // Make different.
    }

    if (animationConfig.boneMask.isNotEmpty) {
      // NOTE: upstream grows the array via `.length =` and then assigns each
      // index; in Dart that would require filling with null first.
      this._boneMask
        ..clear()
        ..addAll(animationConfig.boneMask);
    }

    this._actionTimeline = ActionTimelineState();
    this._actionTimeline!.init(this._armature!, this, this._animationData!.actionTimeline);
    this._actionTimeline!.currentTime = this._time;

    if (this._actionTimeline!.currentTime < 0.0) {
      this._actionTimeline!.currentTime = this._duration - this._actionTimeline!.currentTime;
    }

    if (this._animationData!.zOrderTimeline != null) {
      this._zOrderTimeline = ZOrderTimelineState();
      this._zOrderTimeline!.init(this._armature!, this, this._animationData!.zOrderTimeline);
    }
  }

  /// @internal
  void advanceTime(double passedTime, double cacheFrameRate) {
    // Update fade time.
    if (this._fadeState != 0 || this._subFadeState != 0) {
      this._advanceFadeTime(passedTime);
    }
    // Update time.
    if (this._playheadState == 3) {
      // 11
      if (this.timeScale != 1.0) {
        passedTime *= this.timeScale;
      }

      this._time += passedTime;
    }
    // Update timeline.
    if (this._timelineDirty != 0) {
      if (this._timelineDirty == 2) {
        this._updateTimelines();
      }

      this._timelineDirty = 0;
      this._updateBoneAndSlotTimelines();
    }

    final bool isBlendDirty = this._fadeState != 0 || this._subFadeState == 0;
    final bool isCacheEnabled = this._fadeState == 0 && cacheFrameRate > 0.0;
    var isUpdateTimeline = true;
    var isUpdateBoneTimeline = true;
    final double time = this._time;
    this._weightResult = this._weight * this._fadeProgress;

    if (this._parent != null) {
      this._weightResult *= this._parent!._weightResult;
    }

    if (this._actionTimeline!.playState <= 0) {
      // Update main timeline.
      this._actionTimeline!.update(time);
    }

    if (this._weight == 0.0) {
      return;
    }

    if (isCacheEnabled) {
      // Cache time internval.
      final double internval = cacheFrameRate * 2.0;
      this._actionTimeline!.currentTime = (this._actionTimeline!.currentTime * internval).floor() / internval;
    }

    if (this._zOrderTimeline != null && this._zOrderTimeline!.playState <= 0) {
      // Update zOrder timeline.
      this._zOrderTimeline!.update(time);
    }

    if (isCacheEnabled) {
      // Update cache.
      final int cacheFrameIndex = (this._actionTimeline!.currentTime * cacheFrameRate).floor(); // uint
      if (this._armature!._cacheFrameIndex == cacheFrameIndex) {
        // Same cache.
        isUpdateTimeline = false;
        isUpdateBoneTimeline = false;
      } else {
        this._armature!._cacheFrameIndex = cacheFrameIndex;

        if (this._animationData!.cachedFrames[cacheFrameIndex]) {
          // Cached.
          isUpdateBoneTimeline = false;
        } else {
          // Cache.
          this._animationData!.cachedFrames[cacheFrameIndex] = true;
        }
      }
    }

    if (isUpdateTimeline) {
      var isBlend = false;
      BlendState? prevTarget;

      if (isUpdateBoneTimeline) {
        for (var i = 0, l = this._boneTimelines.length; i < l; ++i) {
          final timeline = this._boneTimelines[i];

          if (timeline.playState <= 0) {
            timeline.update(time);
          }

          if (timeline.target != prevTarget) {
            final blendState = timeline.target as BlendState;
            isBlend = blendState.update(this);
            prevTarget = blendState;

            if (blendState.dirty == 1) {
              final pose = (blendState.target as Bone).animationPose;
              pose.x = 0.0;
              pose.y = 0.0;
              pose.rotation = 0.0;
              pose.skew = 0.0;
              pose.scaleX = 1.0;
              pose.scaleY = 1.0;
            }
          }

          if (isBlend) {
            timeline.blend(isBlendDirty);
          }
        }
      }

      for (var i = 0, l = this._boneBlendTimelines.length; i < l; ++i) {
        final timeline = this._boneBlendTimelines[i];

        if (timeline.playState <= 0) {
          timeline.update(time);
        }

        if ((timeline.target as BlendState).update(this)) {
          timeline.blend(isBlendDirty);
        }
      }

      if (this.displayControl) {
        for (var i = 0, l = this._slotTimelines.length; i < l; ++i) {
          final timeline = this._slotTimelines[i];
          if (timeline.playState <= 0) {
            final slot = timeline.target as Slot;
            final displayController = slot.displayController;

            if (displayController == null || displayController == this.name || displayController == this.group) {
              timeline.update(time);
            }
          }
        }
      }

      for (var i = 0, l = this._slotBlendTimelines.length; i < l; ++i) {
        final timeline = this._slotBlendTimelines[i];
        if (timeline.playState <= 0) {
          final blendState = timeline.target as BlendState;
          timeline.update(time);

          if (blendState.update(this)) {
            timeline.blend(isBlendDirty);
          }
        }
      }

      for (var i = 0, l = this._constraintTimelines.length; i < l; ++i) {
        final timeline = this._constraintTimelines[i];
        if (timeline.playState <= 0) {
          timeline.update(time);
        }
      }

      if (this._animationTimelines.isNotEmpty) {
        var dL = 100.0;
        var dR = 100.0;
        AnimationState? leftState;
        AnimationState? rightState;

        for (var i = 0, l = this._animationTimelines.length; i < l; ++i) {
          final timeline = this._animationTimelines[i];
          if (timeline.playState <= 0) {
            timeline.update(time);
          }

          if (this.blendType == AnimationBlendType.E1D) {
            final animationState = timeline.target as AnimationState;
            final double d = this.parameterX - animationState.positionX;

            if (d >= 0.0) {
              if (d < dL) {
                dL = d;
                leftState = animationState;
              }
            } else {
              if (-d < dR) {
                dR = -d;
                rightState = animationState;
              }
            }
          }
        }

        if (leftState != null) {
          if (this._activeChildA != leftState) {
            if (this._activeChildA != null) {
              this._activeChildA!.weight = 0.0;
            }

            this._activeChildA = leftState;
            this._activeChildA!.activeTimeline();
          }

          if (this._activeChildB != rightState) {
            if (this._activeChildB != null) {
              this._activeChildB!.weight = 0.0;
            }

            this._activeChildB = rightState;
          }

          leftState.weight = dR / (dL + dR);

          if (rightState != null) {
            rightState.weight = 1.0 - leftState.weight;
          }
        }
      }
    }

    if (this._fadeState == 0) {
      if (this._subFadeState > 0) {
        this._subFadeState = 0;

        if (this._poseTimelines.isNotEmpty) {
          // Remove pose timelines.
          for (final timeline in this._poseTimelines) {
            var index = this._boneTimelines.indexOf(timeline);
            if (index >= 0) {
              this._boneTimelines.removeAt(index);
              timeline.returnToPool();
              continue;
            }

            index = this._boneBlendTimelines.indexOf(timeline);
            if (index >= 0) {
              this._boneBlendTimelines.removeAt(index);
              timeline.returnToPool();
              continue;
            }

            index = this._slotTimelines.indexOf(timeline);
            if (index >= 0) {
              this._slotTimelines.removeAt(index);
              timeline.returnToPool();
              continue;
            }

            index = this._slotBlendTimelines.indexOf(timeline);
            if (index >= 0) {
              this._slotBlendTimelines.removeAt(index);
              timeline.returnToPool();
              continue;
            }

            index = this._constraintTimelines.indexOf(timeline);
            if (index >= 0) {
              this._constraintTimelines.removeAt(index);
              timeline.returnToPool();
              continue;
            }
          }

          this._poseTimelines.length = 0;
        }
      }

      if (this._actionTimeline!.playState > 0) {
        if (this.autoFadeOutTime >= 0.0) {
          // Auto fade out.
          this.fadeOut(this.autoFadeOutTime);
        }
      }
    }
  }

  /// - Continue play.
  void play() {
    this._playheadState = 3; // 11
  }

  /// - Stop play.
  void stop() {
    this._playheadState &= 1; // 0x
  }

  /// - Fade out the animation state.
  void fadeOut(double fadeOutTime, [bool pausePlayhead = true]) {
    if (fadeOutTime < 0.0) {
      fadeOutTime = 0.0;
    }

    if (pausePlayhead) {
      this._playheadState &= 2; // x0
    }

    if (this._fadeState > 0) {
      if (fadeOutTime > this.fadeTotalTime - this._fadeTime) {
        // If the animation is already in fade out, the new fade out will be ignored.
        return;
      }
    } else {
      this._fadeState = 1;
      this._subFadeState = -1;

      if (fadeOutTime <= 0.0 || this._fadeProgress <= 0.0) {
        this._fadeProgress = 0.000001; // Modify fade progress to different value.
      }

      for (final timeline in this._boneTimelines) {
        timeline.fadeOut();
      }

      for (final timeline in this._boneBlendTimelines) {
        timeline.fadeOut();
      }

      for (final timeline in this._slotTimelines) {
        timeline.fadeOut();
      }

      for (final timeline in this._slotBlendTimelines) {
        timeline.fadeOut();
      }

      for (final timeline in this._constraintTimelines) {
        timeline.fadeOut();
      }

      for (final timeline in this._animationTimelines) {
        timeline.fadeOut();
        //
        final animaitonState = timeline.target as AnimationState;
        animaitonState.fadeOut(999999.0, true);
      }
    }

    this.displayControl = false;
    this.fadeTotalTime = this._fadeProgress > 0.000001 ? fadeOutTime / this._fadeProgress : 0.0;
    this._fadeTime = this.fadeTotalTime * (1.0 - this._fadeProgress);
  }

  /// - Check if a specific bone mask is included.
  bool containsBoneMask(String boneName) {
    return this._boneMask.isEmpty || this._boneMask.indexOf(boneName) >= 0;
  }

  /// - Add a specific bone mask.
  void addBoneMask(String boneName, [bool recursive = true]) {
    final currentBone = this._armature!.getBone(boneName);
    if (currentBone == null) {
      return;
    }

    if (this._boneMask.indexOf(boneName) < 0) {
      // Add mixing
      this._boneMask.add(boneName);
    }

    if (recursive) {
      // Add recursive mixing.
      for (final bone in this._armature!.getBones()) {
        if (this._boneMask.indexOf(bone.name) < 0 && currentBone.contains(bone)) {
          this._boneMask.add(bone.name);
        }
      }
    }

    this._timelineDirty = 1;
  }

  /// - Remove the mask of a specific bone.
  void removeBoneMask(String boneName, [bool recursive = true]) {
    var index = this._boneMask.indexOf(boneName);
    if (index >= 0) {
      // Remove mixing.
      this._boneMask.removeAt(index);
    }

    if (recursive) {
      final currentBone = this._armature!.getBone(boneName);
      if (currentBone != null) {
        final bones = this._armature!.getBones();
        if (this._boneMask.isNotEmpty) {
          // Remove recursive mixing.
          for (final bone in bones) {
            final i = this._boneMask.indexOf(bone.name);
            if (i >= 0 && currentBone.contains(bone)) {
              this._boneMask.removeAt(i);
            }
          }
        } else {
          // Add unrecursive mixing.
          for (final bone in bones) {
            if (bone == currentBone) {
              continue;
            }

            if (!currentBone.contains(bone)) {
              this._boneMask.add(bone.name);
            }
          }
        }
      }
    }

    this._timelineDirty = 1;
  }

  /// - Remove all bone masks.
  void removeAllBoneMask() {
    this._boneMask.length = 0;
    this._timelineDirty = 1;
  }

  /// @private
  void addState(AnimationState animationState, [List<TimelineData>? timelineDatas]) {
    // Milestone 2: blend animation nodes (AnimationProgress/Weight/Parameter
    // timelines) are not ported.
    if (animationState._parent == null) {
      animationState._parent = this;
    }
  }

  /// @internal
  void activeTimeline() {
    for (final timeline in this._slotTimelines) {
      timeline.dirty = true;
      timeline.currentTime = -1.0;
    }
  }

  bool get isFadeIn => this._fadeState < 0;
  bool get isFadeOut => this._fadeState > 0;
  bool get isFadeComplete => this._fadeState == 0;

  bool get isPlaying => (this._playheadState & 2) != 0 && this._actionTimeline!.playState <= 0;
  bool get isCompleted => this._actionTimeline!.playState > 0;
  int get currentPlayTimes => this._actionTimeline!.currentPlayTimes;
  double get totalTime => this._duration;
  double get currentTime => this._actionTimeline!.currentTime;
  set currentTime(double value) {
    final int currentPlayTimes = this._actionTimeline!.currentPlayTimes - (this._actionTimeline!.playState > 0 ? 1 : 0);
    if (value < 0 || this._duration < value) {
      value = _jsMod(value, this._duration) + currentPlayTimes * this._duration;
      if (value < 0) {
        value += this._duration;
      }
    }

    if (this.playTimes > 0 &&
        currentPlayTimes == this.playTimes - 1 &&
        value == this._duration &&
        this._parent == null) {
      value = this._duration - 0.000001;
    }

    if (this._time == value) {
      return;
    }

    this._time = value;
    this._actionTimeline!.setCurrentTime(this._time);

    if (this._zOrderTimeline != null) {
      this._zOrderTimeline!.playState = -1;
    }

    for (final timeline in this._boneTimelines) {
      timeline.playState = -1;
    }

    for (final timeline in this._slotTimelines) {
      timeline.playState = -1;
    }
  }

  double get weight => this._weight;
  set weight(double value) {
    if (this._weight == value) {
      return;
    }

    this._weight = value;

    for (final timeline in this._boneTimelines) {
      timeline.dirty = true;
    }

    for (final timeline in this._boneBlendTimelines) {
      timeline.dirty = true;
    }

    for (final timeline in this._slotBlendTimelines) {
      timeline.dirty = true;
    }
  }

  AnimationData get animationData => this._animationData!;
}

/// @internal
///
/// Faithful port of `.ref/dragonBones-ts/animation/AnimationState.ts`'s
/// `BlendState`.
class BlendState extends BaseObject {
  static const String BONE_TRANSFORM = 'boneTransform';
  static const String BONE_ALPHA = 'boneAlpha';
  static const String SURFACE = 'surface';
  static const String SLOT_DEFORM = 'slotDeform';
  static const String SLOT_ALPHA = 'slotAlpha';
  static const String SLOT_Z_INDEX = 'slotZIndex';

  int dirty = 0;
  int layer = 0;
  double leftWeight = 0.0;
  double layerWeight = 0.0;
  double blendWeight = 0.0;
  BaseObject? target;

  @override
  void _onClear() {
    this.reset();

    this.target = null;
  }

  bool update(AnimationState animationState) {
    final int animationLayer = animationState.layer;
    double animationWeight = animationState._weightResult;

    if (this.dirty > 0) {
      if (this.leftWeight > 0.0) {
        if (this.layer != animationLayer) {
          if (this.layerWeight >= this.leftWeight) {
            this.dirty++;
            this.layer = animationLayer;
            this.leftWeight = 0.0;
            this.blendWeight = 0.0;

            return false;
          }

          this.layer = animationLayer;
          this.leftWeight -= this.layerWeight;
          this.layerWeight = 0.0;
        }

        animationWeight *= this.leftWeight;
        this.dirty++;
        this.blendWeight = animationWeight;
        this.layerWeight += this.blendWeight;

        return true;
      }

      return false;
    }

    this.dirty++;
    this.layer = animationLayer;
    this.leftWeight = 1.0;
    this.blendWeight = animationWeight;
    this.layerWeight = animationWeight;

    return true;
  }

  void reset() {
    this.dirty = 0;
    this.layer = 0;
    this.leftWeight = 0.0;
    this.layerWeight = 0.0;
    this.blendWeight = 0.0;
  }
}
