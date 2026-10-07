part of '../../dragonbones.dart';

/// @private
class GeometryData {
  bool isShared = false;
  bool inheritDeform = false;
  int offset = 0;
  DragonBonesData? data;
  WeightData? weight;

  void clear() {
    this.isShared = false;
    this.inheritDeform = false;
    this.offset = 0;
    this.data = null;
    this.weight = null;
  }

  void shareFrom(GeometryData value) {
    this.isShared = true;
    this.offset = value.offset;
    this.weight = value.weight;
  }
}

/// @private
abstract class DisplayData extends BaseObject {
  int type = DisplayType.Image;
  String name = '';
  String path = '';
  final Transform transform = Transform();
  SkinData? parent;

  @override
  void _onClear() {
    this.name = '';
    this.path = '';
    this.transform.identity();
    this.parent = null;
  }
}

/// @private
class ImageDisplayData extends DisplayData {
  final Point pivot = Point();
  TextureData? texture;

  @override
  void _onClear() {
    super._onClear();
    this.type = DisplayType.Image;
    this.pivot.clear();
    this.texture = null;
  }
}

/// @private
class MeshDisplayData extends DisplayData {
  final GeometryData geometry = GeometryData();
  TextureData? texture;

  @override
  void _onClear() {
    super._onClear();
    this.type = DisplayType.Mesh;
    this.geometry.clear();
    this.texture = null;
  }
}

/// @private
class ArmatureDisplayData extends DisplayData {
  bool inheritAnimation = false;
  final List<ActionData> actions = <ActionData>[];
  ArmatureData? armature;

  @override
  void _onClear() {
    super._onClear();
    this.type = DisplayType.Armature;
    this.inheritAnimation = false;
    this.actions.length = 0;
    this.armature = null;
  }

  void addAction(ActionData value) {
    this.actions.add(value);
  }
}

/// @private
class PathDisplayData extends DisplayData {
  bool closed = false;
  bool constantSpeed = false;
  final GeometryData geometry = GeometryData();
  final List<double> curveLengths = <double>[];

  @override
  void _onClear() {
    super._onClear();
    this.type = DisplayType.Path;
    this.closed = false;
    this.constantSpeed = false;
    this.geometry.clear();
    this.curveLengths.length = 0;
  }
}

/// @private
class BoundingBoxDisplayData extends DisplayData {
  BoundingBoxData? boundingBox;

  @override
  void _onClear() {
    super._onClear();
    this.type = DisplayType.BoundingBox;
    this.boundingBox = null;
  }
}

/// @private
class BoundingBoxData extends BaseObject {
  int type = BoundingBoxType.Rectangle;
  int color = 0x000000;
  double width = 0.0;
  double height = 0.0;

  @override
  void _onClear() {
    this.type = BoundingBoxType.Rectangle;
    this.color = 0x000000;
    this.width = 0.0;
    this.height = 0.0;
  }
}

/// @private
class RectangleBoundingBoxData extends BoundingBoxData {
  @override
  void _onClear() {
    super._onClear();
    this.type = BoundingBoxType.Rectangle;
  }
}

/// @private
class EllipseBoundingBoxData extends BoundingBoxData {
  @override
  void _onClear() {
    super._onClear();
    this.type = BoundingBoxType.Ellipse;
  }
}

/// @private
class PolygonBoundingBoxData extends BoundingBoxData {
  double x = 0.0;
  double y = 0.0;
  final List<double> vertices = <double>[];

  @override
  void _onClear() {
    super._onClear();
    this.type = BoundingBoxType.Polygon;
    this.x = 0.0;
    this.y = 0.0;
    this.vertices.length = 0;
  }
}

/// @private
class WeightData extends BaseObject {
  int count = 0;
  int offset = 0;
  final List<BoneData> bones = <BoneData>[];

  @override
  void _onClear() {
    this.count = 0;
    this.offset = 0;
    this.bones.length = 0;
  }

  void addBone(BoneData value) => this.bones.add(value);
}
