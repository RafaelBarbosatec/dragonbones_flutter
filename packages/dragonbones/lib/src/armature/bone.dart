part of '../../dragonbones.dart';

/// - Bone is one of the most important logical units in the armature animation
/// system, and is responsible for the realization of translate, rotation,
/// scaling in the animations. An armature can contain multiple bones.
///
/// Faithful port of `.ref/dragonBones-ts/armature/Bone.ts`.
class Bone extends TransformObject {
  /// - The offset mode.
  int offsetMode = OffsetMode.Additive;

  /// @internal
  final Transform animationPose = Transform();

  /// @internal
  bool _transformDirty = false;

  /// @internal
  bool _childrenTransformDirty = false;

  bool _localDirty = true;

  /// @internal
  bool _hasConstraint = false;

  bool _visible = true;
  int _cachedFrameIndex = -1;

  /// @internal
  BoneData? _boneData;

  /// @private
  Bone? _parent;

  /// @internal
  List<int>? _cachedFrameIndices;

  @override
  void _onClear() {
    super._onClear();

    this.offsetMode = OffsetMode.Additive;
    this.animationPose.identity();

    this._transformDirty = false;
    this._childrenTransformDirty = false;
    this._localDirty = true;
    this._hasConstraint = false;
    this._visible = true;
    this._cachedFrameIndex = -1;
    this._boneData = null;
    this._parent = null;
    this._cachedFrameIndices = null;
  }

  void _updateGlobalTransformMatrix(bool isCache) {
    final BoneData boneData = this._boneData!;
    final Transform global = this.global;
    final Matrix globalTransformMatrix = this.globalTransformMatrix;
    final Transform? origin = this.origin;
    final Transform offset = this.offset;
    final Transform animationPose = this.animationPose;
    final Bone? parent = this._parent;

    final bool flipX = this._armature!.flipX;
    final bool flipY = this._armature!.flipY == DragonBones.yDown;
    bool inherit = parent != null;
    double rotation = 0.0;

    if (this.offsetMode == OffsetMode.Additive) {
      if (origin != null) {
        // global.copyFrom(this.origin).add(this.offset).add(this.animationPose);
        global.x = origin.x + offset.x + animationPose.x;
        global.scaleX = origin.scaleX * offset.scaleX * animationPose.scaleX;
        global.scaleY = origin.scaleY * offset.scaleY * animationPose.scaleY;

        if (DragonBones.yDown) {
          global.y = origin.y + offset.y + animationPose.y;
          global.skew = origin.skew + offset.skew + animationPose.skew;
          global.rotation = origin.rotation + offset.rotation + animationPose.rotation;
        } else {
          global.y = origin.y - offset.y + animationPose.y;
          global.skew = origin.skew - offset.skew + animationPose.skew;
          global.rotation = origin.rotation - offset.rotation + animationPose.rotation;
        }
      } else {
        global.copyFrom(offset);

        if (!DragonBones.yDown) {
          global.y = -global.y;
          global.skew = -global.skew;
          global.rotation = -global.rotation;
        }

        global.add(animationPose);
      }
    } else if (this.offsetMode == OffsetMode.None) {
      if (origin != null) {
        global.copyFrom(origin).add(animationPose);
      } else {
        global.copyFrom(animationPose);
      }
    } else {
      inherit = false;
      global.copyFrom(offset);

      if (!DragonBones.yDown) {
        global.y = -global.y;
        global.skew = -global.skew;
        global.rotation = -global.rotation;
      }
    }

    if (inherit) {
      final bool isSurface = parent!._boneData!.type == BoneType.Surface;
      final Bone? surfaceBone = isSurface ? (parent as Surface)._bone : null;
      final Matrix parentMatrix =
          isSurface ? (parent as Surface)._getGlobalTransformMatrix(global.x, global.y) : parent.globalTransformMatrix;

      if (boneData.inheritScale && (!isSurface || surfaceBone != null)) {
        if (isSurface) {
          if (boneData.inheritRotation) {
            global.rotation += parent.global.rotation;
          }

          surfaceBone!.updateGlobalTransform();
          global.scaleX *= surfaceBone.global.scaleX;
          global.scaleY *= surfaceBone.global.scaleY;
          final helper = Point();
          parentMatrix.transformPoint(global.x, global.y, helper);
          global.x = helper.x;
          global.y = helper.y;
          global.toMatrix(globalTransformMatrix);

          if (boneData.inheritTranslation) {
            global.x = globalTransformMatrix.tx;
            global.y = globalTransformMatrix.ty;
          } else {
            globalTransformMatrix.tx = global.x;
            globalTransformMatrix.ty = global.y;
          }
        } else {
          if (!boneData.inheritRotation) {
            parent.updateGlobalTransform();

            if (flipX && flipY) {
              rotation = global.rotation - (parent.global.rotation + math.pi);
            } else if (flipX) {
              rotation = global.rotation + parent.global.rotation + math.pi;
            } else if (flipY) {
              rotation = global.rotation + parent.global.rotation;
            } else {
              rotation = global.rotation - parent.global.rotation;
            }

            global.rotation = rotation;
          }

          global.toMatrix(globalTransformMatrix);
          globalTransformMatrix.concat(parentMatrix);

          if (boneData.inheritTranslation) {
            global.x = globalTransformMatrix.tx;
            global.y = globalTransformMatrix.ty;
          } else {
            globalTransformMatrix.tx = global.x;
            globalTransformMatrix.ty = global.y;
          }

          if (isCache) {
            global.fromMatrix(globalTransformMatrix);
          } else {
            this._globalDirty = true;
          }
        }
      } else {
        if (boneData.inheritTranslation) {
          final double x = global.x;
          final double y = global.y;
          global.x = parentMatrix.a * x + parentMatrix.c * y + parentMatrix.tx;
          global.y = parentMatrix.b * x + parentMatrix.d * y + parentMatrix.ty;
        } else {
          if (flipX) {
            global.x = -global.x;
          }

          if (flipY) {
            global.y = -global.y;
          }
        }

        if (boneData.inheritRotation) {
          parent.updateGlobalTransform();

          if (parent.global.scaleX < 0.0) {
            rotation = global.rotation + parent.global.rotation + math.pi;
          } else {
            rotation = global.rotation + parent.global.rotation;
          }

          if (parentMatrix.a * parentMatrix.d - parentMatrix.b * parentMatrix.c < 0.0) {
            rotation -= global.rotation * 2.0;

            if (flipX != flipY || boneData.inheritReflection) {
              global.skew += math.pi;
            }

            if (!DragonBones.yDown) {
              global.skew = -global.skew;
            }
          }

          global.rotation = rotation;
        } else if (flipX || flipY) {
          if (flipX && flipY) {
            rotation = global.rotation + math.pi;
          } else {
            if (flipX) {
              rotation = math.pi - global.rotation;
            } else {
              rotation = -global.rotation;
            }

            global.skew += math.pi;
          }

          global.rotation = rotation;
        }

        global.toMatrix(globalTransformMatrix);
      }
    } else {
      if (flipX || flipY) {
        if (flipX) {
          global.x = -global.x;
        }

        if (flipY) {
          global.y = -global.y;
        }

        if (flipX && flipY) {
          rotation = global.rotation + math.pi;
        } else {
          if (flipX) {
            rotation = math.pi - global.rotation;
          } else {
            rotation = -global.rotation;
          }

          global.skew += math.pi;
        }

        global.rotation = rotation;
      }

      global.toMatrix(globalTransformMatrix);
    }
  }

  /// @internal
  void _updateAlpha() {
    if (this._parent != null) {
      this._globalAlpha = this._alpha * this._parent!._globalAlpha;
    } else {
      this._globalAlpha = this._alpha * this._armature!._globalAlpha;
    }
  }

  /// @internal
  void init(BoneData boneData, Armature armatureValue) {
    if (this._boneData != null) {
      return;
    }

    this._boneData = boneData;
    this._armature = armatureValue;
    this._alpha = this._boneData!.alpha;

    if (this._boneData!.parent != null) {
      this._parent = this._armature!.getBone(this._boneData!.parent!.name);
    }

    this._armature!._addBone(this);
    this.origin = this._boneData!.transform;
  }

  /// @internal
  void update(int cacheFrameIndex) {
    if (cacheFrameIndex >= 0 && this._cachedFrameIndices != null) {
      final int cachedFrameIndex = this._cachedFrameIndices![cacheFrameIndex];
      if (cachedFrameIndex >= 0 && this._cachedFrameIndex == cachedFrameIndex) {
        // Same cache.
        this._transformDirty = false;
      } else if (cachedFrameIndex >= 0) {
        // Has been Cached.
        this._transformDirty = true;
        this._cachedFrameIndex = cachedFrameIndex;
      } else {
        if (this._hasConstraint) {
          // Update constraints.
          for (final constraint in this._armature!._constraints) {
            if (constraint._root == this) {
              constraint.update();
            }
          }
        }

        if (this._transformDirty || (this._parent != null && this._parent!._childrenTransformDirty)) {
          // Dirty.
          this._transformDirty = true;
          this._cachedFrameIndex = -1;
        } else if (this._cachedFrameIndex >= 0) {
          // Same cache, but not set index yet.
          this._transformDirty = false;
          this._cachedFrameIndices![cacheFrameIndex] = this._cachedFrameIndex;
        } else {
          // Dirty.
          this._transformDirty = true;
          this._cachedFrameIndex = -1;
        }
      }
    } else {
      if (this._hasConstraint) {
        // Update constraints.
        for (final constraint in this._armature!._constraints) {
          if (constraint._root == this) {
            constraint.update();
          }
        }
      }

      if (this._transformDirty || (this._parent != null && this._parent!._childrenTransformDirty)) {
        // Dirty.
        cacheFrameIndex = -1;
        this._transformDirty = true;
        this._cachedFrameIndex = -1;
      }
    }

    if (this._transformDirty) {
      this._transformDirty = false;
      this._childrenTransformDirty = true;
      //
      if (this._cachedFrameIndex < 0) {
        final bool isCache = cacheFrameIndex >= 0;
        if (this._localDirty) {
          this._updateGlobalTransformMatrix(isCache);
        }

        if (isCache && this._cachedFrameIndices != null) {
          this._cachedFrameIndex = this._cachedFrameIndices![cacheFrameIndex] =
              this._armature!._armatureData!.setCacheFrame(this.globalTransformMatrix, this.global);
        }
      } else {
        this._armature!._armatureData!.getCacheFrame(this.globalTransformMatrix, this.global, this._cachedFrameIndex);
      }
      //
    } else if (this._childrenTransformDirty) {
      this._childrenTransformDirty = false;
    }

    this._localDirty = true;
  }

  /// @internal
  void updateByConstraint() {
    if (this._localDirty) {
      this._localDirty = false;

      if (this._transformDirty || (this._parent != null && this._parent!._childrenTransformDirty)) {
        this._updateGlobalTransformMatrix(true);
      }

      this._transformDirty = true;
    }
  }

  /// - Forces the bone to update the transform in the next frame.
  void invalidUpdate() {
    this._transformDirty = true;
  }

  /// - Check whether the bone contains a specific bone.
  bool contains(Bone value) {
    if (value == this) {
      return false;
    }

    Bone? ancestor = value;
    while (ancestor != this && ancestor != null) {
      ancestor = ancestor.parent;
    }

    return ancestor == this;
  }

  /// - The bone data.
  BoneData get boneData => this._boneData!;

  /// - The visible of all slots in the bone.
  bool get visible => this._visible;
  set visible(bool value) {
    if (this._visible == value) {
      return;
    }

    this._visible = value;

    for (final slot in this._armature!.getSlots()) {
      if (slot.parent == this) {
        slot._updateVisible();
      }
    }
  }

  /// - The bone name.
  String get name => this._boneData!.name;

  /// - The parent bone to which it belongs.
  Bone? get parent => this._parent;
}

/// - A surface deform bone (milestone 2 placeholder: the vertex/deform math is
/// not ported; only the pieces referenced by [Bone] are provided so the
/// compilation unit is complete). Surface bones are never built for the
/// milestone-1 fixtures.
///
/// Faithful port of `.ref/dragonBones-ts/armature/Surface.ts` (partial).
class Surface extends Bone {
  final List<double> _vertices = <double>[];
  final List<double> _deformVertices = <double>[];

  Bone? _bone;

  double _dX = 0.0;
  double _dY = 0.0;
  double _k = 0.0;
  double _kX = 0.0;
  double _kY = 0.0;

  @override
  void _onClear() {
    super._onClear();

    this._dX = 0.0;
    this._dY = 0.0;
    this._k = 0.0;
    this._kX = 0.0;
    this._kY = 0.0;
    this._vertices.length = 0;
    this._deformVertices.length = 0;
    this._bone = null;
  }

  @override
  void _updateGlobalTransformMatrix(bool isCache) {
    // Milestone 2. Fall back to the plain bone path so the class is usable.
    super._updateGlobalTransformMatrix(isCache);
  }

  Matrix _getGlobalTransformMatrix(double x, double y) {
    // Milestone 2 (surface deformation). Out-of-range points already fall back
    // to the global matrix upstream; surfaces are unsupported in milestone 1.
    return this.globalTransformMatrix;
  }
}
