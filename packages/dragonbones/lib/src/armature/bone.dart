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

/// - A surface deform bone: a grid of vertices whose affine transform is
/// interpolated across each cell, so meshes parented to it bend and stretch
/// with the surface instead of following a single rigid matrix.
///
/// Faithful port of `.ref/dragonBones-ts/armature/Surface.ts`.
class Surface extends Bone {
  static final Point _helpPoint = Point();
  static final Matrix _helpMatrix = Matrix();
  static final Transform _helpTransform = Transform();

  final List<double> _vertices = <double>[];
  final List<double> _deformVertices = <double>[];

  /// `x1, y1, x2, y2, x3, y3, x4, y4, d1X, d1Y, d2X, d2Y`.
  final List<double> _hullCache = <double>[];

  /// `[flag, a, b, c, d, tx, ty]` per cell: inside and outside.
  final List<double> _matrixCahce = <double>[];

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
    this._hullCache.length = 0;
    this._matrixCahce.length = 0;
    this._bone = null;
  }

  void _getAffineTransform(double x, double y, double lX, double lY, double aX, double aY, double bX, double bY,
      double cX, double cY, Transform transform, Matrix matrix, bool isDown) {
    final double dabX = bX - aX;
    final double dabY = bY - aY;
    final double dacX = cX - aX;
    final double dacY = cY - aY;

    transform.rotation = math.atan2(dabY, dabX);
    transform.skew = math.atan2(dacY, dacX) - math.pi * 0.5 - transform.rotation;

    if (isDown) {
      transform.rotation += math.pi;
    }

    transform.scaleX = math.sqrt(dabX * dabX + dabY * dabY) / lX;
    transform.scaleY = math.sqrt(dacX * dacX + dacY * dacY) / lY;
    transform.toMatrix(matrix);
    transform.x = matrix.tx = aX - (matrix.a * x + matrix.c * y);
    transform.y = matrix.ty = aY - (matrix.b * x + matrix.d * y);
  }

  void _updateVertices() {
    final data = this._armature!.armatureData.parent!;
    final geometry = (this._boneData as SurfaceData).geometry;
    final intArray = data.intArray!;
    final floatArray = data.floatArray!;
    final int vertexCount = intArray[geometry.offset + BinaryOffset.GeometryVertexCount];
    final int verticesOffset = MeshGeometryArrays._u16(intArray[geometry.offset + BinaryOffset.GeometryFloatOffset]);
    final List<double> vertices = this._vertices;
    final List<double> animationVertices = this._deformVertices;

    if (this._parent != null) {
      if (this._parent!._boneData!.type == BoneType.Surface) {
        for (var i = 0; i < vertexCount; ++i) {
          final int iD = i * 2;
          final double x = floatArray[verticesOffset + iD] + animationVertices[iD];
          final double y = floatArray[verticesOffset + iD + 1] + animationVertices[iD + 1];
          final matrix = (this._parent! as Surface)._getGlobalTransformMatrix(x, y);
          vertices[iD] = matrix.a * x + matrix.c * y + matrix.tx;
          vertices[iD + 1] = matrix.b * x + matrix.d * y + matrix.ty;
        }
      } else {
        final parentMatrix = this._parent!.globalTransformMatrix;

        for (var i = 0; i < vertexCount; ++i) {
          final int iD = i * 2;
          final double x = floatArray[verticesOffset + iD] + animationVertices[iD];
          final double y = floatArray[verticesOffset + iD + 1] + animationVertices[iD + 1];
          vertices[iD] = parentMatrix.a * x + parentMatrix.c * y + parentMatrix.tx;
          vertices[iD + 1] = parentMatrix.b * x + parentMatrix.d * y + parentMatrix.ty;
        }
      }
    } else {
      for (var i = 0; i < vertexCount; ++i) {
        final int iD = i * 2;
        vertices[iD] = floatArray[verticesOffset + iD] + animationVertices[iD];
        vertices[iD + 1] = floatArray[verticesOffset + iD + 1] + animationVertices[iD + 1];
      }
    }
  }

  @override
  void _updateGlobalTransformMatrix(bool isCache) {
    // The surface's own transform is the affine transform of the middle cell of
    // its hull, not the usual bone composition.
    final int segmentXD = (this._boneData as SurfaceData).segmentX * 2;
    final int lastIndex = this._vertices.length - 2;
    const double lA = 200.0;

    final double raX = this._vertices[0];
    final double raY = this._vertices[1];
    final double rbX = this._vertices[segmentXD];
    final double rbY = this._vertices[segmentXD + 1];
    final double rcX = this._vertices[lastIndex];
    final double rcY = this._vertices[lastIndex + 1];
    final double rdX = this._vertices[lastIndex - segmentXD];
    final double rdY = this._vertices[lastIndex - segmentXD + 1];

    final double dacX = raX + (rcX - raX) * 0.5;
    final double dacY = raY + (rcY - raY) * 0.5;
    final double dbdX = rbX + (rdX - rbX) * 0.5;
    final double dbdY = rbY + (rdY - rbY) * 0.5;
    final double aX = dacX + (dbdX - dacX) * 0.5;
    final double aY = dacY + (dbdY - dacY) * 0.5;
    final double bX = rbX + (rcX - rbX) * 0.5;
    final double bY = rbY + (rcY - rbY) * 0.5;
    final double cX = rdX + (rcX - rdX) * 0.5;
    final double cY = rdY + (rcY - rdY) * 0.5;

    this._getAffineTransform(0.0, 0.0, lA, lA, aX, aY, bX, bY, cX, cY, this.global, this.globalTransformMatrix, false);
    this._globalDirty = false;
  }

  /// The affine transform of the surface cell that contains `(x, y)`, with
  /// [globalTransformMatrix] as the fallback outside the hull.
  Matrix _getGlobalTransformMatrix(double x, double y) {
    const double lA = 200.0;
    const double lB = 1000.0;

    if (x < -lB || lB < x || y < -lB || lB < y) {
      return this.globalTransformMatrix;
    }

    var isDown = false;
    final surfaceData = this._boneData as SurfaceData;
    final int segmentX = surfaceData.segmentX;
    final int segmentY = surfaceData.segmentY;
    final int segmentXD = surfaceData.segmentX * 2;
    final double dX = this._dX;
    final double dY = this._dY;
    final int indexX = ((x + lA) / dX).floor(); // -1 ~ segmentX - 1
    final int indexY = ((y + lA) / dY).floor(); // -1 ~ segmentY - 1
    var matrixIndex = 0;
    final double pX = indexX * dX - lA;
    final double pY = indexY * dY - lA;

    final matrices = this._matrixCahce;
    final helpMatrix = Surface._helpMatrix;

    if (x < -lA) {
      if (y < -lA || y >= lA) {
        // Out.
        return this.globalTransformMatrix;
      }

      // Left.
      isDown = y > this._kX * (x + lA) + pY;
      matrixIndex = ((segmentX * segmentY + segmentX + segmentY + segmentY + indexY) * 2 + (isDown ? 1 : 0)) * 7;

      if (matrices[matrixIndex] > 0.0) {
        helpMatrix.copyFromArray(matrices, matrixIndex + 1);
      } else {
        final int vertexIndex = indexY * (segmentXD + 2);
        final double ddX = this._hullCache[4];
        final double ddY = this._hullCache[5];
        final double sX = this._hullCache[2] - (segmentY - indexY) * ddX;
        final double sY = this._hullCache[3] - (segmentY - indexY) * ddY;
        final vertices = this._vertices;

        if (isDown) {
          this._getAffineTransform(
              -lA,
              pY + dY,
              lB - lA,
              dY,
              vertices[vertexIndex + segmentXD + 2],
              vertices[vertexIndex + segmentXD + 3],
              sX + ddX,
              sY + ddY,
              vertices[vertexIndex],
              vertices[vertexIndex + 1],
              Surface._helpTransform,
              helpMatrix,
              true);
        } else {
          this._getAffineTransform(-lB, pY, lB - lA, dY, sX, sY, vertices[vertexIndex], vertices[vertexIndex + 1],
              sX + ddX, sY + ddY, Surface._helpTransform, helpMatrix, false);
        }

        matrices[matrixIndex] = 1.0;
        matrices[matrixIndex + 1] = helpMatrix.a;
        matrices[matrixIndex + 2] = helpMatrix.b;
        matrices[matrixIndex + 3] = helpMatrix.c;
        matrices[matrixIndex + 4] = helpMatrix.d;
        matrices[matrixIndex + 5] = helpMatrix.tx;
        matrices[matrixIndex + 6] = helpMatrix.ty;
      }
    } else if (x >= lA) {
      if (y < -lA || y >= lA) {
        // Out.
        return this.globalTransformMatrix;
      }

      // Right.
      isDown = y > this._kX * (x - lB) + pY;
      matrixIndex = ((segmentX * segmentY + segmentX + indexY) * 2 + (isDown ? 1 : 0)) * 7;

      if (matrices[matrixIndex] > 0.0) {
        helpMatrix.copyFromArray(matrices, matrixIndex + 1);
      } else {
        final int vertexIndex = (indexY + 1) * (segmentXD + 2) - 2;
        final double ddX = this._hullCache[4];
        final double ddY = this._hullCache[5];
        final double sX = this._hullCache[0] + indexY * ddX;
        final double sY = this._hullCache[1] + indexY * ddY;
        final vertices = this._vertices;

        if (isDown) {
          this._getAffineTransform(lB, pY + dY, lB - lA, dY, sX + ddX, sY + ddY, vertices[vertexIndex + segmentXD + 2],
              vertices[vertexIndex + segmentXD + 3], sX, sY, Surface._helpTransform, helpMatrix, true);
        } else {
          this._getAffineTransform(
              lA,
              pY,
              lB - lA,
              dY,
              vertices[vertexIndex],
              vertices[vertexIndex + 1],
              sX,
              sY,
              vertices[vertexIndex + segmentXD + 2],
              vertices[vertexIndex + segmentXD + 3],
              Surface._helpTransform,
              helpMatrix,
              false);
        }

        matrices[matrixIndex] = 1.0;
        matrices[matrixIndex + 1] = helpMatrix.a;
        matrices[matrixIndex + 2] = helpMatrix.b;
        matrices[matrixIndex + 3] = helpMatrix.c;
        matrices[matrixIndex + 4] = helpMatrix.d;
        matrices[matrixIndex + 5] = helpMatrix.tx;
        matrices[matrixIndex + 6] = helpMatrix.ty;
      }
    } else if (y < -lA) {
      if (x < -lA || x >= lA) {
        // Out.
        return this.globalTransformMatrix;
      }

      // Up.
      isDown = y > this._kY * (x - pX - dX) - lB;
      matrixIndex = ((segmentX * segmentY + segmentX + indexX) * 2 + (isDown ? 1 : 0)) * 7;

      if (matrices[matrixIndex] > 0.0) {
        helpMatrix.copyFromArray(matrices, matrixIndex + 1);
      } else {
        final int vertexIndex = indexX * 2;
        final double ddX = this._hullCache[10];
        final double ddY = this._hullCache[11];
        final double sX = this._hullCache[8] + indexX * ddX;
        final double sY = this._hullCache[9] + indexX * ddY;
        final vertices = this._vertices;

        if (isDown) {
          this._getAffineTransform(
              pX + dX,
              -lA,
              dX,
              lB - lA,
              vertices[vertexIndex + 2],
              vertices[vertexIndex + 3],
              vertices[vertexIndex],
              vertices[vertexIndex + 1],
              sX + ddX,
              sY + ddY,
              Surface._helpTransform,
              helpMatrix,
              true);
        } else {
          this._getAffineTransform(pX, -lB, dX, lB - lA, sX, sY, sX + ddX, sY + ddY, vertices[vertexIndex],
              vertices[vertexIndex + 1], Surface._helpTransform, helpMatrix, false);
        }

        matrices[matrixIndex] = 1.0;
        matrices[matrixIndex + 1] = helpMatrix.a;
        matrices[matrixIndex + 2] = helpMatrix.b;
        matrices[matrixIndex + 3] = helpMatrix.c;
        matrices[matrixIndex + 4] = helpMatrix.d;
        matrices[matrixIndex + 5] = helpMatrix.tx;
        matrices[matrixIndex + 6] = helpMatrix.ty;
      }
    } else if (y >= lA) {
      if (x < -lA || x >= lA) {
        // Out.
        return this.globalTransformMatrix;
      }

      // Down.
      isDown = y > this._kY * (x - pX - dX) + lA;
      matrixIndex = ((segmentX * segmentY + segmentX + segmentY + indexX) * 2 + (isDown ? 1 : 0)) * 7;

      if (matrices[matrixIndex] > 0.0) {
        helpMatrix.copyFromArray(matrices, matrixIndex + 1);
      } else {
        final int vertexIndex = segmentY * (segmentXD + 2) + indexX * 2;
        final double ddX = this._hullCache[10];
        final double ddY = this._hullCache[11];
        final double sX = this._hullCache[6] - (segmentX - indexX) * ddX;
        final double sY = this._hullCache[7] - (segmentX - indexX) * ddY;
        final vertices = this._vertices;

        if (isDown) {
          this._getAffineTransform(pX + dX, lB, dX, lB - lA, sX + ddX, sY + ddY, sX, sY, vertices[vertexIndex + 2],
              vertices[vertexIndex + 3], Surface._helpTransform, helpMatrix, true);
        } else {
          this._getAffineTransform(pX, lA, dX, lB - lA, vertices[vertexIndex], vertices[vertexIndex + 1],
              vertices[vertexIndex + 2], vertices[vertexIndex + 3], sX, sY, Surface._helpTransform, helpMatrix, false);
        }

        matrices[matrixIndex] = 1.0;
        matrices[matrixIndex + 1] = helpMatrix.a;
        matrices[matrixIndex + 2] = helpMatrix.b;
        matrices[matrixIndex + 3] = helpMatrix.c;
        matrices[matrixIndex + 4] = helpMatrix.d;
        matrices[matrixIndex + 5] = helpMatrix.tx;
        matrices[matrixIndex + 6] = helpMatrix.ty;
      }
    } else {
      // Center.
      isDown = y > this._k * (x - pX - dX) + pY;
      matrixIndex = ((segmentX * indexY + indexX) * 2 + (isDown ? 1 : 0)) * 7;

      if (matrices[matrixIndex] > 0.0) {
        helpMatrix.copyFromArray(matrices, matrixIndex + 1);
      } else {
        final int vertexIndex = indexX * 2 + indexY * (segmentXD + 2);
        final vertices = this._vertices;

        if (isDown) {
          this._getAffineTransform(
              pX + dX,
              pY + dY,
              dX,
              dY,
              vertices[vertexIndex + segmentXD + 4],
              vertices[vertexIndex + segmentXD + 5],
              vertices[vertexIndex + segmentXD + 2],
              vertices[vertexIndex + segmentXD + 3],
              vertices[vertexIndex + 2],
              vertices[vertexIndex + 3],
              Surface._helpTransform,
              helpMatrix,
              true);
        } else {
          this._getAffineTransform(
              pX,
              pY,
              dX,
              dY,
              vertices[vertexIndex],
              vertices[vertexIndex + 1],
              vertices[vertexIndex + 2],
              vertices[vertexIndex + 3],
              vertices[vertexIndex + segmentXD + 2],
              vertices[vertexIndex + segmentXD + 3],
              Surface._helpTransform,
              helpMatrix,
              false);
        }

        matrices[matrixIndex] = 1.0;
        matrices[matrixIndex + 1] = helpMatrix.a;
        matrices[matrixIndex + 2] = helpMatrix.b;
        matrices[matrixIndex + 3] = helpMatrix.c;
        matrices[matrixIndex + 4] = helpMatrix.d;
        matrices[matrixIndex + 5] = helpMatrix.tx;
        matrices[matrixIndex + 6] = helpMatrix.ty;
      }
    }

    return helpMatrix;
  }

  @override
  void init(BoneData boneData, Armature armatureValue) {
    if (this._boneData != null) {
      return;
    }

    super.init(boneData, armatureValue);

    final surfaceData = boneData as SurfaceData;
    final int segmentX = surfaceData.segmentX;
    final int segmentY = surfaceData.segmentY;
    final int vertexCount =
        this._armature!.armatureData.parent!.intArray![surfaceData.geometry.offset + BinaryOffset.GeometryVertexCount];
    const double lB = 1000.0;
    const double lA = 200.0;

    this._dX = lA * 2.0 / segmentX;
    this._dY = lA * 2.0 / segmentY;
    this._k = -this._dY / this._dX;
    this._kX = -this._dY / (lB - lA);
    this._kY = -(lB - lA) / this._dX;

    // Dart cannot grow a `List<double>` with `length =` (it would fill with
    // null, which the non-nullable element type rejects), so allocate explicitly.
    this._vertices.clear();
    this._deformVertices.clear();
    this._matrixCahce.clear();
    this._hullCache.length = 0;

    for (var i = 0, l = vertexCount * 2; i < l; ++i) {
      this._vertices.add(0.0);
      this._deformVertices.add(0.0);
    }

    for (var i = 0, l = (segmentX * segmentY + segmentX * 2 + segmentY * 2) * 2 * 7; i < l; ++i) {
      this._matrixCahce.add(0.0);
    }

    for (var i = 0; i < 12; ++i) {
      this._hullCache.add(0.0);
    }

    if (this._parent != null) {
      if (this._parent!.boneData.type == BoneType.Bone) {
        this._bone = this._parent;
      } else {
        this._bone = (this._parent! as Surface)._bone;
      }
    }
  }

  @override
  void update(int cacheFrameIndex) {
    if (cacheFrameIndex >= 0 && this._cachedFrameIndices != null) {
      final int cachedFrameIndex = this._cachedFrameIndices![cacheFrameIndex];

      if (cachedFrameIndex >= 0 && this._cachedFrameIndex == cachedFrameIndex) {
        // Same cache.
        this._transformDirty = false;
      } else if (cachedFrameIndex >= 0) {
        // Has been cached.
        this._transformDirty = true;
        this._cachedFrameIndex = cachedFrameIndex;
      } else {
        if (this._hasConstraint) {
          for (final constraint in this._armature!._constraints) {
            if (constraint._root == this) {
              constraint.update();
            }
          }
        }

        if (this._transformDirty || (this._parent != null && this._parent!._childrenTransformDirty)) {
          this._transformDirty = true;
          this._cachedFrameIndex = -1;
        } else if (this._cachedFrameIndex >= 0) {
          // Same cache, but not set index yet.
          this._transformDirty = false;
          this._cachedFrameIndices![cacheFrameIndex] = this._cachedFrameIndex;
        } else {
          this._transformDirty = true;
          this._cachedFrameIndex = -1;
        }
      }
    } else {
      if (this._hasConstraint) {
        for (final constraint in this._armature!._constraints) {
          if (constraint._root == this) {
            constraint.update();
          }
        }
      }

      if (this._transformDirty || (this._parent != null && this._parent!._childrenTransformDirty)) {
        cacheFrameIndex = -1;
        this._transformDirty = true;
        this._cachedFrameIndex = -1;
      }
    }

    if (this._transformDirty) {
      this._transformDirty = false;
      this._childrenTransformDirty = true;

      for (var i = 0, l = this._matrixCahce.length; i < l; i += 7) {
        this._matrixCahce[i] = -1.0;
      }

      this._updateVertices();

      if (this._cachedFrameIndex < 0) {
        final bool isCache = cacheFrameIndex >= 0;

        if (this._localDirty) {
          this._updateGlobalTransformMatrix(isCache);
        }

        if (isCache && this._cachedFrameIndices != null) {
          this._cachedFrameIndex = this._cachedFrameIndices![cacheFrameIndex] =
              this._armature!.armatureData.setCacheFrame(this.globalTransformMatrix, this.global);
        }
      } else {
        this._armature!.armatureData.getCacheFrame(this.globalTransformMatrix, this.global, this._cachedFrameIndex);
      }

      // Update hull vertices.
      const double lB = 1000.0;
      const double lA = 200.0;
      final double ddX = 2 * this.global.x;
      final double ddY = 2 * this.global.y;
      final helpPoint = Surface._helpPoint;

      this.globalTransformMatrix.transformPoint(lB, -lA, helpPoint);
      this._hullCache[0] = helpPoint.x;
      this._hullCache[1] = helpPoint.y;
      this._hullCache[2] = ddX - helpPoint.x;
      this._hullCache[3] = ddY - helpPoint.y;
      this.globalTransformMatrix.transformPoint(0.0, this._dY, helpPoint, true);
      this._hullCache[4] = helpPoint.x;
      this._hullCache[5] = helpPoint.y;

      this.globalTransformMatrix.transformPoint(lA, lB, helpPoint);
      this._hullCache[6] = helpPoint.x;
      this._hullCache[7] = helpPoint.y;
      this._hullCache[8] = ddX - helpPoint.x;
      this._hullCache[9] = ddY - helpPoint.y;
      this.globalTransformMatrix.transformPoint(this._dX, 0.0, helpPoint, true);
      this._hullCache[10] = helpPoint.x;
      this._hullCache[11] = helpPoint.y;
    } else if (this._childrenTransformDirty) {
      this._childrenTransformDirty = false;
    }

    this._localDirty = true;
  }
}
