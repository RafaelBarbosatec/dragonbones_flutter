part of '../../dragonbones.dart';

/// - The animation player is used to play the animation data and manage the
/// animation states.
///
/// Faithful port of `.ref/dragonBones-ts/animation/Animation.ts` (manual
/// fade-out `Single` mode / child-armature propagation are kept; `gotoAnd*`
/// helpers are omitted as unused).
class Animation extends BaseObject {
  /// - The play speed of all animations.
  double timeScale = 1.0;

  bool _animationDirty = false;
  double _inheritTimeScale = 1.0;
  final List<String> _animationNames = <String>[];
  final List<AnimationState> _animationStates = <AnimationState>[];
  final Map<String, AnimationData> _animations = <String, AnimationData>{};
  final Map<String, Map<String, BlendState>> _blendStates = <String, Map<String, BlendState>>{};
  Armature? _armature;
  AnimationConfig? _animationConfig;
  AnimationState? _lastAnimationState;

  @override
  void _onClear() {
    for (final animationState in this._animationStates) {
      animationState.returnToPool();
    }

    this._animations.clear();

    for (final k in this._blendStates.keys.toList()) {
      final blendStates = this._blendStates[k]!;
      for (final kB in blendStates.keys) {
        blendStates[kB]!.returnToPool();
      }

      this._blendStates.remove(k);
    }

    this.timeScale = 1.0;

    this._animationDirty = false;
    this._inheritTimeScale = 1.0;
    this._animationNames.length = 0;
    this._animationStates.length = 0;
    this._armature = null;
    this._animationConfig = null;
    this._lastAnimationState = null;
  }

  void _fadeOut(AnimationConfig animationConfig) {
    switch (animationConfig.fadeOutMode) {
      case AnimationFadeOutMode.SameLayer:
        for (final animationState in this._animationStates) {
          if (animationState._parent != null) {
            continue;
          }

          if (animationState.layer == animationConfig.layer) {
            animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
          }
        }
        break;

      case AnimationFadeOutMode.SameGroup:
        for (final animationState in this._animationStates) {
          if (animationState._parent != null) {
            continue;
          }

          if (animationState.group == animationConfig.group) {
            animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
          }
        }
        break;

      case AnimationFadeOutMode.SameLayerAndGroup:
        for (final animationState in this._animationStates) {
          if (animationState._parent != null) {
            continue;
          }

          if (animationState.layer == animationConfig.layer && animationState.group == animationConfig.group) {
            animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
          }
        }
        break;

      case AnimationFadeOutMode.All:
        for (final animationState in this._animationStates) {
          if (animationState._parent != null) {
            continue;
          }

          animationState.fadeOut(animationConfig.fadeOutTime, animationConfig.pauseFadeOut);
        }
        break;

      case AnimationFadeOutMode.Single: // TODO
      default:
        break;
    }
  }

  /// @internal
  void init(Armature armature) {
    if (this._armature != null) {
      return;
    }

    this._armature = armature;
    this._animationConfig = AnimationConfig();
  }

  /// @internal
  void advanceTime(double passedTime) {
    if (passedTime < 0.0) {
      // Only animationState can reverse play.
      passedTime = -passedTime;
    }

    if (this._armature!.inheritAnimation && this._armature!._parent != null) {
      // Inherit parent animation timeScale.
      this._inheritTimeScale = this._armature!._parent!._armature!.animation._inheritTimeScale * this.timeScale;
    } else {
      this._inheritTimeScale = this.timeScale;
    }

    if (this._inheritTimeScale != 1.0) {
      passedTime *= this._inheritTimeScale;
    }

    for (final k in this._blendStates.keys) {
      final blendStates = this._blendStates[k]!;
      for (final kB in blendStates.keys) {
        blendStates[kB]!.reset();
      }
    }

    final int animationStateCount = this._animationStates.length;
    if (animationStateCount == 1) {
      final animationState = this._animationStates[0];
      if (animationState._fadeState > 0 && animationState._subFadeState > 0) {
        this._armature!._dragonBones!.bufferObject(animationState);
        this._animationStates.length = 0;
        this._lastAnimationState = null;
      } else {
        final animationData = animationState.animationData;
        final cacheFrameRate = animationData.cacheFrameRate;

        if (this._animationDirty && cacheFrameRate > 0.0) {
          // Update cachedFrameIndices.
          this._animationDirty = false;
        }

        animationState.advanceTime(passedTime, cacheFrameRate);
      }
    } else if (animationStateCount > 1) {
      for (var i = 0, r = 0; i < animationStateCount; ++i) {
        final animationState = this._animationStates[i];
        if (animationState._fadeState > 0 && animationState._subFadeState > 0) {
          r++;
          this._armature!._dragonBones!.bufferObject(animationState);
          this._animationDirty = true;

          if (this._lastAnimationState == animationState) {
            // Update last animation state.
            this._lastAnimationState = null;
          }
        } else {
          if (r > 0) {
            this._animationStates[i - r] = animationState;
          }

          animationState.advanceTime(passedTime, 0.0);
        }

        if (i == animationStateCount - 1 && r > 0) {
          // Modify animation states size.
          this._animationStates.length -= r;

          if (this._lastAnimationState == null && this._animationStates.isNotEmpty) {
            this._lastAnimationState = this._animationStates[this._animationStates.length - 1];
          }
        }
      }

      this._armature!._cacheFrameIndex = -1;
    } else {
      this._armature!._cacheFrameIndex = -1;
    }
  }

  /// - Clear all animations states.
  void reset() {
    for (final animationState in this._animationStates) {
      animationState.returnToPool();
    }

    this._animationDirty = false;
    this._animationConfig!.clear();
    this._animationStates.length = 0;
    this._lastAnimationState = null;
  }

  /// - Pause a specific animation state.
  void stop([String? animationName]) {
    if (animationName != null) {
      final animationState = this.getState(animationName);
      if (animationState != null) {
        animationState.stop();
      }
    } else {
      for (final animationState in this._animationStates) {
        animationState.stop();
      }
    }
  }

  /// @internal
  AnimationState? playConfig(AnimationConfig animationConfig) {
    final animationName = animationConfig.animation;
    if (!this._animations.containsKey(animationName)) {
      return null;
    }

    final animationData = this._animations[animationName]!;

    if (animationConfig.fadeOutMode == AnimationFadeOutMode.Single) {
      for (final animationState in this._animationStates) {
        if (animationState._fadeState < 1 &&
            animationState.layer == animationConfig.layer &&
            animationState.animationData == animationData) {
          return animationState;
        }
      }
    }

    if (this._animationStates.isEmpty) {
      animationConfig.fadeInTime = 0.0;
    } else if (animationConfig.fadeInTime < 0.0) {
      animationConfig.fadeInTime = animationData.fadeInTime;
    }

    if (animationConfig.fadeOutTime < 0.0) {
      animationConfig.fadeOutTime = animationConfig.fadeInTime;
    }

    if (animationConfig.timeScale <= -100.0) {
      animationConfig.timeScale = 1.0 / animationData.scale;
    }

    if (animationData.frameCount > 0) {
      if (animationConfig.position < 0.0) {
        animationConfig.position %= animationData.duration;
        animationConfig.position = animationData.duration - animationConfig.position;
      } else if (animationConfig.position == animationData.duration) {
        animationConfig.position -= 0.000001; // Play a little time before end.
      } else if (animationConfig.position > animationData.duration) {
        animationConfig.position %= animationData.duration;
      }

      if (animationConfig.duration > 0.0 &&
          animationConfig.position + animationConfig.duration > animationData.duration) {
        animationConfig.duration = animationData.duration - animationConfig.position;
      }

      if (animationConfig.playTimes < 0) {
        animationConfig.playTimes = animationData.playTimes;
      }
    } else {
      animationConfig.playTimes = 1;
      animationConfig.position = 0.0;

      if (animationConfig.duration > 0.0) {
        animationConfig.duration = 0.0;
      }
    }

    if (animationConfig.duration == 0.0) {
      animationConfig.duration = -1.0;
    }

    this._fadeOut(animationConfig);
    //
    final animationState = AnimationState();
    animationState.init(this._armature!, animationData, animationConfig);
    this._animationDirty = true;
    this._armature!._cacheFrameIndex = -1;

    if (this._animationStates.isNotEmpty) {
      // Sort animation state.
      var added = false;

      for (var i = 0, l = this._animationStates.length; i < l; ++i) {
        if (animationState.layer > this._animationStates[i].layer) {
          added = true;
          this._animationStates.insert(i, animationState);
          break;
        } else if (i != l - 1 && animationState.layer > this._animationStates[i + 1].layer) {
          added = true;
          this._animationStates.insert(i + 1, animationState);
          break;
        }
      }

      if (!added) {
        this._animationStates.add(animationState);
      }
    } else {
      this._animationStates.add(animationState);
    }

    // Milestone 2: child-armature same-name propagation and blend animation
    // nodes (animationData.animationTimelines) are not ported.

    this._lastAnimationState = animationState;

    return animationState;
  }

  /// - Play a specific animation.
  AnimationState? play([String? animationName, int playTimes = -1]) {
    this._animationConfig!.clear();
    this._animationConfig!.resetToPose = true;
    this._animationConfig!.playTimes = playTimes;
    this._animationConfig!.fadeInTime = 0.0;
    this._animationConfig!.animation = animationName != null ? animationName : '';

    if (animationName != null && animationName.isNotEmpty) {
      this.playConfig(this._animationConfig!);
    } else if (this._lastAnimationState == null) {
      final defaultAnimation = this._armature!.armatureData.defaultAnimation;
      if (defaultAnimation != null) {
        this._animationConfig!.animation = defaultAnimation.name;
        this.playConfig(this._animationConfig!);
      }
    } else if (!this._lastAnimationState!.isPlaying && !this._lastAnimationState!.isCompleted) {
      this._lastAnimationState!.play();
    } else {
      this._animationConfig!.animation = this._lastAnimationState!.name;
      this.playConfig(this._animationConfig!);
    }

    return this._lastAnimationState;
  }

  /// - Fade in a specific animation.
  AnimationState? fadeIn(String animationName,
      [double fadeInTime = -1.0,
      int playTimes = -1,
      int layer = 0,
      String? group,
      int fadeOutMode = AnimationFadeOutMode.SameLayerAndGroup]) {
    this._animationConfig!.clear();
    this._animationConfig!.fadeOutMode = fadeOutMode;
    this._animationConfig!.playTimes = playTimes;
    this._animationConfig!.layer = layer;
    this._animationConfig!.fadeInTime = fadeInTime;
    this._animationConfig!.animation = animationName;
    this._animationConfig!.group = group != null ? group : '';

    return this.playConfig(this._animationConfig!);
  }

  /// @internal
  BlendState getBlendState(String type, String name, BaseObject target) {
    if (!this._blendStates.containsKey(type)) {
      this._blendStates[type] = <String, BlendState>{};
    }

    final blendStates = this._blendStates[type]!;
    if (!blendStates.containsKey(name)) {
      final blendState = BlendState();
      blendStates[name] = blendState;
      blendState.target = target;
    }

    return blendStates[name]!;
  }

  /// - Get a specific animation state.
  AnimationState? getState(String animationName, [int layer = -1]) {
    var i = this._animationStates.length;
    while (i-- > 0) {
      final animationState = this._animationStates[i];
      if (animationState.name == animationName && (layer < 0 || animationState.layer == layer)) {
        return animationState;
      }
    }

    return null;
  }

  /// - Check whether a specific animation data is included.
  bool hasAnimation(String animationName) => this._animations.containsKey(animationName);

  /// - Get all the animation states.
  List<AnimationState> getStates() => this._animationStates;

  bool get isPlaying {
    for (final animationState in this._animationStates) {
      if (animationState.isPlaying) {
        return true;
      }
    }

    return false;
  }

  bool get isCompleted {
    for (final animationState in this._animationStates) {
      if (!animationState.isCompleted) {
        return false;
      }
    }

    return this._animationStates.isNotEmpty;
  }

  String get lastAnimationName => this._lastAnimationState != null ? this._lastAnimationState!.name : '';

  List<String> get animationNames => this._animationNames;

  Map<String, AnimationData> get animations => this._animations;
  set animations(Map<String, AnimationData> value) {
    if (identical(this._animations, value)) {
      return;
    }

    this._animationNames.length = 0;
    this._animations.clear();

    for (final k in value.keys) {
      this._animationNames.add(k);
      this._animations[k] = value[k]!;
    }
  }

  /// - An AnimationConfig instance that can be used quickly.
  AnimationConfig get animationConfig {
    this._animationConfig!.clear();
    return this._animationConfig!;
  }

  /// - The last playing animation state.
  AnimationState? get lastAnimationState => this._lastAnimationState;
}
