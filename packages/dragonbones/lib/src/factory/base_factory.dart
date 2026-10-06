part of dragonbones;

/// @private
///
/// Holder used while building an armature: which data / armature / skin the
/// build is resolving against. Transcribed from the upstream
/// `factory/BaseFactory.ts`.
class BuildArmaturePackage {
  String dataName = '';
  String textureAtlasName = '';
  DragonBonesData? data;
  ArmatureData? armature;
  SkinData? skin;
}

/// Factory that turns parsed [DragonBonesData] into runnable [Armature]s.
///
/// Engine-agnostic: the three `_build*` hooks are abstract, so a binding (Flame,
/// a headless test harness, ...) supplies how an armature, a slot and a texture
/// atlas are actually represented.
///
/// Ported from `.ref/dragonBones-ts/factory/BaseFactory.ts`. The upstream object
/// pool is deliberately not ported — Dart's GC handles that — so objects are
/// constructed directly.
abstract class BaseFactory {
  /// @internal
  static DataParser? _objectParser;

  /// When true, lookups search every cached data set, not just the named one.
  bool autoSearch = false;

  /// @internal
  final Map<String, DragonBonesData> _dragonBonesDataMap = <String, DragonBonesData>{};

  /// @internal
  final Map<String, List<TextureAtlasData>> _textureAtlasDataMap =
      <String, List<TextureAtlasData>>{};

  /// @internal
  DragonBones? _dragonBones;

  /// @internal
  late final DataParser _dataParser;

  BaseFactory([DataParser? dataParser]) {
    BaseFactory._objectParser ??= ObjectDataParser();
    this._dataParser = dataParser ?? BaseFactory._objectParser!;
  }

  /// The [DragonBones] instance driving this factory's clock and object pool.
  DragonBones get dragonBones => this._dragonBones!;
  set dragonBones(DragonBones value) {
    this._dragonBones = value;
  }

  /// Whether mesh displays are supported. Always true here: meshes are rendered
  /// through Canvas.drawVertices, or ignored entirely in headless use.
  bool _isSupportMesh() => true;

  /// @internal
  TextureData? _getTextureData(String textureAtlasName, String textureName) {
    final textureAtlases = this._textureAtlasDataMap[textureAtlasName];
    if (textureAtlases != null) {
      for (final textureAtlasData in textureAtlases) {
        final textureData = textureAtlasData.getTexture(textureName);
        if (textureData != null) {
          return textureData;
        }
      }
    }

    if (this.autoSearch) {
      for (final key in this._textureAtlasDataMap.keys) {
        for (final textureAtlasData in this._textureAtlasDataMap[key]!) {
          if (textureAtlasData.autoSearch) {
            final textureData = textureAtlasData.getTexture(textureName);
            if (textureData != null) {
              return textureData;
            }
          }
        }
      }
    }

    return null;
  }

  /// @internal
  bool _fillBuildArmaturePackage(
    BuildArmaturePackage dataPackage,
    String dragonBonesName,
    String armatureName,
    String skinName,
    String textureAtlasName,
  ) {
    DragonBonesData? dragonBonesData;
    ArmatureData? armatureData;

    if (dragonBonesName.isNotEmpty) {
      dragonBonesData = this._dragonBonesDataMap[dragonBonesName];
      if (dragonBonesData != null) {
        armatureData = dragonBonesData.getArmature(armatureName);
      }
    }

    if (armatureData == null && (dragonBonesName.isEmpty || this.autoSearch)) {
      for (final key in this._dragonBonesDataMap.keys) {
        dragonBonesData = this._dragonBonesDataMap[key];
        if (dragonBonesName.isEmpty || dragonBonesData!.autoSearch) {
          armatureData = dragonBonesData!.getArmature(armatureName);
          if (armatureData != null) {
            dragonBonesName = key;
            break;
          }
        }
      }
    }

    if (armatureData != null) {
      dataPackage.dataName = dragonBonesName;
      dataPackage.textureAtlasName = textureAtlasName;
      dataPackage.data = dragonBonesData;
      dataPackage.armature = armatureData;
      dataPackage.skin = null;

      if (skinName.isNotEmpty) {
        dataPackage.skin = armatureData.getSkin(skinName);
        if (dataPackage.skin == null && this.autoSearch) {
          for (final key in this._dragonBonesDataMap.keys) {
            final skinDragonBonesData = this._dragonBonesDataMap[key]!;
            final skinArmatureData = skinDragonBonesData.getArmature(skinName);
            if (skinArmatureData != null) {
              dataPackage.skin = skinArmatureData.defaultSkin;
              break;
            }
          }
        }
      }

      dataPackage.skin ??= armatureData.defaultSkin;

      return true;
    }

    return false;
  }

  /// @internal
  void _buildBones(BuildArmaturePackage dataPackage, Armature armature) {
    for (final boneData in dataPackage.armature!.sortedBones) {
      // `Surface` (BoneType.Surface) is a milestone-2 feature; every bone in the
      // supported fixtures is a plain bone.
      final bone = Bone();
      bone.init(boneData, armature);
    }
  }

  /// @internal
  void _buildSlots(BuildArmaturePackage dataPackage, Armature armature) {
    final currentSkin = dataPackage.skin;
    final defaultSkin = dataPackage.armature!.defaultSkin;
    if (currentSkin == null || defaultSkin == null) {
      return;
    }

    final skinSlots = <String, List<DisplayData?>>{};
    for (final key in defaultSkin.displays.keys) {
      skinSlots[key] = defaultSkin.getDisplays(key)!;
    }

    if (!identical(currentSkin, defaultSkin)) {
      for (final key in currentSkin.displays.keys) {
        skinSlots[key] = currentSkin.getDisplays(key)!;
      }
    }

    for (final slotData in dataPackage.armature!.sortedSlots) {
      final displayDatas = skinSlots[slotData.name];
      final slot = this._buildSlot(dataPackage, slotData, armature);

      if (displayDatas != null) {
        slot.displayFrameCount = displayDatas.length;
        for (var i = 0, l = slot.displayFrameCount; i < l; ++i) {
          final displayData = displayDatas[i];
          slot.replaceRawDisplayData(displayData, i);

          if (displayData != null) {
            if (dataPackage.textureAtlasName.isNotEmpty) {
              final textureData =
                  this._getTextureData(dataPackage.textureAtlasName, displayData.path);
              slot.replaceTextureData(textureData, i);
            }

            final display = this._getSlotDisplay(dataPackage, displayData, slot);
            slot.replaceDisplay(display, i);
          } else {
            slot.replaceDisplay(null);
          }
        }
      }

      slot._setDisplayIndex(slotData.displayIndex, true);
    }
  }

  /// @internal
  ///
  /// Constraints (IK / path) are milestone 2. The upstream builds and registers
  /// them here; this port intentionally does nothing so that armatures with
  /// constraints still build (their bones simply are not constrained).
  void _buildConstraints(BuildArmaturePackage dataPackage, Armature armature) {
    // Intentionally empty — see doc comment.
  }

  /// @internal
  ///
  /// Nested child armatures are not supported in milestone 1; returning null
  /// makes the caller fall back to a plain display.
  Armature? _buildChildArmature(
    BuildArmaturePackage? dataPackage,
    Slot slot,
    ArmatureDisplayData displayData,
  ) {
    return null;
  }

  /// @internal
  Object? _getSlotDisplay(
    BuildArmaturePackage? dataPackage,
    DisplayData displayData,
    Slot slot,
  ) {
    final dataName = dataPackage != null
        ? dataPackage.dataName
        : displayData.parent!.parent!.parent!.name;

    switch (displayData.type) {
      case DisplayType.Image:
        final imageDisplayData = displayData as ImageDisplayData;
        imageDisplayData.texture ??= this._getTextureData(dataName, displayData.path);
        return slot.rawDisplay;

      case DisplayType.Mesh:
        final meshDisplayData = displayData as MeshDisplayData;
        meshDisplayData.texture ??= this._getTextureData(dataName, meshDisplayData.path);
        return this._isSupportMesh() ? slot.meshDisplay : slot.rawDisplay;

      case DisplayType.Armature:
        final armatureDisplayData = displayData as ArmatureDisplayData;
        final childArmature =
            this._buildChildArmature(dataPackage, slot, armatureDisplayData);
        if (childArmature != null) {
          childArmature.inheritAnimation = armatureDisplayData.inheritAnimation;
          // NOTE: upstream also registers the display data's actions as events
          // here. EventObject is not ported in milestone 1, and
          // _buildChildArmature always returns null, so this branch is
          // unreachable today — revisit when nested armatures land.
          childArmature.animation.play();
          return childArmature.display;
        }
        return null;

      default:
        return null;
    }
  }

  // ---- binding hooks -------------------------------------------------------

  /// @internal
  TextureAtlasData _buildTextureAtlasData(
    TextureAtlasData? textureAtlasData,
    Object? textureAtlas,
  );

  /// @internal
  Armature _buildArmature(BuildArmaturePackage dataPackage);

  /// @internal
  Slot _buildSlot(
    BuildArmaturePackage dataPackage,
    SlotData slotData,
    Armature armature,
  );

  // ---- public API ----------------------------------------------------------

  /// Parses raw DragonBones data (a decoded JSON `Map`) and caches it.
  ///
  /// Only the text/JSON format is supported: the binary `.dragonbones` parser
  /// is not ported, which is why this takes a decoded object rather than bytes.
  DragonBonesData? parseDragonBonesData(dynamic rawData, [String? name, double scale = 1.0]) {
    final dragonBonesData = this._dataParser.parseDragonBonesData(rawData, scale);
    if (dragonBonesData != null) {
      this.addDragonBonesData(dragonBonesData, name);
    }
    return dragonBonesData;
  }

  /// Parses a texture atlas (`*_tex.json`) and caches it.
  TextureAtlasData parseTextureAtlasData(
    dynamic rawData,
    Object? textureAtlas, [
    String? name,
    double scale = 1.0,
  ]) {
    var textureAtlasData = this._buildTextureAtlasData(null, null);
    this._dataParser.parseTextureAtlasData(rawData, textureAtlasData, scale);
    textureAtlasData = this._buildTextureAtlasData(textureAtlasData, textureAtlas);
    this.addTextureAtlasData(textureAtlasData, name);
    return textureAtlasData;
  }

  /// Caches a [DragonBonesData] under [name] (defaults to the data's own name).
  void addDragonBonesData(DragonBonesData data, [String? name]) {
    name ??= data.name;
    if (this._dragonBonesDataMap.containsKey(name)) {
      if (identical(this._dragonBonesDataMap[name], data)) {
        return;
      }
      // Upstream warns and refuses; silently refusing here would hide a real
      // mistake, so keep it loud.
      print('Can not add same name data: $name');
      return;
    }
    this._dragonBonesDataMap[name] = data;
  }

  /// @internal
  DragonBonesData? getDragonBonesData(String name) => this._dragonBonesDataMap[name];

  /// Caches a [TextureAtlasData] under [name] (defaults to the atlas' own name).
  void addTextureAtlasData(TextureAtlasData data, [String? name]) {
    name ??= data.name;
    final list = this._textureAtlasDataMap.putIfAbsent(
      name,
      () => <TextureAtlasData>[],
    );
    list.add(data);
  }

  /// Returns the cached texture atlases registered under [name], or null.
  List<TextureAtlasData>? getTextureAtlasData(String name) =>
      this._textureAtlasDataMap[name];

  /// Looks up armature data by name.
  ArmatureData? getArmatureData(String name, [String dragonBonesName = '']) {
    final dataPackage = BuildArmaturePackage();
    if (!this._fillBuildArmaturePackage(dataPackage, dragonBonesName, name, '', '')) {
      return null;
    }
    return dataPackage.armature;
  }

  /// Builds a runnable [Armature] from cached data.
  ///
  /// The returned armature is **not** driven by [dragonBones]' clock; advance it
  /// yourself (or add it to the clock) to animate it.
  Armature? buildArmature(
    String armatureName, [
    String dragonBonesName = '',
    String skinName = '',
    String textureAtlasName = '',
  ]) {
    final dataPackage = BuildArmaturePackage();
    if (!this._fillBuildArmaturePackage(
      dataPackage,
      dragonBonesName,
      armatureName,
      skinName,
      textureAtlasName,
    )) {
      print('No armature data: $armatureName, $dragonBonesName');
      return null;
    }

    final armature = this._buildArmature(dataPackage);
    this._buildBones(dataPackage, armature);
    this._buildSlots(dataPackage, armature);
    this._buildConstraints(dataPackage, armature);
    armature.invalidUpdate(null, true);
    armature.advanceTime(0.0); // Update armature pose.

    return armature;
  }

  /// Replaces the display data of a slot.
  void replaceDisplay(Slot slot, DisplayData? displayData, [int displayIndex = -1]) {
    if (displayIndex < 0) {
      displayIndex = slot.displayIndex;
    }
    if (displayIndex < 0) {
      displayIndex = 0;
    }

    slot.replaceDisplayData(displayData, displayIndex);

    if (displayData != null) {
      var display = this._getSlotDisplay(null, displayData, slot);
      if (displayData.type == DisplayType.Image) {
        final rawDisplayData = slot.getDisplayFrameAt(displayIndex).rawDisplayData;
        if (rawDisplayData != null && rawDisplayData.type == DisplayType.Mesh) {
          display = slot.meshDisplay;
        }
      }
      slot.replaceDisplay(display, displayIndex);
    } else {
      slot.replaceDisplay(null, displayIndex);
    }
  }
}
