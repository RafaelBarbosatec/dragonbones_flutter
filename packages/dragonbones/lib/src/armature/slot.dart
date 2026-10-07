part of '../../dragonbones.dart';

/// @private
class DisplayFrame extends BaseObject {
  DisplayData? rawDisplayData;
  DisplayData? displayData;
  TextureData? textureData;
  Object? display;
  final List<double> deformVertices = <double>[];

  @override
  void _onClear() {
    this.rawDisplayData = null;
    this.displayData = null;
    this.textureData = null;
    this.display = null;
    this.deformVertices.length = 0;
  }

  void updateDeformVertices() {
    if (this.rawDisplayData == null || this.deformVertices.isNotEmpty) {
      return;
    }

    GeometryData rawGeometryData;
    if (this.rawDisplayData!.type == DisplayType.Mesh) {
      rawGeometryData = (this.rawDisplayData! as MeshDisplayData).geometry;
    } else if (this.rawDisplayData!.type == DisplayType.Path) {
      rawGeometryData = (this.rawDisplayData! as PathDisplayData).geometry;
    } else {
      return;
    }

    int vertexCount;
    if (rawGeometryData.weight != null) {
      vertexCount = rawGeometryData.weight!.count * 2;
    } else {
      vertexCount = rawGeometryData.data!.intArray![rawGeometryData.offset + BinaryOffset.GeometryVertexCount] * 2;
    }

    // NOTE: upstream does `this.deformVertices.length = vertexCount` (JS fills
    // holes with undefined). Dart cannot grow a List<double> that way, so build
    // it explicitly.
    this.deformVertices.clear();
    for (var i = 0; i < vertexCount; ++i) {
      this.deformVertices.add(0.0);
    }
  }

  GeometryData? getGeometryData() {
    if (this.displayData != null) {
      if (this.displayData!.type == DisplayType.Mesh) {
        return (this.displayData! as MeshDisplayData).geometry;
      }

      if (this.displayData!.type == DisplayType.Path) {
        return (this.displayData! as PathDisplayData).geometry;
      }
    }

    if (this.rawDisplayData != null) {
      if (this.rawDisplayData!.type == DisplayType.Mesh) {
        return (this.rawDisplayData! as MeshDisplayData).geometry;
      }

      if (this.rawDisplayData!.type == DisplayType.Path) {
        return (this.rawDisplayData! as PathDisplayData).geometry;
      }
    }

    return null;
  }

  BoundingBoxData? getBoundingBox() {
    if (this.displayData != null && this.displayData!.type == DisplayType.BoundingBox) {
      return (this.displayData! as BoundingBoxDisplayData).boundingBox;
    }

    if (this.rawDisplayData != null && this.rawDisplayData!.type == DisplayType.BoundingBox) {
      return (this.rawDisplayData! as BoundingBoxDisplayData).boundingBox;
    }

    return null;
  }

  TextureData? getTextureData() {
    if (this.displayData != null) {
      if (this.displayData!.type == DisplayType.Image) {
        return (this.displayData! as ImageDisplayData).texture;
      }

      if (this.displayData!.type == DisplayType.Mesh) {
        return (this.displayData! as MeshDisplayData).texture;
      }
    }

    if (this.textureData != null) {
      return this.textureData;
    }

    if (this.rawDisplayData != null) {
      if (this.rawDisplayData!.type == DisplayType.Image) {
        return (this.rawDisplayData! as ImageDisplayData).texture;
      }

      if (this.rawDisplayData!.type == DisplayType.Mesh) {
        return (this.rawDisplayData! as MeshDisplayData).texture;
      }
    }

    return null;
  }
}

/// - The slot attached to the armature, controls the display status and
/// properties of the display object. A bone can contain multiple slots.
///
/// Faithful port of `.ref/dragonBones-ts/armature/Slot.ts`. The engine-side
/// render hooks are abstract; a concrete headless subclass supplies no-ops
/// (mirroring `tool/ground_truth/dump.js`).
abstract class Slot extends TransformObject {
  /// - Displays the animated state or mixed group name controlled by the object.
  String? displayController;

  bool _displayDataDirty = false;
  bool _displayDirty = false;
  bool _geometryDirty = false;
  bool _textureDirty = false;
  bool _visibleDirty = false;
  bool _blendModeDirty = false;
  bool _zOrderDirty = false;

  /// @internal
  bool _colorDirty = false;

  /// @internal
  bool _verticesDirty = false;

  bool _transformDirty = false;
  bool _visible = true;
  int _blendMode = BlendMode.Normal;
  int _displayIndex = -1;
  int _animationDisplayIndex = -1;
  int _cachedFrameIndex = -1;

  /// @internal
  int _zOrder = 0;

  /// @internal
  int _zIndex = 0;

  /// @internal
  double _pivotX = 0.0;

  /// @internal
  double _pivotY = 0.0;

  final Matrix _localMatrix = Matrix();

  /// @internal
  final ColorTransform _colorTransform = ColorTransform();

  /// @internal
  final List<DisplayFrame> _displayFrames = <DisplayFrame>[];

  /// @internal
  final List<Bone?> _geometryBones = <Bone?>[];

  /// @internal
  SlotData? _slotData;

  /// @internal
  DisplayFrame? _displayFrame;

  /// @internal
  GeometryData? _geometryData;

  BoundingBoxData? _boundingBoxData;
  TextureData? _textureData;
  Object? _rawDisplay;
  Object? _meshDisplay;
  Object? _display;

  Armature? _childArmature;

  /// @private
  Bone? _parent;

  /// @internal
  List<int>? _cachedFrameIndices;

  // ---- engine-side render hooks (abstract) ----------------------------------
  void _initDisplay(Object? value, bool isRetain);
  void _disposeDisplay(Object? value, bool isRelease);
  void _onUpdateDisplay();
  void _addDisplay();
  void _replaceDisplay(Object? value);
  void _removeDisplay();
  void _updateZOrder();

  /// @internal
  void _updateVisible();
  void _updateBlendMode();
  void _updateColor();
  void _updateFrame();
  void _updateMesh();
  void _updateTransform();
  void _identityTransform();

  @override
  void _onClear() {
    super._onClear();

    final List<Object?> disposeDisplayList = <Object?>[];
    for (final displayFrame in this._displayFrames) {
      final Object? display = displayFrame.display;
      if (display != this._rawDisplay && display != this._meshDisplay && disposeDisplayList.indexOf(display) < 0) {
        disposeDisplayList.add(display);
      }

      displayFrame.returnToPool();
    }

    for (final eachDisplay in disposeDisplayList) {
      if (eachDisplay is Armature) {
        eachDisplay.dispose();
      } else {
        this._disposeDisplay(eachDisplay, true);
      }
    }

    if (this._meshDisplay != null && this._meshDisplay != this._rawDisplay) {
      this._disposeDisplay(this._meshDisplay, false);
    }

    if (this._rawDisplay != null) {
      this._disposeDisplay(this._rawDisplay, false);
    }

    this.displayController = null;

    this._displayDataDirty = false;
    this._displayDirty = false;
    this._geometryDirty = false;
    this._textureDirty = false;
    this._visibleDirty = false;
    this._blendModeDirty = false;
    this._zOrderDirty = false;
    this._colorDirty = false;
    this._verticesDirty = false;
    this._transformDirty = false;
    this._visible = true;
    this._blendMode = BlendMode.Normal;
    this._displayIndex = -1;
    this._animationDisplayIndex = -1;
    this._zOrder = 0;
    this._zIndex = 0;
    this._cachedFrameIndex = -1;
    this._pivotX = 0.0;
    this._pivotY = 0.0;
    this._localMatrix.identity();
    this._colorTransform.identity();
    this._displayFrames.length = 0;
    this._geometryBones.length = 0;
    this._slotData = null;
    this._displayFrame = null;
    this._geometryData = null;
    this._boundingBoxData = null;
    this._textureData = null;
    this._rawDisplay = null;
    this._meshDisplay = null;
    this._display = null;
    this._childArmature = null;
    this._parent = null;
    this._cachedFrameIndices = null;
  }

  bool _hasDisplay(Object? display) {
    for (final displayFrame in this._displayFrames) {
      if (displayFrame.display == display) {
        return true;
      }
    }

    return false;
  }

  /// @internal
  bool _isBonesUpdate() {
    for (final bone in this._geometryBones) {
      if (bone != null && bone._childrenTransformDirty) {
        return true;
      }
    }

    return false;
  }

  /// @internal
  void _updateAlpha() {
    final double globalAlpha = this._alpha * this._parent!._globalAlpha;

    if (this._globalAlpha != globalAlpha) {
      this._globalAlpha = globalAlpha;
      this._colorDirty = true;
    }
  }

  void _updateDisplayData() {
    final DisplayFrame? prevDisplayFrame = this._displayFrame;
    final GeometryData? prevGeometryData = this._geometryData;
    final TextureData? prevTextureData = this._textureData;
    DisplayData? rawDisplayData;
    DisplayData? displayData;

    this._displayFrame = null;
    this._geometryData = null;
    this._boundingBoxData = null;
    this._textureData = null;

    if (this._displayIndex >= 0 && this._displayIndex < this._displayFrames.length) {
      this._displayFrame = this._displayFrames[this._displayIndex];
      rawDisplayData = this._displayFrame!.rawDisplayData;
      displayData = this._displayFrame!.displayData;

      this._geometryData = this._displayFrame!.getGeometryData();
      this._boundingBoxData = this._displayFrame!.getBoundingBox();
      this._textureData = this._displayFrame!.getTextureData();
    }

    if (this._displayFrame != prevDisplayFrame ||
        this._geometryData != prevGeometryData ||
        this._textureData != prevTextureData) {
      // Update pivot offset.
      if (this._geometryData == null && this._textureData != null) {
        final ImageDisplayData imageDisplayData = ((displayData != null && displayData.type == DisplayType.Image)
            ? displayData
            : rawDisplayData!) as ImageDisplayData;
        final double scale = this._textureData!.parent!.scale * this._armature!._armatureData!.scale;
        final Rectangle? frame = this._textureData!.frame;

        this._pivotX = imageDisplayData.pivot.x;
        this._pivotY = imageDisplayData.pivot.y;

        final Rectangle rect = frame != null ? frame : this._textureData!.region;
        double width = rect.width;
        double height = rect.height;

        if (this._textureData!.rotated && frame == null) {
          width = rect.height;
          height = rect.width;
        }

        this._pivotX *= width * scale;
        this._pivotY *= height * scale;

        if (frame != null) {
          this._pivotX += frame.x * scale;
          this._pivotY += frame.y * scale;
        }

        if (rawDisplayData != null && imageDisplayData != rawDisplayData) {
          rawDisplayData.transform.toMatrix(TransformObject._helpMatrix);
          TransformObject._helpMatrix.invert();
          TransformObject._helpMatrix.transformPoint(0.0, 0.0, TransformObject._helpPoint);
          this._pivotX -= TransformObject._helpPoint.x;
          this._pivotY -= TransformObject._helpPoint.y;

          imageDisplayData.transform.toMatrix(TransformObject._helpMatrix);
          TransformObject._helpMatrix.invert();
          TransformObject._helpMatrix.transformPoint(0.0, 0.0, TransformObject._helpPoint);
          this._pivotX += TransformObject._helpPoint.x;
          this._pivotY += TransformObject._helpPoint.y;
        }

        if (!DragonBones.yDown) {
          this._pivotY =
              (this._textureData!.rotated ? this._textureData!.region.width : this._textureData!.region.height) *
                      scale -
                  this._pivotY;
        }
      } else {
        this._pivotX = 0.0;
        this._pivotY = 0.0;
      }

      // Update original transform.
      if (rawDisplayData != null) {
        this.origin = rawDisplayData.transform;
      } else if (displayData != null) {
        this.origin = displayData.transform;
      } else {
        this.origin = null;
      }

      // TODO remove slot offset.
      if (this.origin != null) {
        this.global.copyFrom(this.origin!).add(this.offset).toMatrix(this._localMatrix);
      } else {
        this.global.copyFrom(this.offset).toMatrix(this._localMatrix);
      }

      // Update geometry.
      if (this._geometryData != prevGeometryData) {
        this._geometryDirty = true;
        this._verticesDirty = true;

        if (this._geometryData != null) {
          this._geometryBones.length = 0;
          if (this._geometryData!.weight != null) {
            for (var i = 0, l = this._geometryData!.weight!.bones.length; i < l; ++i) {
              final bone = this._armature!.getBone(this._geometryData!.weight!.bones[i].name);
              this._geometryBones.add(bone);
            }
          }
        } else {
          this._geometryBones.length = 0;
          this._geometryData = null;
        }
      }

      this._textureDirty = this._textureData != prevTextureData;
      this._transformDirty = true;
    }
  }

  void _updateDisplay() {
    final Object? prevDisplay = this._display != null ? this._display : this._rawDisplay;
    final Armature? prevChildArmature = this._childArmature;

    // Update display and child armature.
    if (this._displayFrame != null) {
      this._display = this._displayFrame!.display;
      if (this._display != null && this._display is Armature) {
        this._childArmature = this._display as Armature;
        this._display = this._childArmature!.display;
      } else {
        this._childArmature = null;
      }
    } else {
      this._display = null;
      this._childArmature = null;
    }

    // Update display.
    final Object? currentDisplay = this._display != null ? this._display : this._rawDisplay;
    if (currentDisplay != prevDisplay) {
      this._textureDirty = true;
      this._visibleDirty = true;
      this._blendModeDirty = true;
      this._colorDirty = true;
      this._transformDirty = true;

      this._onUpdateDisplay();
      this._replaceDisplay(prevDisplay);
    }

    // Update child armature.
    if (this._childArmature != prevChildArmature) {
      if (prevChildArmature != null) {
        prevChildArmature._parent = null;
        prevChildArmature.clock = null;
        if (prevChildArmature.inheritAnimation) {
          prevChildArmature.animation.reset();
        }
      }

      if (this._childArmature != null) {
        this._childArmature!._parent = this;
        this._childArmature!.clock = this._armature!.clock;
        if (this._childArmature!.inheritAnimation) {
          if (this._childArmature!.cacheFrameRate == 0) {
            final cacheFrameRate = this._armature!.cacheFrameRate;
            if (cacheFrameRate != 0) {
              this._childArmature!.cacheFrameRate = cacheFrameRate;
            }
          }

          if (this._displayFrame != null) {
            final displayData = this._displayFrame!.displayData != null
                ? this._displayFrame!.displayData
                : this._displayFrame!.rawDisplayData;
            final List<ActionData>? actions = (displayData != null && displayData.type == DisplayType.Armature)
                ? (displayData as ArmatureDisplayData).actions
                : null;

            if (actions != null && actions.isNotEmpty) {
              // Milestone 2: buffering child armature actions is not ported.
            } else {
              this._childArmature!.animation.play();
            }
          }
        }
      }
    }
  }

  void _updateGlobalTransformMatrix(bool isCache) {
    final Matrix parentMatrix = this._parent!._boneData!.type == BoneType.Bone
        ? this._parent!.globalTransformMatrix
        : (this._parent! as Surface)._getGlobalTransformMatrix(this.global.x, this.global.y);
    this.globalTransformMatrix.copyFrom(this._localMatrix);
    this.globalTransformMatrix.concat(parentMatrix);

    if (isCache) {
      this.global.fromMatrix(this.globalTransformMatrix);
    } else {
      this._globalDirty = true;
    }
  }

  /// @internal
  void _setDisplayIndex(int value, [bool isAnimation = false]) {
    if (isAnimation) {
      if (this._animationDisplayIndex == value) {
        return;
      }

      this._animationDisplayIndex = value;
    }

    if (this._displayIndex == value) {
      return;
    }

    this._displayIndex = value < this._displayFrames.length ? value : this._displayFrames.length - 1;
    this._displayDataDirty = true;
    this._displayDirty = this._displayIndex < 0 || this._display != this._displayFrames[this._displayIndex].display;
  }

  /// @internal
  bool _setZOrder(int value) {
    this._zOrder = value;
    this._zOrderDirty = true;

    return this._zOrderDirty;
  }

  /// @internal
  bool _setColor(ColorTransform value) {
    this._colorTransform.copyFrom(value);

    return this._colorDirty = true;
  }

  /// @internal
  void init(SlotData slotData, Armature armatureValue, Object? rawDisplay, Object? meshDisplay) {
    if (this._slotData != null) {
      return;
    }

    this._slotData = slotData;
    this._colorDirty = true;
    this._blendModeDirty = true;
    this._blendMode = this._slotData!.blendMode;
    this._zOrder = this._slotData!.zOrder;
    this._zIndex = this._slotData!.zIndex;
    this._alpha = this._slotData!.alpha;
    this._colorTransform.copyFrom(this._slotData!.color);
    this._rawDisplay = rawDisplay;
    this._meshDisplay = meshDisplay;
    this._armature = armatureValue;
    final slotParent = this._armature!.getBone(this._slotData!.parent!.name);

    if (slotParent != null) {
      this._parent = slotParent;
    }

    this._armature!._addSlot(this);
    this._initDisplay(this._rawDisplay, false);
    if (this._rawDisplay != this._meshDisplay) {
      this._initDisplay(this._meshDisplay, false);
    }

    this._onUpdateDisplay();
    this._addDisplay();
  }

  /// @internal
  void update(int cacheFrameIndex) {
    if (this._displayDataDirty) {
      this._updateDisplayData();
      this._displayDataDirty = false;
    }

    if (this._displayDirty) {
      this._updateDisplay();
      this._displayDirty = false;
    }

    if (this._geometryDirty || this._textureDirty) {
      if (this._display == null || this._display == this._rawDisplay || this._display == this._meshDisplay) {
        this._updateFrame();
      }

      this._geometryDirty = false;
      this._textureDirty = false;
    }

    if (this._display == null) {
      return;
    }

    if (this._visibleDirty) {
      this._updateVisible();
      this._visibleDirty = false;
    }

    if (this._blendModeDirty) {
      this._updateBlendMode();
      this._blendModeDirty = false;
    }

    if (this._colorDirty) {
      this._updateColor();
      this._colorDirty = false;
    }

    if (this._zOrderDirty) {
      this._updateZOrder();
      this._zOrderDirty = false;
    }

    if (this._geometryData != null && this._display == this._meshDisplay) {
      final bool isSkinned = this._geometryData!.weight != null;
      final bool isSurface = this._parent!._boneData!.type != BoneType.Bone;

      if (this._verticesDirty ||
          (isSkinned && this._isBonesUpdate()) ||
          (isSurface && this._parent!._childrenTransformDirty)) {
        this._verticesDirty = false;
        this._updateMesh();
      }

      if (isSkinned || isSurface) {
        return;
      }
    }

    if (cacheFrameIndex >= 0 && this._cachedFrameIndices != null) {
      final int cachedFrameIndex = this._cachedFrameIndices![cacheFrameIndex];
      if (cachedFrameIndex >= 0 && this._cachedFrameIndex == cachedFrameIndex) {
        // Same cache.
        this._transformDirty = false;
      } else if (cachedFrameIndex >= 0) {
        // Has been Cached.
        this._transformDirty = true;
        this._cachedFrameIndex = cachedFrameIndex;
      } else if (this._transformDirty || this._parent!._childrenTransformDirty) {
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
    } else if (this._transformDirty || this._parent!._childrenTransformDirty) {
      // Dirty.
      cacheFrameIndex = -1;
      this._transformDirty = true;
      this._cachedFrameIndex = -1;
    }

    if (this._transformDirty) {
      if (this._cachedFrameIndex < 0) {
        final bool isCache = cacheFrameIndex >= 0;
        this._updateGlobalTransformMatrix(isCache);

        if (isCache && this._cachedFrameIndices != null) {
          this._cachedFrameIndex = this._cachedFrameIndices![cacheFrameIndex] =
              this._armature!._armatureData!.setCacheFrame(this.globalTransformMatrix, this.global);
        }
      } else {
        this._armature!._armatureData!.getCacheFrame(this.globalTransformMatrix, this.global, this._cachedFrameIndex);
      }

      this._updateTransform();
      this._transformDirty = false;
    }
  }

  /// - Forces the slot to update the display object state next frame.
  void invalidUpdate() {
    this._displayDataDirty = true;
    this._displayDirty = true;
    this._transformDirty = true;
  }

  /// @private
  void updateTransformAndMatrix() {
    if (this._transformDirty) {
      this._updateGlobalTransformMatrix(false);
      this._transformDirty = false;
    }
  }

  /// @private
  void replaceRawDisplayData(DisplayData? displayData, [int index = -1]) {
    if (index < 0) {
      index = this._displayIndex < 0 ? 0 : this._displayIndex;
    } else if (index >= this._displayFrames.length) {
      return;
    }

    final displayFrame = this._displayFrames[index];
    if (displayFrame.rawDisplayData != displayData) {
      displayFrame.deformVertices.length = 0;
      displayFrame.rawDisplayData = displayData;
      if (displayFrame.rawDisplayData == null) {
        final defaultSkin = this._armature!._armatureData!.defaultSkin;
        if (defaultSkin != null) {
          final defaultRawDisplayDatas = defaultSkin.getDisplays(this._slotData!.name);
          if (defaultRawDisplayDatas != null && index < defaultRawDisplayDatas.length) {
            displayFrame.rawDisplayData = defaultRawDisplayDatas[index];
          }
        }
      }

      if (index == this._displayIndex) {
        this._displayDataDirty = true;
      }
    }
  }

  /// @private
  void replaceDisplayData(DisplayData? displayData, [int index = -1]) {
    if (index < 0) {
      index = this._displayIndex < 0 ? 0 : this._displayIndex;
    } else if (index >= this._displayFrames.length) {
      return;
    }

    final displayFrame = this._displayFrames[index];
    if (displayFrame.displayData != displayData && displayFrame.rawDisplayData != displayData) {
      displayFrame.displayData = displayData;

      if (index == this._displayIndex) {
        this._displayDataDirty = true;
      }
    }
  }

  /// @private
  void replaceTextureData(TextureData? textureData, [int index = -1]) {
    if (index < 0) {
      index = this._displayIndex < 0 ? 0 : this._displayIndex;
    } else if (index >= this._displayFrames.length) {
      return;
    }

    final displayFrame = this._displayFrames[index];
    if (displayFrame.textureData != textureData) {
      displayFrame.textureData = textureData;

      if (index == this._displayIndex) {
        this._displayDataDirty = true;
      }
    }
  }

  /// @private
  void replaceDisplay(Object? value, [int index = -1]) {
    if (index < 0) {
      index = this._displayIndex < 0 ? 0 : this._displayIndex;
    } else if (index >= this._displayFrames.length) {
      return;
    }

    final displayFrame = this._displayFrames[index];
    if (displayFrame.display != value) {
      final Object? prevDisplay = displayFrame.display;
      displayFrame.display = value;

      if (prevDisplay != null &&
          prevDisplay != this._rawDisplay &&
          prevDisplay != this._meshDisplay &&
          !this._hasDisplay(prevDisplay)) {
        if (prevDisplay is! Armature) {
          this._disposeDisplay(prevDisplay, true);
        }
      }

      if (value != null &&
          value != this._rawDisplay &&
          value != this._meshDisplay &&
          !this._hasDisplay(prevDisplay) &&
          value is! Armature) {
        this._initDisplay(value, true);
      }

      if (index == this._displayIndex) {
        this._displayDirty = true;
      }
    }
  }

  /// @private
  DisplayFrame getDisplayFrameAt(int index) => this._displayFrames[index];

  /// - The visible of slot's display object.
  bool get visible => this._visible;
  set visible(bool value) {
    if (this._visible == value) {
      return;
    }

    this._visible = value;
    this._updateVisible();
  }

  /// @private
  int get displayFrameCount => this._displayFrames.length;
  set displayFrameCount(int value) {
    final prevCount = this._displayFrames.length;
    if (prevCount < value) {
      // NOTE: upstream writes `this._displayFrames.length = value` first. In JS
      // that creates holes; in Dart we have to append the frames explicitly.
      for (var i = prevCount; i < value; ++i) {
        this._displayFrames.add(DisplayFrame());
      }
    } else if (prevCount > value) {
      for (var i = prevCount - 1; i >= value; --i) {
        this.replaceDisplay(null, i);
        this._displayFrames[i].returnToPool();
        this._displayFrames.removeLast();
      }
    }
  }

  /// - The index of the display object displayed in the display list.
  int get displayIndex => this._displayIndex;
  set displayIndex(int value) {
    this._setDisplayIndex(value);
    this.update(-1);
  }

  /// - The slot name.
  String get name => this._slotData!.name;

  /// - Contains a display list of display objects or child armatures.
  List<Object?> get displayList {
    final displays = <Object?>[];
    for (final displayFrame in this._displayFrames) {
      displays.add(displayFrame.display);
    }

    return displays;
  }

  set displayList(List<Object?> value) {
    this.displayFrameCount = value.length;
    var index = 0;
    for (final eachDisplay in value) {
      this.replaceDisplay(eachDisplay, index++);
    }
  }

  /// - The slot data.
  SlotData get slotData => this._slotData!;

  /// - The custom bounding box data for the slot at current time.
  BoundingBoxData? get boundingBoxData => this._boundingBoxData;

  /// @private
  Object? get rawDisplay => this._rawDisplay;

  /// @private
  Object? get meshDisplay => this._meshDisplay;

  // ---- public view for renderers -------------------------------------------
  //
  // The runtime keeps these members as they are upstream (many with a `_`
  // prefix). Renderers live outside this library, so they need a way in; these
  // getters are read-only on purpose — the runtime owns the state.

  /// The atlas entry currently displayed, or null.
  TextureData? get textureData => this._textureData;

  /// Geometry of the current display when it is a deformable mesh, else null.
  GeometryData? get geometryData => this._geometryData;

  /// The bones that skin the current mesh, in weight order.
  ///
  /// Empty for a plain mesh and for sprites. The order matters: the shared
  /// weight arrays index into this list, so it must stay as built.
  List<Bone?> get geometryBones => this._geometryBones;

  /// Animated FFD offsets of the current display frame: `2 * vertexCount`
  /// numbers, `x, y` interleaved; empty when nothing deforms the mesh.
  ///
  /// NOTE: nothing fills these yet. The parser reads the deform timelines and
  /// `DisplayFrame.updateDeformVertices()` is ported, but the animation side
  /// (`DeformTimelineState`, and the lazy call in `AnimationState`) is not — so
  /// this is always empty today and mesh deformation comes from the bone
  /// weights alone. The consumer in [buildMeshGeometry] is written for it.
  List<double> get deformVertices => this._displayFrame?.deformVertices ?? const <double>[];

  /// Anchor that sits on the slot origin, in display pixels.
  double get pivotX => this._pivotX;
  double get pivotY => this._pivotY;

  /// Draw order within the armature.
  int get zOrder => this._zOrder;

  /// DragonBones blend mode enum value (`BlendMode.Normal` is 0).
  int get blendMode => this._blendMode;

  /// Whether the slot should be drawn at all.
  bool get isVisible => this._visible;

  /// Slot colour as `[aM, rM, gM, bM, aO, rO, gO, bO]`.
  List<double> get colorValues => <double>[
        this._colorTransform.alphaMultiplier,
        this._colorTransform.redMultiplier,
        this._colorTransform.greenMultiplier,
        this._colorTransform.blueMultiplier,
        this._colorTransform.alphaOffset,
        this._colorTransform.redOffset,
        this._colorTransform.greenOffset,
        this._colorTransform.blueOffset,
      ];

  /// - The display object that the slot displays at this time.
  Object? get display => this._display;
  set display(Object? value) {
    if (this._display == value) {
      return;
    }

    if (this._displayFrames.isEmpty) {
      this.displayFrameCount = 1;
      this._displayIndex = 0;
    }

    this.replaceDisplay(value, this._displayIndex);
  }

  /// - The child armature that the slot displayed at current time.
  Armature? get childArmature => this._childArmature;
  set childArmature(Armature? value) {
    if (this._childArmature == value) {
      return;
    }

    this.display = value;
  }

  /// - The parent bone to which it belongs.
  Bone get parent => this._parent!;
}
