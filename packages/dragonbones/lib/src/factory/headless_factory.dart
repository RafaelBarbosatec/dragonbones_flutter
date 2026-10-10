part of '../../dragonbones.dart';

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
///
/// It does carry a *working* event dispatcher, though — that is what makes the
/// headless factory a complete binding for logic, not just for geometry.
/// Servers, tools and tests get exactly the events a renderer would:
///
/// ```dart
/// armature.eventDispatcher.addDBEventListener(EventObject.COMPLETE, (event) {
///   print('${event.animationState!.name} finished');
/// });
/// ```
///
/// Registering a listener also flips [hasDBEventListener], and the runtime uses
/// that to skip allocating events nobody wants — so listening to nothing costs
/// nothing.
class HeadlessArmatureDisplay implements IArmatureProxy {
  Armature? _armature;

  final Map<String, List<void Function(EventObject)>> _listeners = <String, List<void Function(EventObject)>>{};

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
  bool hasDBEventListener(String type) => this._listeners[type]?.isNotEmpty ?? false;

  @override
  void addDBEventListener(String type, void Function(EventObject event) listener) {
    (this._listeners[type] ??= <void Function(EventObject)>[]).add(listener);
  }

  @override
  void removeDBEventListener(String type, void Function(EventObject event) listener) {
    this._listeners[type]?.remove(listener);
  }

  @override
  void dispatchDBEvent(String type, EventObject eventObject) {
    final listeners = this._listeners[type];
    if (listeners == null) {
      return;
    }

    // Iterate over a copy: a listener is allowed to remove itself (or another)
    // while the event is being delivered.
    for (final listener in List<void Function(EventObject)>.of(listeners)) {
      listener(eventObject);
    }
  }

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
  /// [proxyFactory] builds the [IArmatureProxy] for every armature this factory
  /// creates — including nested child armatures, which are built during an
  /// update.
  ///
  /// Supply it to observe or route events from *all* of them at once. The proxy
  /// doubles as the armature's display object, so it must implement
  /// [IArmatureProxy] and nothing else is required of it (headless renders
  /// nothing). Defaults to a fresh [HeadlessArmatureDisplay].
  HeadlessFactory([super.dataParser, this.proxyFactory]) {
    this.dragonBones = DragonBones();
  }

  /// Builds the proxy for each armature, or null to use [HeadlessArmatureDisplay].
  final IArmatureProxy Function()? proxyFactory;

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
    final display = this.proxyFactory?.call() ?? HeadlessArmatureDisplay();
    armature.init(dataPackage.armature!, display, display, this.dragonBones);
    // Register with the hub's clock, the way the official engine bindings do
    // (`EgretFactory` calls `_dragonBones.clock.add(armature)`), so that
    // advancing the hub advances this armature *and* flushes its events.
    this.dragonBones.clock.add(armature);
    return armature;
  }

  @override
  Slot _buildSlot(
    BuildArmaturePackage dataPackage,
    SlotData slotData,
    Armature armature,
  ) {
    final slot = HeadlessSlot();
    // The displays must be non-null even headlessly: `Slot.update` bails out
    // early when `_display` is null, which would silently skip the whole
    // transform update (and therefore the draw geometry). The official engines
    // pass real bitmap/mesh objects here; placeholders stand in for those.
    slot.init(slotData, armature, HeadlessDisplay(), HeadlessDisplay());
    return slot;
  }
}

/// Stand-in for an engine's bitmap/mesh object. Never drawn — it exists so the
/// slot machinery (which branches on the display being non-null) runs normally.
class HeadlessDisplay {
  @override
  String toString() => '[HeadlessDisplay]';
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
class HeadlessTextureData extends TextureData {}
