part of dragonbones;

/// - An interface that the engine binding implements so the armature can
/// communicate with the display container.
///
/// Port of `.ref/dragonBones-ts/armature/IArmatureProxy.ts` (trimmed to what
/// milestone 1 needs).
abstract class IArmatureProxy {
  void dbInit(Armature armature);
  void dbClear();
  void dbUpdate();
  bool hasDBEventListener(String type);
  Armature get armature;
  Animation get animation;
}

/// @private
///
/// Base class for runtime constraints. Milestone 1 has no constraints, so only
/// the members referenced by [Bone] / [Armature] are declared.
abstract class Constraint extends BaseObject {
  /// @internal
  Bone? _root;

  /// @internal
  void update();
}

/// - Armature is the core of the skeleton animation system.
///
/// Faithful port of `.ref/dragonBones-ts/armature/Armature.ts` (manual action
/// buffering / event objects are elided; the fixtures used by milestone 1 have
/// no actions).
class Armature extends BaseObject implements IAnimatable {
  /// - Whether to inherit the animation control of the parent armature.
  bool inheritAnimation = true;

  /// @private
  Object? userData;

  /// @internal
  bool _lockUpdate = false;

  bool _slotsDirty = true;
  bool _zOrderDirty = false;

  /// @internal
  bool _zIndexDirty = false;

  /// @internal
  bool _alphaDirty = true;

  bool _flipX = false;
  bool _flipY = false;

  /// @internal
  int _cacheFrameIndex = -1;

  double _alpha = 1.0;

  /// @internal
  double _globalAlpha = 1.0;

  final List<Bone> _bones = <Bone>[];
  final List<Slot> _slots = <Slot>[];

  /// @internal
  final List<Constraint> _constraints = <Constraint>[];

  /// @internal
  ArmatureData? _armatureData;

  Animation? _animation;

  IArmatureProxy? _proxy;

  Object? _display;

  /// @internal
  TextureAtlasData? _replaceTextureAtlasData;

  Object? _replacedTexture;

  /// @internal
  DragonBones? _dragonBones;

  WorldClock? _clock;

  /// @internal
  Slot? _parent;

  @override
  void _onClear() {
    if (this._clock != null) {
      this._clock!.remove(this);
    }

    for (final bone in this._bones) {
      bone.returnToPool();
    }

    for (final slot in this._slots) {
      slot.returnToPool();
    }

    for (final constraint in this._constraints) {
      constraint.returnToPool();
    }

    if (this._animation != null) {
      this._animation!.returnToPool();
    }

    if (this._proxy != null) {
      this._proxy!.dbClear();
    }

    if (this._replaceTextureAtlasData != null) {
      this._replaceTextureAtlasData!.returnToPool();
    }

    this.inheritAnimation = true;
    this.userData = null;

    this._lockUpdate = false;
    this._slotsDirty = true;
    this._zOrderDirty = false;
    this._zIndexDirty = false;
    this._alphaDirty = true;
    this._flipX = false;
    this._flipY = false;
    this._cacheFrameIndex = -1;
    this._alpha = 1.0;
    this._globalAlpha = 1.0;
    this._bones.length = 0;
    this._slots.length = 0;
    this._constraints.length = 0;
    this._armatureData = null;
    this._animation = null;
    this._proxy = null;
    this._display = null;
    this._replaceTextureAtlasData = null;
    this._replacedTexture = null;
    this._dragonBones = null;
    this._clock = null;
    this._parent = null;
  }

  static int _onSortSlots(Slot a, Slot b) =>
      a._zIndex * 1000 + a._zOrder > b._zIndex * 1000 + b._zOrder ? 1 : -1;

  /// @internal
  void _sortZOrder(List<int>? slotIndices, int offset) {
    final slotDatas = this._armatureData!.sortedSlots;
    final bool isOriginal = slotIndices == null;

    if (this._zOrderDirty || !isOriginal) {
      for (var i = 0, l = slotDatas.length; i < l; ++i) {
        final int slotIndex = isOriginal ? i : slotIndices[offset + i];
        if (slotIndex < 0 || slotIndex >= l) {
          continue;
        }

        final slotData = slotDatas[slotIndex];
        final slot = this.getSlot(slotData.name);

        if (slot != null) {
          slot._setZOrder(i);
        }
      }

      this._slotsDirty = true;
      this._zOrderDirty = !isOriginal;
    }
  }

  /// @internal
  void _addBone(Bone value) {
    if (this._bones.indexOf(value) < 0) {
      this._bones.add(value);
    }
  }

  /// @internal
  void _addSlot(Slot value) {
    if (this._slots.indexOf(value) < 0) {
      this._slots.add(value);
    }
  }

  /// @internal
  void _addConstraint(Constraint value) {
    if (this._constraints.indexOf(value) < 0) {
      this._constraints.add(value);
    }
  }

  /// - Dispose the armature.
  void dispose() {
    if (this._armatureData != null) {
      this._lockUpdate = true;
      this._dragonBones!.bufferObject(this);
    }
  }

  /// @internal
  void init(ArmatureData armatureData, IArmatureProxy proxy, Object? display, DragonBones dragonBones) {
    if (this._armatureData != null) {
      return;
    }

    this._armatureData = armatureData;
    this._animation = Animation();
    this._proxy = proxy;
    this._display = display;
    this._dragonBones = dragonBones;

    this._proxy!.dbInit(this);
    this._animation!.init(this);
    this._animation!.animations = this._armatureData!.animations;
  }

  /// @inheritDoc
  void advanceTime(double passedTime) {
    if (this._lockUpdate) {
      return;
    }

    this._lockUpdate = true;

    if (this._armatureData == null) {
      this._lockUpdate = false;
      return;
    } else if (this._armatureData!.parent == null) {
      this._lockUpdate = false;
      return;
    }

    final int prevCacheFrameIndex = this._cacheFrameIndex;
    // Update animation.
    this._animation!.advanceTime(passedTime);
    // Sort slots.
    if (this._slotsDirty || this._zIndexDirty) {
      this._slots.sort(Armature._onSortSlots);

      if (this._zIndexDirty) {
        for (var i = 0, l = this._slots.length; i < l; ++i) {
          this._slots[i]._setZOrder(i);
        }
      }

      this._slotsDirty = false;
      this._zIndexDirty = false;
    }
    // Update alpha.
    if (this._alphaDirty) {
      this._alphaDirty = false;
      this._globalAlpha = this._alpha * (this._parent != null ? this._parent!._globalAlpha : 1.0);

      for (final bone in this._bones) {
        bone._updateAlpha();
      }

      for (final slot in this._slots) {
        slot._updateAlpha();
      }
    }
    // Update bones and slots.
    if (this._cacheFrameIndex < 0 || this._cacheFrameIndex != prevCacheFrameIndex) {
      for (var i = 0, l = this._bones.length; i < l; ++i) {
        this._bones[i].update(this._cacheFrameIndex);
      }

      for (var i = 0, l = this._slots.length; i < l; ++i) {
        this._slots[i].update(this._cacheFrameIndex);
      }
    }

    this._lockUpdate = false;
    this._proxy!.dbUpdate();
  }

  /// - Forces a specific bone or its owning slot to update next frame.
  void invalidUpdate([String? boneName, bool updateSlot = false]) {
    if (boneName != null && boneName.length > 0) {
      final bone = this.getBone(boneName);
      if (bone != null) {
        bone.invalidUpdate();

        if (updateSlot) {
          for (final slot in this._slots) {
            if (slot.parent == bone) {
              slot.invalidUpdate();
            }
          }
        }
      }
    } else {
      for (final bone in this._bones) {
        bone.invalidUpdate();
      }

      if (updateSlot) {
        for (final slot in this._slots) {
          slot.invalidUpdate();
        }
      }
    }
  }

  /// - Get a specific bone.
  Bone? getBone(String name) {
    for (final bone in this._bones) {
      if (bone.name == name) {
        return bone;
      }
    }

    return null;
  }

  /// - Get a specific bone by the display.
  Bone? getBoneByDisplay(Object? display) {
    final slot = this.getSlotByDisplay(display);

    return slot != null ? slot.parent : null;
  }

  /// - Get a specific slot.
  Slot? getSlot(String name) {
    for (final slot in this._slots) {
      if (slot.name == name) {
        return slot;
      }
    }

    return null;
  }

  /// - Get a specific slot by the display.
  Slot? getSlotByDisplay(Object? display) {
    if (display != null) {
      for (final slot in this._slots) {
        if (slot.display == display) {
          return slot;
        }
      }
    }

    return null;
  }

  /// - Get all bones.
  List<Bone> getBones() => this._bones;

  /// - Get all slots.
  List<Slot> getSlots() => this._slots;

  /// - Whether to flip the armature horizontally.
  bool get flipX => this._flipX;
  set flipX(bool value) {
    if (this._flipX == value) {
      return;
    }

    this._flipX = value;
    this.invalidUpdate();
  }

  /// - Whether to flip the armature vertically.
  bool get flipY => this._flipY;
  set flipY(bool value) {
    if (this._flipY == value) {
      return;
    }

    this._flipY = value;
    this.invalidUpdate();
  }

  /// - The animation cache frame rate.
  double get cacheFrameRate => this._armatureData!.cacheFrameRate;
  set cacheFrameRate(double value) {
    if (this._armatureData!.cacheFrameRate != value) {
      this._armatureData!.cacheFrames(value);

      for (final slot in this._slots) {
        final childArmature = slot.childArmature;
        if (childArmature != null) {
          childArmature.cacheFrameRate = value;
        }
      }
    }
  }

  /// - The armature name.
  String get name => this._armatureData!.name;

  /// - The armature data.
  ArmatureData get armatureData => this._armatureData!;

  /// - The animation player.
  Animation get animation => this._animation!;

  /// @private
  IArmatureProxy get proxy => this._proxy!;

  /// - The event dispatcher.
  IArmatureProxy get eventDispatcher => this._proxy!;

  /// - The display container.
  Object? get display => this._display;

  /// @private
  Object? get replacedTexture => this._replacedTexture;
  set replacedTexture(Object? value) {
    if (this._replacedTexture == value) {
      return;
    }

    if (this._replaceTextureAtlasData != null) {
      this._replaceTextureAtlasData!.returnToPool();
      this._replaceTextureAtlasData = null;
    }

    this._replacedTexture = value;

    for (final slot in this._slots) {
      slot.invalidUpdate();
      slot.update(-1);
    }
  }

  /// @inheritDoc
  WorldClock? get clock => this._clock;
  set clock(WorldClock? value) {
    if (this._clock == value) {
      return;
    }

    if (this._clock != null) {
      this._clock!.remove(this);
    }

    this._clock = value;

    if (this._clock != null) {
      this._clock!.add(this);
    }

    for (final slot in this._slots) {
      final childArmature = slot.childArmature;
      if (childArmature != null) {
        childArmature.clock = this._clock;
      }
    }
  }

  /// - Get the parent slot which the armature belongs to.
  Slot? get parent => this._parent;
  set parent(Slot? value) => this._parent = value;
}
