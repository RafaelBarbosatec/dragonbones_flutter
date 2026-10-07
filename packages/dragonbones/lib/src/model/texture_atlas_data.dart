part of '../../dragonbones.dart';

/// @private
class TextureData extends BaseObject {
  bool rotated = false;
  String name = '';
  final Rectangle region = Rectangle();
  Rectangle? frame;
  TextureAtlasData? parent;

  static Rectangle createRectangle() => Rectangle();

  @override
  void _onClear() {
    this.rotated = false;
    this.name = '';
    this.region.clear();
    this.frame = null;
    this.parent = null;
  }
}

/// @private
class TextureAtlasData extends BaseObject {
  bool autoSearch = false;
  double width = 0.0;
  double height = 0.0;
  double scale = 1.0;
  String name = '';
  String imagePath = '';
  final Map<String, TextureData> textures = <String, TextureData>{};

  @override
  void _onClear() {
    this.textures.clear();
    this.autoSearch = false;
    this.width = 0.0;
    this.height = 0.0;
    this.scale = 1.0;
    this.name = '';
    this.imagePath = '';
  }

  TextureData createTexture() => TextureData();

  void addTexture(TextureData value) {
    if (value.name.isEmpty) {
      value.name = value.region.x.toString() + '_' + value.region.y.toString();
    }
    this.textures[value.name] = value;
    value.parent = this;
  }

  TextureData? getTexture(String textureName) => this.textures[textureName];
}
