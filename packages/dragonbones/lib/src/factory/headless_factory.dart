part of dragonbones;

/// A [Slot] with every engine-side render hook stubbed out.
///
/// Useful for headless use (servers, tooling, and — importantly — comparing this
/// runtime against the official one without a GPU). A real binding overrides
/// these hooks to draw something, exactly like Eggret/Pixi do.
///
/// Deliberately *not* abstract: the render hooks are turned into no-ops so that
/// a binding only has to override what it actually draws.
class HeadlessSlot extends Slot {
  @override
  void _initDisplay(Object? value, bool isRetain) {}
  @override
  void _disposeDisplay(Object? value, bool isRelease) {}
  @override
  void _onUpdateDisplay() {}
  @override
  void _addDisplay() {}
  @override
  void _replaceDisplay(Object? value) {}
  @override
  void _removeDisplay() {}
  @override
  void _updateZOrder() {}
  @override
  void _updateBlendMode() {}
  @override
  void _updateColor() {}
  @override
  void _updateFrame() {}
  @override
  void _updateMesh() {}
  @override
  void _updateTransform() {}
  @override
  void _identityTransform() {}
  @override
  void _updateVisible() {}
}

/// Minimal [IArmatureProxy] with no rendering attached.
class HeadlessArmatureDisplay implements IArmatureProxy {
  Armature? _armature;

  @override
  void dbInit(Armature armature) {
    this._armature = armature;
  }

  @override
  void dbClear() {
    this._armature = null;
  }

  @override
  void dbUpdate() {}

  @override
  bool hasDBEventListener(String type) => false;

  @override
  Armature get armature => this._armature!;

  @override
  Animation get animation => this._armature!.animation;
}

/// Concrete [BaseFactory] that builds [HeadlessSlot]s and drives a private
/// [DragonBones] instance — no engine, no textures, no drawing.
///
/// ```dart
/// final factory = HeadlessFactory();
/// factory.parseDragonBonesData(jsonDecode(skeJson));
/// factory.parseTextureAtlasData(jsonDecode(texJson), null, 'Dragon');
/// final armature = factory.buildArmature('Dragon', 'Dragon')!;
/// armature.animation.play('stand');
/// armature.advanceTime(1 / 24);
/// ```
class HeadlessFactory extends BaseFactory {
  HeadlessFactory([super.dataParser]) {
    this.dragonBones = DragonBones();
  }

  @override
  bool _isSupportMesh() => true;

  @override
  TextureAtlasData _buildTextureAtlasData(
    TextureAtlasData? textureAtlasData,
    Object? textureAtlas,
  ) {
    return textureAtlasData ?? HeadlessTextureAtlasData();
  }

  @override
  Armature _buildArmature(BuildArmaturePackage dataPackage) {
    final armature = Armature();
    final display = HeadlessArmatureDisplay();
    armature.init(dataPackage.armature!, display, display, this.dragonBones);
    return armature;
  }

  @override
  Slot _buildSlot(
    BuildArmaturePackage dataPackage,
    SlotData slotData,
    Armature armature,
  ) {
    final slot = HeadlessSlot();
    slot.init(slotData, armature, null, null);
    return slot;
  }
}

/// @internal
///
/// Atlas with no image behind it — textures resolve (so lookups and display
/// data work) but nothing can be drawn.
class HeadlessTextureAtlasData extends TextureAtlasData {
  @override
  TextureData createTexture() => HeadlessTextureData();
}

/// @internal
class HeadlessTextureData extends TextureData {
  @override
  void _onClear() {
    super._onClear();
  }
}
