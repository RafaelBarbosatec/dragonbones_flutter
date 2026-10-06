part of dragonbones;

/// Grows a `List<int>` by [count] zero-filled entries.
///
/// The upstream parser uses `array.length += n` on plain JS arrays, which
/// leaves holes that are read back as `undefined` (and become 0 once copied
/// into typed arrays). Dart's non-nullable growable lists cannot be extended
/// that way, so this port explicitly appends the zero default.
void _growInt(List<int> list, int count) {
  for (var i = 0; i < count; ++i) {
    list.add(0);
  }
}

/// Grows a `List<double>` by [count] zero-filled entries.
void _growFloat(List<double> list, int count) {
  for (var i = 0; i < count; ++i) {
    list.add(0.0);
  }
}

/// JavaScript `+value | 0` style integer coercion for raw JSON values.
int _intOf(dynamic value, [int defaultValue = 0]) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? defaultValue;
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  return defaultValue;
}

/// @private
abstract class DataParser {
  static const String DATA_VERSION_2_3 = '2.3';
  static const String DATA_VERSION_3_0 = '3.0';
  static const String DATA_VERSION_4_0 = '4.0';
  static const String DATA_VERSION_4_5 = '4.5';
  static const String DATA_VERSION_5_0 = '5.0';
  static const String DATA_VERSION_5_5 = '5.5';
  static const String DATA_VERSION_5_6 = '5.6';
  static const String DATA_VERSION = DataParser.DATA_VERSION_5_6;

  static const List<String> DATA_VERSIONS = <String>[
    DataParser.DATA_VERSION_4_0,
    DataParser.DATA_VERSION_4_5,
    DataParser.DATA_VERSION_5_0,
    DataParser.DATA_VERSION_5_5,
    DataParser.DATA_VERSION_5_6,
  ];

  static const String TEXTURE_ATLAS = 'textureAtlas';
  static const String SUB_TEXTURE = 'SubTexture';
  static const String FORMAT = 'format';
  static const String IMAGE_PATH = 'imagePath';
  static const String WIDTH = 'width';
  static const String HEIGHT = 'height';
  static const String ROTATED = 'rotated';
  static const String FRAME_X = 'frameX';
  static const String FRAME_Y = 'frameY';
  static const String FRAME_WIDTH = 'frameWidth';
  static const String FRAME_HEIGHT = 'frameHeight';

  static const String DRADON_BONES = 'dragonBones';
  static const String USER_DATA = 'userData';
  static const String ARMATURE = 'armature';
  static const String CANVAS = 'canvas';
  static const String BONE = 'bone';
  static const String SURFACE = 'surface';
  static const String SLOT = 'slot';
  static const String CONSTRAINT = 'constraint';
  static const String SKIN = 'skin';
  static const String DISPLAY = 'display';
  static const String FRAME = 'frame';
  static const String IK = 'ik';
  static const String PATH_CONSTRAINT = 'path';

  static const String ANIMATION = 'animation';
  static const String TIMELINE = 'timeline';
  static const String FFD = 'ffd';
  static const String TRANSLATE_FRAME = 'translateFrame';
  static const String ROTATE_FRAME = 'rotateFrame';
  static const String SCALE_FRAME = 'scaleFrame';
  static const String DISPLAY_FRAME = 'displayFrame';
  static const String COLOR_FRAME = 'colorFrame';
  static const String DEFAULT_ACTIONS = 'defaultActions';
  static const String ACTIONS = 'actions';
  static const String EVENTS = 'events';

  static const String INTS = 'ints';
  static const String FLOATS = 'floats';
  static const String STRINGS = 'strings';

  static const String TRANSFORM = 'transform';
  static const String PIVOT = 'pivot';
  static const String AABB = 'aabb';
  static const String COLOR = 'color';

  static const String VERSION = 'version';
  static const String COMPATIBLE_VERSION = 'compatibleVersion';
  static const String FRAME_RATE = 'frameRate';
  static const String TYPE = 'type';
  static const String SUB_TYPE = 'subType';
  static const String NAME = 'name';
  static const String PARENT = 'parent';
  static const String TARGET = 'target';
  static const String STAGE = 'stage';
  static const String SHARE = 'share';
  static const String PATH = 'path';
  static const String LENGTH = 'length';
  static const String DISPLAY_INDEX = 'displayIndex';
  static const String Z_ORDER = 'zOrder';
  static const String Z_INDEX = 'zIndex';
  static const String BLEND_MODE = 'blendMode';
  static const String INHERIT_TRANSLATION = 'inheritTranslation';
  static const String INHERIT_ROTATION = 'inheritRotation';
  static const String INHERIT_SCALE = 'inheritScale';
  static const String INHERIT_REFLECTION = 'inheritReflection';
  static const String INHERIT_ANIMATION = 'inheritAnimation';
  static const String INHERIT_DEFORM = 'inheritDeform';
  static const String SEGMENT_X = 'segmentX';
  static const String SEGMENT_Y = 'segmentY';
  static const String BEND_POSITIVE = 'bendPositive';
  static const String CHAIN = 'chain';
  static const String WEIGHT = 'weight';

  static const String BLEND_TYPE = 'blendType';
  static const String FADE_IN_TIME = 'fadeInTime';
  static const String PLAY_TIMES = 'playTimes';
  static const String SCALE = 'scale';
  static const String OFFSET = 'offset';
  static const String POSITION = 'position';
  static const String DURATION = 'duration';
  static const String TWEEN_EASING = 'tweenEasing';
  static const String TWEEN_ROTATE = 'tweenRotate';
  static const String TWEEN_SCALE = 'tweenScale';
  static const String CLOCK_WISE = 'clockwise';
  static const String CURVE = 'curve';
  static const String SOUND = 'sound';
  static const String EVENT = 'event';
  static const String ACTION = 'action';

  static const String X = 'x';
  static const String Y = 'y';
  static const String SKEW_X = 'skX';
  static const String SKEW_Y = 'skY';
  static const String SCALE_X = 'scX';
  static const String SCALE_Y = 'scY';
  static const String VALUE = 'value';
  static const String ROTATE = 'rotate';
  static const String SKEW = 'skew';
  static const String ALPHA = 'alpha';

  static const String ALPHA_OFFSET = 'aO';
  static const String RED_OFFSET = 'rO';
  static const String GREEN_OFFSET = 'gO';
  static const String BLUE_OFFSET = 'bO';
  static const String ALPHA_MULTIPLIER = 'aM';
  static const String RED_MULTIPLIER = 'rM';
  static const String GREEN_MULTIPLIER = 'gM';
  static const String BLUE_MULTIPLIER = 'bM';

  static const String UVS = 'uvs';
  static const String VERTICES = 'vertices';
  static const String TRIANGLES = 'triangles';
  static const String WEIGHTS = 'weights';
  static const String SLOT_POSE = 'slotPose';
  static const String BONE_POSE = 'bonePose';

  static const String BONES = 'bones';
  static const String POSITION_MODE = 'positionMode';
  static const String SPACING_MODE = 'spacingMode';
  static const String ROTATE_MODE = 'rotateMode';
  static const String SPACING = 'spacing';
  static const String ROTATE_OFFSET = 'rotateOffset';
  static const String ROTATE_MIX = 'rotateMix';
  static const String TRANSLATE_MIX = 'translateMix';

  static const String TARGET_DISPLAY = 'targetDisplay';
  static const String CLOSED = 'closed';
  static const String CONSTANT_SPEED = 'constantSpeed';
  static const String VERTEX_COUNT = 'vertexCount';
  static const String LENGTHS = 'lengths';

  static const String GOTO_AND_PLAY = 'gotoAndPlay';

  static const String DEFAULT_NAME = 'default';

  static int _getArmatureType(String value) {
    switch (value.toLowerCase()) {
      case 'stage':
        return ArmatureType.Stage;
      case 'armature':
        return ArmatureType.Armature;
      case 'movieclip':
        return ArmatureType.MovieClip;
      default:
        return ArmatureType.Armature;
    }
  }

  static int _getBoneType(String value) {
    switch (value.toLowerCase()) {
      case 'bone':
        return BoneType.Bone;
      case 'surface':
        return BoneType.Surface;
      default:
        return BoneType.Bone;
    }
  }

  static int _getPositionMode(String value) {
    switch (value.toLowerCase()) {
      case 'percent':
        return PositionMode.Percent;
      case 'fixed':
        return PositionMode.Fixed;
      default:
        return PositionMode.Percent;
    }
  }

  static int _getSpacingMode(String value) {
    switch (value.toLowerCase()) {
      case 'length':
        return SpacingMode.Length;
      case 'percent':
        return SpacingMode.Percent;
      case 'fixed':
        return SpacingMode.Fixed;
      default:
        return SpacingMode.Length;
    }
  }

  static int _getRotateMode(String value) {
    switch (value.toLowerCase()) {
      case 'tangent':
        return RotateMode.Tangent;
      case 'chain':
        return RotateMode.Chain;
      case 'chainscale':
        return RotateMode.ChainScale;
      default:
        return RotateMode.Tangent;
    }
  }

  static int _getDisplayType(String value) {
    switch (value.toLowerCase()) {
      case 'image':
        return DisplayType.Image;
      case 'mesh':
        return DisplayType.Mesh;
      case 'armature':
        return DisplayType.Armature;
      case 'boundingbox':
        return DisplayType.BoundingBox;
      case 'path':
        return DisplayType.Path;
      default:
        return DisplayType.Image;
    }
  }

  static int _getBoundingBoxType(String value) {
    switch (value.toLowerCase()) {
      case 'rectangle':
        return BoundingBoxType.Rectangle;
      case 'ellipse':
        return BoundingBoxType.Ellipse;
      case 'polygon':
        return BoundingBoxType.Polygon;
      default:
        return BoundingBoxType.Rectangle;
    }
  }

  static int _getBlendMode(String value) {
    switch (value.toLowerCase()) {
      case 'normal':
        return BlendMode.Normal;
      case 'add':
        return BlendMode.Add;
      case 'alpha':
        return BlendMode.Alpha;
      case 'darken':
        return BlendMode.Darken;
      case 'difference':
        return BlendMode.Difference;
      case 'erase':
        return BlendMode.Erase;
      case 'hardlight':
        return BlendMode.HardLight;
      case 'invert':
        return BlendMode.Invert;
      case 'layer':
        return BlendMode.Layer;
      case 'lighten':
        return BlendMode.Lighten;
      case 'multiply':
        return BlendMode.Multiply;
      case 'overlay':
        return BlendMode.Overlay;
      case 'screen':
        return BlendMode.Screen;
      case 'subtract':
        return BlendMode.Subtract;
      default:
        return BlendMode.Normal;
    }
  }

  static int _getAnimationBlendType(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return AnimationBlendType.None;
      case '1d':
        return AnimationBlendType.E1D;
      default:
        return AnimationBlendType.None;
    }
  }

  static int _getActionType(String value) {
    switch (value.toLowerCase()) {
      case 'play':
        return ActionType.Play;
      case 'frame':
        return ActionType.Frame;
      case 'sound':
        return ActionType.Sound;
      default:
        return ActionType.Play;
    }
  }

  DragonBonesData? parseDragonBonesData(dynamic rawData, [double scale = 1.0]);
  bool parseTextureAtlasData(dynamic rawData, TextureAtlasData textureAtlasData, [double scale = 1.0]);
}

/// @private
class ObjectDataParser extends DataParser {
  static bool _getBoolean(dynamic rawData, String key, bool defaultValue) {
    if (_has(rawData, key)) {
      final value = rawData[key];

      if (value is bool) {
        return value;
      } else if (value is String) {
        switch (value) {
          case '0':
          case 'NaN':
          case '':
          case 'false':
          case 'null':
          case 'undefined':
            return false;
          default:
            return true;
        }
      } else if (value is num) {
        return value != 0 && !value.isNaN;
      } else {
        return value != null;
      }
    }

    return defaultValue;
  }

  static double _getNumber(dynamic rawData, String key, double defaultValue) {
    if (_has(rawData, key)) {
      final value = rawData[key];
      if (value == null || value == 'NaN') {
        return defaultValue;
      }

      return _number(value, 0.0);
    }

    return defaultValue;
  }

  static String _getString(dynamic rawData, String key, String defaultValue) {
    if (_has(rawData, key)) {
      final value = rawData[key];
      if (value is String) {
        return value;
      }

      return value.toString();
    }

    return defaultValue;
  }

  static bool _has(dynamic rawData, String key) => rawData is Map && rawData.containsKey(key);

  int _rawTextureAtlasIndex = 0;
  final List<BoneData> _rawBones = <BoneData>[];
  DragonBonesData? _data;
  ArmatureData? _armature;
  BoneData? _bone;
  GeometryData? _geometry;
  SlotData? _slot;
  SkinData? _skin;
  MeshDisplayData? _mesh;
  AnimationData? _animation;
  TimelineData? _timeline;
  List<dynamic>? _rawTextureAtlases;

  int _frameValueType = FrameValueType.Step;
  int _defaultColorOffset = -1;
  double _prevClockwise = 0.0;
  double _prevRotation = 0.0;
  double _frameDefaultValue = 0.0;
  double _frameValueScale = 1.0;
  final Matrix _helpMatrixA = Matrix();
  final Matrix _helpMatrixB = Matrix();
  final Transform _helpTransform = Transform();
  final ColorTransform _helpColorTransform = ColorTransform();
  final Point _helpPoint = Point();
  final List<double> _helpArray = <double>[];
  final List<int> _intArray = <int>[];
  final List<double> _floatArray = <double>[];
  final List<int> _frameIntArray = <int>[];
  final List<double> _frameFloatArray = <double>[];
  final List<int> _frameArray = <int>[];
  final List<int> _timelineArray = <int>[];
  final List<int> _colorArray = <int>[];
  final List<dynamic> _cacheRawMeshes = <dynamic>[];
  final List<MeshDisplayData> _cacheMeshes = <MeshDisplayData>[];
  final List<ActionFrame> _actionFrames = <ActionFrame>[];
  final Map<String, List<num>> _weightSlotPose = <String, List<num>>{};
  final Map<String, List<num>> _weightBonePoses = <String, List<num>>{};
  final Map<String, List<BoneData>> _cacheBones = <String, List<BoneData>>{};
  final Map<String, List<ActionData>> _slotChildActions = <String, List<ActionData>>{};

  void _getCurvePoint(
      double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4, double t, Point result) {
    final lT = 1.0 - t;
    final powA = lT * lT;
    final powB = t * t;
    final kA = lT * powA;
    final kB = 3.0 * t * powA;
    final kC = 3.0 * lT * powB;
    final kD = t * powB;

    result.x = kA * x1 + kB * x2 + kC * x3 + kD * x4;
    result.y = kA * y1 + kB * y2 + kC * y3 + kD * y4;
  }

  bool _samplingEasingCurve(List<num> curve, List<double> samples) {
    final curveCount = curve.length;

    if (curveCount % 3 == 1) {
      var stepIndex = -2;
      for (var i = 0, l = samples.length; i < l; ++i) {
        final t = (i + 1) / (l + 1); // float
        while ((stepIndex + 6 < curveCount ? curve[stepIndex + 6] : 1) < t) {
          // stepIndex + 3 * 2
          stepIndex += 6;
        }

        final isInCurve = stepIndex >= 0 && stepIndex + 6 < curveCount;
        final x1 = isInCurve ? curve[stepIndex].toDouble() : 0.0;
        final y1 = isInCurve ? curve[stepIndex + 1].toDouble() : 0.0;
        final x2 = curve[stepIndex + 2].toDouble();
        final y2 = curve[stepIndex + 3].toDouble();
        final x3 = curve[stepIndex + 4].toDouble();
        final y3 = curve[stepIndex + 5].toDouble();
        final x4 = isInCurve ? curve[stepIndex + 6].toDouble() : 1.0;
        final y4 = isInCurve ? curve[stepIndex + 7].toDouble() : 1.0;

        var lower = 0.0;
        var higher = 1.0;
        while (higher - lower > 0.0001) {
          final percentage = (higher + lower) * 0.5;
          this._getCurvePoint(x1, y1, x2, y2, x3, y3, x4, y4, percentage, this._helpPoint);
          if (t - this._helpPoint.x > 0.0) {
            lower = percentage;
          } else {
            higher = percentage;
          }
        }

        samples[i] = this._helpPoint.y;
      }

      return true;
    } else {
      var stepIndex = 0;
      for (var i = 0, l = samples.length; i < l; ++i) {
        final t = (i + 1) / (l + 1); // float
        while (curve[stepIndex + 6] < t) {
          // stepIndex + 3 * 2
          stepIndex += 6;
        }

        final x1 = curve[stepIndex].toDouble();
        final y1 = curve[stepIndex + 1].toDouble();
        final x2 = curve[stepIndex + 2].toDouble();
        final y2 = curve[stepIndex + 3].toDouble();
        final x3 = curve[stepIndex + 4].toDouble();
        final y3 = curve[stepIndex + 5].toDouble();
        final x4 = curve[stepIndex + 6].toDouble();
        final y4 = curve[stepIndex + 7].toDouble();

        var lower = 0.0;
        var higher = 1.0;
        while (higher - lower > 0.0001) {
          final percentage = (higher + lower) * 0.5;
          this._getCurvePoint(x1, y1, x2, y2, x3, y3, x4, y4, percentage, this._helpPoint);
          if (t - this._helpPoint.x > 0.0) {
            lower = percentage;
          } else {
            higher = percentage;
          }
        }

        samples[i] = this._helpPoint.y;
      }

      return false;
    }
  }

  void _parseActionDataInFrame(dynamic rawData, int frameStart, BoneData? bone, SlotData? slot) {
    if (_has(rawData, DataParser.EVENT)) {
      this._mergeActionFrame(rawData[DataParser.EVENT], frameStart, ActionType.Frame, bone, slot);
    }

    if (_has(rawData, DataParser.SOUND)) {
      this._mergeActionFrame(rawData[DataParser.SOUND], frameStart, ActionType.Sound, bone, slot);
    }

    if (_has(rawData, DataParser.ACTION)) {
      this._mergeActionFrame(rawData[DataParser.ACTION], frameStart, ActionType.Play, bone, slot);
    }

    if (_has(rawData, DataParser.EVENTS)) {
      this._mergeActionFrame(rawData[DataParser.EVENTS], frameStart, ActionType.Frame, bone, slot);
    }

    if (_has(rawData, DataParser.ACTIONS)) {
      this._mergeActionFrame(rawData[DataParser.ACTIONS], frameStart, ActionType.Play, bone, slot);
    }
  }

  void _mergeActionFrame(dynamic rawData, int frameStart, int type, BoneData? bone, SlotData? slot) {
    final actionOffset = this._armature!.actions.length;
    final actions = this._parseActionData(rawData, type, bone, slot);
    var frameIndex = 0;
    ActionFrame? frame;

    for (final action in actions) {
      this._armature!.addAction(action, false);
    }

    if (this._actionFrames.length == 0) {
      // First frame.
      frame = ActionFrame();
      frame.frameStart = 0;
      this._actionFrames.add(frame);
      frame = null;
    }

    for (final eachFrame in this._actionFrames) {
      // Get same frame.
      if (eachFrame.frameStart == frameStart) {
        frame = eachFrame;
        break;
      } else if (eachFrame.frameStart > frameStart) {
        break;
      }

      frameIndex++;
    }

    if (frame == null) {
      // Create and cache frame.
      frame = ActionFrame();
      frame.frameStart = frameStart;
      this._actionFrames.insert(frameIndex, frame);
    }

    for (var i = 0; i < actions.length; ++i) {
      // Cache action offsets.
      frame.actions.add(actionOffset + i);
    }
  }

  ArmatureData _parseArmature(dynamic rawData, double scale) {
    final armature = ArmatureData();
    armature.name = _getString(rawData, DataParser.NAME, '');
    armature.frameRate = _getNumber(rawData, DataParser.FRAME_RATE, this._data!.frameRate);
    armature.scale = scale;

    if (_has(rawData, DataParser.TYPE) && rawData[DataParser.TYPE] is String) {
      armature.type = DataParser._getArmatureType(rawData[DataParser.TYPE] as String);
    } else {
      armature.type = _getNumber(rawData, DataParser.TYPE, ArmatureType.Armature.toDouble()).toInt();
    }

    if (armature.frameRate == 0.0) {
      // Data error.
      armature.frameRate = 24.0;
    }

    this._armature = armature;

    if (_has(rawData, DataParser.CANVAS)) {
      final rawCanvas = rawData[DataParser.CANVAS];
      final canvas = CanvasData();

      if (_has(rawCanvas, DataParser.COLOR)) {
        canvas.hasBackground = true;
      } else {
        canvas.hasBackground = false;
      }

      canvas.color = _getNumber(rawCanvas, DataParser.COLOR, 0).toInt();
      canvas.x = _getNumber(rawCanvas, DataParser.X, 0.0) * armature.scale;
      canvas.y = _getNumber(rawCanvas, DataParser.Y, 0.0) * armature.scale;
      canvas.width = _getNumber(rawCanvas, DataParser.WIDTH, 0.0) * armature.scale;
      canvas.height = _getNumber(rawCanvas, DataParser.HEIGHT, 0.0) * armature.scale;
      armature.canvas = canvas;
    }

    if (_has(rawData, DataParser.AABB)) {
      final rawAABB = rawData[DataParser.AABB];
      armature.aabb.x = _getNumber(rawAABB, DataParser.X, 0.0) * armature.scale;
      armature.aabb.y = _getNumber(rawAABB, DataParser.Y, 0.0) * armature.scale;
      armature.aabb.width = _getNumber(rawAABB, DataParser.WIDTH, 0.0) * armature.scale;
      armature.aabb.height = _getNumber(rawAABB, DataParser.HEIGHT, 0.0) * armature.scale;
    }

    if (_has(rawData, DataParser.BONE)) {
      final rawBones = rawData[DataParser.BONE] as List<dynamic>;
      for (final rawBone in rawBones) {
        final parentName = _getString(rawBone, DataParser.PARENT, '');
        final bone = this._parseBone(rawBone);

        if (parentName.isNotEmpty) {
          // Get bone parent.
          final parent = armature.getBone(parentName);
          if (parent != null) {
            bone.parent = parent;
          } else {
            // Cache.
            if (!this._cacheBones.containsKey(parentName)) {
              this._cacheBones[parentName] = <BoneData>[];
            }

            this._cacheBones[parentName]!.add(bone);
          }
        }

        if (this._cacheBones.containsKey(bone.name)) {
          for (final child in this._cacheBones[bone.name]!) {
            child.parent = bone;
          }

          this._cacheBones.remove(bone.name);
        }

        armature.addBone(bone);
        this._rawBones.add(bone); // Cache raw bones sort.
      }
    }

    if (_has(rawData, DataParser.IK)) {
      final rawIKS = rawData[DataParser.IK] as List<dynamic>;
      for (final rawIK in rawIKS) {
        final constraint = this._parseIKConstraint(rawIK);
        if (constraint != null) {
          armature.addConstraint(constraint);
        }
      }
    }

    armature.sortBones();

    if (_has(rawData, DataParser.SLOT)) {
      var zOrder = 0;
      final rawSlots = rawData[DataParser.SLOT] as List<dynamic>;
      for (final rawSlot in rawSlots) {
        armature.addSlot(this._parseSlot(rawSlot, zOrder++));
      }
    }

    if (_has(rawData, DataParser.SKIN)) {
      final rawSkins = rawData[DataParser.SKIN] as List<dynamic>;
      for (final rawSkin in rawSkins) {
        armature.addSkin(this._parseSkin(rawSkin));
      }
    }

    if (_has(rawData, DataParser.PATH_CONSTRAINT)) {
      final rawPaths = rawData[DataParser.PATH_CONSTRAINT] as List<dynamic>;
      for (final rawPath in rawPaths) {
        final constraint = this._parsePathConstraint(rawPath);
        if (constraint != null) {
          armature.addConstraint(constraint);
        }
      }
    }

    for (var i = 0, l = this._cacheRawMeshes.length; i < l; ++i) {
      // Link mesh.
      final rawData = this._cacheRawMeshes[i];
      final shareName = _getString(rawData, DataParser.SHARE, '');
      if (shareName.isEmpty) {
        continue;
      }

      var skinName = _getString(rawData, DataParser.SKIN, DataParser.DEFAULT_NAME);
      if (skinName.isEmpty) {
        skinName = DataParser.DEFAULT_NAME;
      }

      final shareMesh = armature.getMesh(skinName, '', shareName); // TODO slot;
      if (shareMesh == null) {
        continue; // Error.
      }

      final mesh = this._cacheMeshes[i];
      mesh.geometry.shareFrom(shareMesh.geometry);
    }

    if (_has(rawData, DataParser.ANIMATION)) {
      final rawAnimations = rawData[DataParser.ANIMATION] as List<dynamic>;
      for (final rawAnimation in rawAnimations) {
        final animation = this._parseAnimation(rawAnimation);
        armature.addAnimation(animation);
      }
    }

    if (_has(rawData, DataParser.DEFAULT_ACTIONS)) {
      final actions = this._parseActionData(rawData[DataParser.DEFAULT_ACTIONS], ActionType.Play, null, null);
      for (final action in actions) {
        armature.addAction(action, true);

        if (action.type == ActionType.Play) {
          // Set default animation from default action.
          final animation = armature.getAnimation(action.name);
          if (animation != null) {
            armature.defaultAnimation = animation;
          }
        }
      }
    }

    if (_has(rawData, DataParser.ACTIONS)) {
      final actions = this._parseActionData(rawData[DataParser.ACTIONS], ActionType.Play, null, null);
      for (final action in actions) {
        armature.addAction(action, false);
      }
    }

    // Clear helper.
    this._rawBones.length = 0;
    this._cacheRawMeshes.length = 0;
    this._cacheMeshes.length = 0;
    this._armature = null;

    this._weightSlotPose.clear();
    this._weightBonePoses.clear();
    this._cacheBones.clear();
    this._slotChildActions.clear();

    return armature;
  }

  BoneData _parseBone(dynamic rawData) {
    int type;

    if (_has(rawData, DataParser.TYPE) && rawData[DataParser.TYPE] is String) {
      type = DataParser._getBoneType(rawData[DataParser.TYPE] as String);
    } else {
      type = _getNumber(rawData, DataParser.TYPE, BoneType.Bone.toDouble()).toInt();
    }

    if (type == BoneType.Bone) {
      final scale = this._armature!.scale;
      final bone = BoneData();
      bone.inheritTranslation = _getBoolean(rawData, DataParser.INHERIT_TRANSLATION, true);
      bone.inheritRotation = _getBoolean(rawData, DataParser.INHERIT_ROTATION, true);
      bone.inheritScale = _getBoolean(rawData, DataParser.INHERIT_SCALE, true);
      bone.inheritReflection = _getBoolean(rawData, DataParser.INHERIT_REFLECTION, true);
      bone.length = _getNumber(rawData, DataParser.LENGTH, 0.0) * scale;
      bone.alpha = _getNumber(rawData, DataParser.ALPHA, 1.0);
      bone.name = _getString(rawData, DataParser.NAME, '');

      if (_has(rawData, DataParser.TRANSFORM)) {
        this._parseTransform(rawData[DataParser.TRANSFORM], bone.transform, scale);
      }

      return bone;
    }

    final surface = SurfaceData();
    surface.alpha = _getNumber(rawData, DataParser.ALPHA, 1.0);
    surface.name = _getString(rawData, DataParser.NAME, '');
    surface.segmentX = _getNumber(rawData, DataParser.SEGMENT_X, 0.0).toInt();
    surface.segmentY = _getNumber(rawData, DataParser.SEGMENT_Y, 0.0).toInt();
    this._parseGeometry(rawData, surface.geometry);

    return surface;
  }

  ConstraintData? _parseIKConstraint(dynamic rawData) {
    final bone = this._armature!.getBone(_getString(rawData, DataParser.BONE, ''));
    if (bone == null) {
      return null;
    }

    final target = this._armature!.getBone(_getString(rawData, DataParser.TARGET, ''));
    if (target == null) {
      return null;
    }

    final chain = _getNumber(rawData, DataParser.CHAIN, 0.0);
    final constraint = IKConstraintData();
    constraint.scaleEnabled = _getBoolean(rawData, DataParser.SCALE, false);
    constraint.bendPositive = _getBoolean(rawData, DataParser.BEND_POSITIVE, true);
    constraint.weight = _getNumber(rawData, DataParser.WEIGHT, 1.0);
    constraint.name = _getString(rawData, DataParser.NAME, '');
    constraint.type = ConstraintType.IK;
    constraint.target = target;

    if (chain > 0.0 && bone.parent != null) {
      constraint.root = bone.parent;
      constraint.bone = bone;
    } else {
      constraint.root = bone;
      constraint.bone = null;
    }

    return constraint;
  }

  ConstraintData? _parsePathConstraint(dynamic rawData) {
    final target = this._armature!.getSlot(_getString(rawData, DataParser.TARGET, ''));
    if (target == null) {
      return null;
    }

    final defaultSkin = this._armature!.defaultSkin;
    if (defaultSkin == null) {
      return null;
    }
    //TODO
    final targetDisplay = defaultSkin.getDisplay(target.name, _getString(rawData, DataParser.TARGET_DISPLAY, target.name));
    if (targetDisplay is! PathDisplayData) {
      return null;
    }

    final bones = rawData[DataParser.BONES] as List<dynamic>?;
    if (bones == null || bones.isEmpty) {
      return null;
    }

    final constraint = PathConstraintData();
    constraint.name = _getString(rawData, DataParser.NAME, '');
    constraint.type = ConstraintType.Path;
    constraint.pathSlot = target;
    constraint.pathDisplayData = targetDisplay;
    constraint.target = target.parent;
    constraint.positionMode = DataParser._getPositionMode(_getString(rawData, DataParser.POSITION_MODE, ''));
    constraint.spacingMode = DataParser._getSpacingMode(_getString(rawData, DataParser.SPACING_MODE, ''));
    constraint.rotateMode = DataParser._getRotateMode(_getString(rawData, DataParser.ROTATE_MODE, ''));
    constraint.position = _getNumber(rawData, DataParser.POSITION, 0.0);
    constraint.spacing = _getNumber(rawData, DataParser.SPACING, 0.0);
    constraint.rotateOffset = _getNumber(rawData, DataParser.ROTATE_OFFSET, 0.0);
    constraint.rotateMix = _getNumber(rawData, DataParser.ROTATE_MIX, 1.0);
    constraint.translateMix = _getNumber(rawData, DataParser.TRANSLATE_MIX, 1.0);
    //
    for (final boneName in bones) {
      final bone = this._armature!.getBone(boneName as String);
      if (bone != null) {
        constraint.AddBone(bone);

        if (constraint.root == null) {
          constraint.root = bone;
        }
      }
    }

    return constraint;
  }

  SlotData _parseSlot(dynamic rawData, int zOrder) {
    final slot = SlotData();
    slot.displayIndex = _getNumber(rawData, DataParser.DISPLAY_INDEX, 0.0).toInt();
    slot.zOrder = zOrder;
    slot.zIndex = _getNumber(rawData, DataParser.Z_INDEX, 0.0).toInt();
    slot.alpha = _getNumber(rawData, DataParser.ALPHA, 1.0);
    slot.name = _getString(rawData, DataParser.NAME, '');
    slot.parent = this._armature!.getBone(_getString(rawData, DataParser.PARENT, ''));

    if (_has(rawData, DataParser.BLEND_MODE) && rawData[DataParser.BLEND_MODE] is String) {
      slot.blendMode = DataParser._getBlendMode(rawData[DataParser.BLEND_MODE] as String);
    } else {
      slot.blendMode = _getNumber(rawData, DataParser.BLEND_MODE, BlendMode.Normal.toDouble()).toInt();
    }

    if (_has(rawData, DataParser.COLOR)) {
      slot.color = SlotData.createColor();
      this._parseColorTransform(rawData[DataParser.COLOR], slot.color);
    } else {
      slot.color = SlotData.DEFAULT_COLOR;
    }

    if (_has(rawData, DataParser.ACTIONS)) {
      this._slotChildActions[slot.name] = this._parseActionData(rawData[DataParser.ACTIONS], ActionType.Play, null, null);
    }

    return slot;
  }

  SkinData _parseSkin(dynamic rawData) {
    final skin = SkinData();
    skin.name = _getString(rawData, DataParser.NAME, DataParser.DEFAULT_NAME);

    if (skin.name.isEmpty) {
      skin.name = DataParser.DEFAULT_NAME;
    }

    if (_has(rawData, DataParser.SLOT)) {
      final rawSlots = rawData[DataParser.SLOT] as List<dynamic>;
      this._skin = skin;

      for (final rawSlot in rawSlots) {
        final slotName = _getString(rawSlot, DataParser.NAME, '');
        final slot = this._armature!.getSlot(slotName);

        if (slot != null) {
          this._slot = slot;

          if (_has(rawSlot, DataParser.DISPLAY)) {
            final rawDisplays = rawSlot[DataParser.DISPLAY] as List<dynamic>;
            for (final rawDisplay in rawDisplays) {
              if (rawDisplay != null) {
                skin.addDisplay(slotName, this._parseDisplay(rawDisplay));
              } else {
                skin.addDisplay(slotName, null);
              }
            }
          }

          this._slot = null;
        }
      }

      this._skin = null;
    }

    return skin;
  }

  DisplayData? _parseDisplay(dynamic rawData) {
    final name = _getString(rawData, DataParser.NAME, '');
    final path = _getString(rawData, DataParser.PATH, '');
    int type = DisplayType.Image;
    DisplayData? display;

    if (_has(rawData, DataParser.TYPE) && rawData[DataParser.TYPE] is String) {
      type = DataParser._getDisplayType(rawData[DataParser.TYPE] as String);
    } else {
      type = _getNumber(rawData, DataParser.TYPE, type.toDouble()).toInt();
    }

    switch (type) {
      case DisplayType.Image:
        {
          final imageDisplay = ImageDisplayData();
          display = imageDisplay;
          imageDisplay.name = name;
          imageDisplay.path = path.isNotEmpty ? path : name;
          this._parsePivot(rawData, imageDisplay);
          break;
        }

      case DisplayType.Armature:
        {
          final armatureDisplay = ArmatureDisplayData();
          display = armatureDisplay;
          armatureDisplay.name = name;
          armatureDisplay.path = path.isNotEmpty ? path : name;
          armatureDisplay.inheritAnimation = true;

          if (_has(rawData, DataParser.ACTIONS)) {
            final actions = this._parseActionData(rawData[DataParser.ACTIONS], ActionType.Play, null, null);
            for (final action in actions) {
              armatureDisplay.addAction(action);
            }
          } else if (this._slotChildActions.containsKey(this._slot!.name)) {
            final displays = this._skin!.getDisplays(this._slot!.name);
            if (displays == null ? this._slot!.displayIndex == 0 : this._slot!.displayIndex == displays.length) {
              for (final action in this._slotChildActions[this._slot!.name]!) {
                armatureDisplay.addAction(action);
              }

              this._slotChildActions.remove(this._slot!.name);
            }
          }
          break;
        }

      case DisplayType.Mesh:
        {
          final meshDisplay = MeshDisplayData();
          display = meshDisplay;
          meshDisplay.geometry.inheritDeform = _getBoolean(rawData, DataParser.INHERIT_DEFORM, true);
          meshDisplay.name = name;
          meshDisplay.path = path.isNotEmpty ? path : name;

          if (_has(rawData, DataParser.SHARE)) {
            meshDisplay.geometry.data = this._data;
            this._cacheRawMeshes.add(rawData);
            this._cacheMeshes.add(meshDisplay);
          } else {
            this._parseMesh(rawData, meshDisplay);
          }
          break;
        }

      case DisplayType.BoundingBox:
        {
          final boundingBox = this._parseBoundingBox(rawData);
          if (boundingBox != null) {
            final boundingBoxDisplay = BoundingBoxDisplayData();
            display = boundingBoxDisplay;
            boundingBoxDisplay.name = name;
            boundingBoxDisplay.path = path.isNotEmpty ? path : name;
            boundingBoxDisplay.boundingBox = boundingBox;
          }
          break;
        }

      case DisplayType.Path:
        {
          final rawCurveLengths = rawData[DataParser.LENGTHS] as List<dynamic>;
          final pathDisplay = PathDisplayData();
          display = pathDisplay;
          pathDisplay.closed = _getBoolean(rawData, DataParser.CLOSED, false);
          pathDisplay.constantSpeed = _getBoolean(rawData, DataParser.CONSTANT_SPEED, false);
          pathDisplay.name = name;
          pathDisplay.path = path.isNotEmpty ? path : name;
          pathDisplay.curveLengths.clear();
          _growFloat(pathDisplay.curveLengths, rawCurveLengths.length);

          for (var i = 0, l = rawCurveLengths.length; i < l; ++i) {
            pathDisplay.curveLengths[i] = _number(rawCurveLengths[i], 0.0);
          }

          this._parsePath(rawData, pathDisplay);
          break;
        }
    }

    if (display != null && _has(rawData, DataParser.TRANSFORM)) {
      this._parseTransform(rawData[DataParser.TRANSFORM], display.transform, this._armature!.scale);
    }

    return display;
  }

  void _parsePath(dynamic rawData, PathDisplayData display) {
    this._parseGeometry(rawData, display.geometry);
  }

  void _parsePivot(dynamic rawData, ImageDisplayData display) {
    if (_has(rawData, DataParser.PIVOT)) {
      final rawPivot = rawData[DataParser.PIVOT];
      display.pivot.x = _getNumber(rawPivot, DataParser.X, 0.0);
      display.pivot.y = _getNumber(rawPivot, DataParser.Y, 0.0);
    } else {
      display.pivot.x = 0.5;
      display.pivot.y = 0.5;
    }
  }

  void _parseMesh(dynamic rawData, MeshDisplayData mesh) {
    this._parseGeometry(rawData, mesh.geometry);

    if (_has(rawData, DataParser.WEIGHTS)) {
      // Cache pose data.
      final rawSlotPose = (rawData[DataParser.SLOT_POSE] as List<dynamic>).cast<num>();
      final rawBonePoses = (rawData[DataParser.BONE_POSE] as List<dynamic>).cast<num>();
      final meshName = '${this._skin!.name}_${this._slot!.name}_${mesh.name}';
      this._weightSlotPose[meshName] = rawSlotPose;
      this._weightBonePoses[meshName] = rawBonePoses;
    }
  }

  BoundingBoxData? _parseBoundingBox(dynamic rawData) {
    BoundingBoxData? boundingBox;
    var type = BoundingBoxType.Rectangle;

    if (_has(rawData, DataParser.SUB_TYPE) && rawData[DataParser.SUB_TYPE] is String) {
      type = DataParser._getBoundingBoxType(rawData[DataParser.SUB_TYPE] as String);
    } else {
      type = _getNumber(rawData, DataParser.SUB_TYPE, type.toDouble()).toInt();
    }

    switch (type) {
      case BoundingBoxType.Rectangle:
        boundingBox = RectangleBoundingBoxData();
        break;

      case BoundingBoxType.Ellipse:
        boundingBox = EllipseBoundingBoxData();
        break;

      case BoundingBoxType.Polygon:
        boundingBox = this._parsePolygonBoundingBox(rawData);
        break;
    }

    if (boundingBox != null) {
      boundingBox.color = _getNumber(rawData, DataParser.COLOR, 0x000000.toDouble()).toInt();
      if (boundingBox.type == BoundingBoxType.Rectangle || boundingBox.type == BoundingBoxType.Ellipse) {
        boundingBox.width = _getNumber(rawData, DataParser.WIDTH, 0.0);
        boundingBox.height = _getNumber(rawData, DataParser.HEIGHT, 0.0);
      }
    }

    return boundingBox;
  }

  PolygonBoundingBoxData _parsePolygonBoundingBox(dynamic rawData) {
    final polygonBoundingBox = PolygonBoundingBoxData();

    if (_has(rawData, DataParser.VERTICES)) {
      final scale = this._armature!.scale;
      final rawVertices = rawData[DataParser.VERTICES] as List<dynamic>;
      final vertices = polygonBoundingBox.vertices;
      vertices.clear();
      _growFloat(vertices, rawVertices.length);

      for (var i = 0, l = rawVertices.length; i < l; i += 2) {
        final x = _number(rawVertices[i], 0.0) * scale;
        final y = _number(rawVertices[i + 1], 0.0) * scale;
        vertices[i] = x;
        vertices[i + 1] = y;

        // AABB.
        if (i == 0) {
          polygonBoundingBox.x = x;
          polygonBoundingBox.y = y;
          polygonBoundingBox.width = x;
          polygonBoundingBox.height = y;
        } else {
          if (x < polygonBoundingBox.x) {
            polygonBoundingBox.x = x;
          } else if (x > polygonBoundingBox.width) {
            polygonBoundingBox.width = x;
          }

          if (y < polygonBoundingBox.y) {
            polygonBoundingBox.y = y;
          } else if (y > polygonBoundingBox.height) {
            polygonBoundingBox.height = y;
          }
        }
      }

      polygonBoundingBox.width -= polygonBoundingBox.x;
      polygonBoundingBox.height -= polygonBoundingBox.y;
    } else {
      // Upstream warns: "Data error. Please reexport DragonBones Data...".
    }

    return polygonBoundingBox;
  }

  AnimationData _parseAnimation(dynamic rawData) {
    final animation = AnimationData();
    animation.blendType = DataParser._getAnimationBlendType(_getString(rawData, DataParser.BLEND_TYPE, ''));
    animation.frameCount = _getNumber(rawData, DataParser.DURATION, 0.0).toInt();
    animation.playTimes = _getNumber(rawData, DataParser.PLAY_TIMES, 1.0).toInt();
    animation.duration = animation.frameCount / this._armature!.frameRate; // float
    animation.fadeInTime = _getNumber(rawData, DataParser.FADE_IN_TIME, 0.0);
    animation.scale = _getNumber(rawData, DataParser.SCALE, 1.0);
    animation.name = _getString(rawData, DataParser.NAME, DataParser.DEFAULT_NAME);

    if (animation.name.isEmpty) {
      animation.name = DataParser.DEFAULT_NAME;
    }

    animation.frameIntOffset = this._frameIntArray.length;
    animation.frameFloatOffset = this._frameFloatArray.length;
    animation.frameOffset = this._frameArray.length;
    this._animation = animation;

    if (_has(rawData, DataParser.FRAME)) {
      final rawFrames = rawData[DataParser.FRAME] as List<dynamic>;
      final keyFrameCount = rawFrames.length;

      if (keyFrameCount > 0) {
        var frameStart = 0;
        for (var i = 0; i < keyFrameCount; ++i) {
          final rawFrame = rawFrames[i];
          this._parseActionDataInFrame(rawFrame, frameStart, null, null);
          frameStart += _getNumber(rawFrame, DataParser.DURATION, 1.0).toInt();
        }
      }
    }

    if (_has(rawData, DataParser.Z_ORDER)) {
      this._animation!.zOrderTimeline = this._parseTimeline(rawData[DataParser.Z_ORDER], null, DataParser.FRAME,
          TimelineType.ZOrder, FrameValueType.Step, 0, this._parseZOrderFrame);
    }

    if (_has(rawData, DataParser.BONE)) {
      final rawTimelines = rawData[DataParser.BONE] as List<dynamic>;
      for (final rawTimeline in rawTimelines) {
        this._parseBoneTimeline(rawTimeline);
      }
    }

    if (_has(rawData, DataParser.SLOT)) {
      final rawTimelines = rawData[DataParser.SLOT] as List<dynamic>;
      for (final rawTimeline in rawTimelines) {
        this._parseSlotTimeline(rawTimeline);
      }
    }

    if (_has(rawData, DataParser.FFD)) {
      final rawTimelines = rawData[DataParser.FFD] as List<dynamic>;
      for (final rawTimeline in rawTimelines) {
        var skinName = _getString(rawTimeline, DataParser.SKIN, DataParser.DEFAULT_NAME);
        final slotName = _getString(rawTimeline, DataParser.SLOT, '');
        final displayName = _getString(rawTimeline, DataParser.NAME, '');

        if (skinName.isEmpty) {
          skinName = DataParser.DEFAULT_NAME;
        }

        this._slot = this._armature!.getSlot(slotName);
        this._mesh = this._armature!.getMesh(skinName, slotName, displayName);
        if (this._slot == null || this._mesh == null) {
          continue;
        }

        final timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, TimelineType.SlotDeform,
            FrameValueType.Float, 0, this._parseSlotDeformFrame);

        if (timeline != null) {
          this._animation!.addSlotTimeline(slotName, timeline);
        }

        this._slot = null;
        this._mesh = null;
      }
    }

    if (_has(rawData, DataParser.IK)) {
      final rawTimelines = rawData[DataParser.IK] as List<dynamic>;
      for (final rawTimeline in rawTimelines) {
        final constraintName = _getString(rawTimeline, DataParser.NAME, '');
        final constraint = this._armature!.getConstraint(constraintName);
        if (constraint == null) {
          continue;
        }

        final timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, TimelineType.IKConstraint,
            FrameValueType.Int, 2, this._parseIKConstraintFrame);

        if (timeline != null) {
          this._animation!.addConstraintTimeline(constraintName, timeline);
        }
      }
    }

    if (this._actionFrames.length > 0) {
      this._animation!.actionTimeline = this._parseTimeline(
          null, this._actionFrames, '', TimelineType.Action, FrameValueType.Step, 0, this._parseActionFrame);
      this._actionFrames.length = 0;
    }

    if (_has(rawData, DataParser.TIMELINE)) {
      final rawTimelines = rawData[DataParser.TIMELINE] as List<dynamic>;
      for (final rawTimeline in rawTimelines) {
        final timelineType = _getNumber(rawTimeline, DataParser.TYPE, TimelineType.Action.toDouble()).toInt();
        final timelineName = _getString(rawTimeline, DataParser.NAME, '');
        TimelineData? timeline;

        switch (timelineType) {
          case TimelineType.Action:
            // TODO
            break;

          case TimelineType.SlotDisplay:
          case TimelineType.SlotZIndex:
          case TimelineType.BoneAlpha:
          case TimelineType.SlotAlpha:
          case TimelineType.AnimationProgress:
          case TimelineType.AnimationWeight:
            if (timelineType == TimelineType.SlotDisplay) {
              this._frameValueType = FrameValueType.Step;
              this._frameValueScale = 1.0;
            } else {
              this._frameValueType = FrameValueType.Int;

              if (timelineType == TimelineType.SlotZIndex) {
                this._frameValueScale = 1.0;
              } else if (timelineType == TimelineType.AnimationProgress ||
                  timelineType == TimelineType.AnimationWeight) {
                this._frameValueScale = 10000.0;
              } else {
                this._frameValueScale = 100.0;
              }
            }

            if (timelineType == TimelineType.BoneAlpha ||
                timelineType == TimelineType.SlotAlpha ||
                timelineType == TimelineType.AnimationWeight) {
              this._frameDefaultValue = 1.0;
            } else {
              this._frameDefaultValue = 0.0;
            }

            if (timelineType == TimelineType.AnimationProgress && animation.blendType != AnimationBlendType.None) {
              timeline = AnimationTimelineData();
              final animationTimeline = timeline as AnimationTimelineData;
              animationTimeline.x = _getNumber(rawTimeline, DataParser.X, 0.0);
              animationTimeline.y = _getNumber(rawTimeline, DataParser.Y, 0.0);
            }

            timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, timelineType, this._frameValueType, 1,
                this._parseSingleValueFrame, timeline);
            break;

          case TimelineType.BoneTranslate:
          case TimelineType.BoneRotate:
          case TimelineType.BoneScale:
          case TimelineType.IKConstraint:
          case TimelineType.AnimationParameter:
            if (timelineType == TimelineType.IKConstraint || timelineType == TimelineType.AnimationParameter) {
              this._frameValueType = FrameValueType.Int;

              if (timelineType == TimelineType.AnimationParameter) {
                this._frameValueScale = 10000.0;
              } else {
                this._frameValueScale = 100.0;
              }
            } else {
              if (timelineType == TimelineType.BoneRotate) {
                this._frameValueScale = Transform.DEG_RAD;
              } else {
                this._frameValueScale = 1.0;
              }

              this._frameValueType = FrameValueType.Float;
            }

            if (timelineType == TimelineType.BoneScale || timelineType == TimelineType.IKConstraint) {
              this._frameDefaultValue = 1.0;
            } else {
              this._frameDefaultValue = 0.0;
            }

            timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, timelineType, this._frameValueType, 2,
                this._parseDoubleValueFrame);
            break;

          case TimelineType.ZOrder:
            // TODO
            break;

          case TimelineType.Surface:
            {
              final surface = this._armature!.getBone(timelineName) as SurfaceData?;
              if (surface == null) {
                continue;
              }

              this._geometry = surface.geometry;
              timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, timelineType, FrameValueType.Float, 0,
                  this._parseDeformFrame);

              this._geometry = null;
              break;
            }

          case TimelineType.SlotDeform:
            {
              this._geometry = null;
              for (final skinName in this._armature!.skins.keys) {
                final skin = this._armature!.skins[skinName]!;
                for (final slotName in skin.displays.keys) {
                  final displays = skin.displays[slotName]!;
                  for (final display in displays) {
                    if (display != null && display.name == timelineName) {
                      this._geometry = (display as MeshDisplayData).geometry;
                      break;
                    }
                  }
                }
              }

              if (this._geometry == null) {
                continue;
              }

              timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, timelineType, FrameValueType.Float, 0,
                  this._parseDeformFrame);

              this._geometry = null;
              break;
            }

          case TimelineType.SlotColor:
            timeline = this._parseTimeline(rawTimeline, null, DataParser.FRAME, timelineType, FrameValueType.Int, 1,
                this._parseSlotColorFrame);
            break;
        }

        if (timeline != null) {
          switch (timelineType) {
            case TimelineType.Action:
              // TODO
              break;

            case TimelineType.ZOrder:
              // TODO
              break;

            case TimelineType.BoneTranslate:
            case TimelineType.BoneRotate:
            case TimelineType.BoneScale:
            case TimelineType.Surface:
            case TimelineType.BoneAlpha:
              this._animation!.addBoneTimeline(timelineName, timeline);
              break;

            case TimelineType.SlotDisplay:
            case TimelineType.SlotColor:
            case TimelineType.SlotDeform:
            case TimelineType.SlotZIndex:
            case TimelineType.SlotAlpha:
              this._animation!.addSlotTimeline(timelineName, timeline);
              break;

            case TimelineType.IKConstraint:
              this._animation!.addConstraintTimeline(timelineName, timeline);
              break;

            case TimelineType.AnimationProgress:
            case TimelineType.AnimationWeight:
            case TimelineType.AnimationParameter:
              this._animation!.addAnimationTimeline(timelineName, timeline);
              break;
          }
        }
      }
    }

    this._animation = null;

    return animation;
  }

  TimelineData? _parseTimeline(
      dynamic rawData,
      List<dynamic>? rawFrames,
      String framesKey,
      int timelineType,
      int frameValueType,
      int frameValueCount,
      int Function(dynamic rawData, int frameStart, int frameCount) frameParser,
      [TimelineData? timeline]) {
    if (rawData != null && framesKey.isNotEmpty && _has(rawData, framesKey)) {
      rawFrames = rawData[framesKey] as List<dynamic>?;
    }

    if (rawFrames == null) {
      return null;
    }

    final keyFrameCount = rawFrames.length;
    if (keyFrameCount == 0) {
      return null;
    }

    final frameIntArrayLength = this._frameIntArray.length;
    final frameFloatArrayLength = this._frameFloatArray.length;
    final timelineOffset = this._timelineArray.length;
    if (timeline == null) {
      timeline = TimelineData();
    }

    timeline.type = timelineType;
    timeline.offset = timelineOffset;
    this._frameValueType = frameValueType;
    this._timeline = timeline;
    _growInt(this._timelineArray, 1 + 1 + 1 + 1 + 1 + keyFrameCount);

    if (rawData != null) {
      this._timelineArray[timelineOffset + BinaryOffset.TimelineScale] =
          _jsRound(_getNumber(rawData, DataParser.SCALE, 1.0) * 100.0).toInt();
      this._timelineArray[timelineOffset + BinaryOffset.TimelineOffset] =
          _jsRound(_getNumber(rawData, DataParser.OFFSET, 0.0) * 100.0).toInt();
    } else {
      this._timelineArray[timelineOffset + BinaryOffset.TimelineScale] = 100;
      this._timelineArray[timelineOffset + BinaryOffset.TimelineOffset] = 0;
    }

    this._timelineArray[timelineOffset + BinaryOffset.TimelineKeyFrameCount] = keyFrameCount;
    this._timelineArray[timelineOffset + BinaryOffset.TimelineFrameValueCount] = frameValueCount;

    switch (this._frameValueType) {
      case FrameValueType.Step:
        this._timelineArray[timelineOffset + BinaryOffset.TimelineFrameValueOffset] = 0;
        break;

      case FrameValueType.Int:
        this._timelineArray[timelineOffset + BinaryOffset.TimelineFrameValueOffset] =
            frameIntArrayLength - this._animation!.frameIntOffset;
        break;

      case FrameValueType.Float:
        this._timelineArray[timelineOffset + BinaryOffset.TimelineFrameValueOffset] =
            frameFloatArrayLength - this._animation!.frameFloatOffset;
        break;
    }

    if (keyFrameCount == 1) {
      // Only one frame.
      timeline.frameIndicesOffset = -1;
      this._timelineArray[timelineOffset + BinaryOffset.TimelineFrameOffset + 0] =
          frameParser(rawFrames[0], 0, 0) - this._animation!.frameOffset;
    } else {
      final totalFrameCount = this._animation!.frameCount + 1; // One more frame than animation.
      final frameIndices = this._data!.frameIndices;
      final frameIndicesOffset = frameIndices.length;
      _growInt(frameIndices, totalFrameCount);
      timeline.frameIndicesOffset = frameIndicesOffset;

      var iK = 0;
      var frameStart = 0;
      var frameCount = 0;
      for (var i = 0; i < totalFrameCount; ++i) {
        if (frameStart + frameCount <= i && iK < keyFrameCount) {
          final rawFrame = rawFrames[iK];
          frameStart = i; // frame.frameStart;

          if (iK == keyFrameCount - 1) {
            frameCount = this._animation!.frameCount - frameStart;
          } else {
            if (rawFrame is ActionFrame) {
              frameCount = this._actionFrames[iK + 1].frameStart - frameStart;
            } else {
              frameCount = _getNumber(rawFrame, DataParser.DURATION, 1.0).toInt();
            }
          }

          this._timelineArray[timelineOffset + BinaryOffset.TimelineFrameOffset + iK] =
              frameParser(rawFrame, frameStart, frameCount) - this._animation!.frameOffset;
          iK++;
        }

        frameIndices[frameIndicesOffset + i] = iK - 1;
      }
    }

    this._timeline = null;

    return timeline;
  }

  void _parseBoneTimeline(dynamic rawData) {
    final bone = this._armature!.getBone(_getString(rawData, DataParser.NAME, ''));
    if (bone == null) {
      return;
    }

    this._bone = bone;
    this._slot = this._armature!.getSlot(this._bone!.name);

    if (_has(rawData, DataParser.TRANSLATE_FRAME)) {
      this._frameDefaultValue = 0.0;
      this._frameValueScale = 1.0;
      final timeline = this._parseTimeline(rawData, null, DataParser.TRANSLATE_FRAME, TimelineType.BoneTranslate,
          FrameValueType.Float, 2, this._parseDoubleValueFrame);

      if (timeline != null) {
        this._animation!.addBoneTimeline(bone.name, timeline);
      }
    }

    if (_has(rawData, DataParser.ROTATE_FRAME)) {
      this._frameDefaultValue = 0.0;
      this._frameValueScale = 1.0;
      final timeline = this._parseTimeline(rawData, null, DataParser.ROTATE_FRAME, TimelineType.BoneRotate,
          FrameValueType.Float, 2, this._parseBoneRotateFrame);

      if (timeline != null) {
        this._animation!.addBoneTimeline(bone.name, timeline);
      }
    }

    if (_has(rawData, DataParser.SCALE_FRAME)) {
      this._frameDefaultValue = 1.0;
      this._frameValueScale = 1.0;
      final timeline = this._parseTimeline(rawData, null, DataParser.SCALE_FRAME, TimelineType.BoneScale,
          FrameValueType.Float, 2, this._parseBoneScaleFrame);

      if (timeline != null) {
        this._animation!.addBoneTimeline(bone.name, timeline);
      }
    }

    if (_has(rawData, DataParser.FRAME)) {
      final timeline = this._parseTimeline(
          rawData, null, DataParser.FRAME, TimelineType.BoneAll, FrameValueType.Float, 6, this._parseBoneAllFrame);

      if (timeline != null) {
        this._animation!.addBoneTimeline(bone.name, timeline);
      }
    }

    this._bone = null;
    this._slot = null;
  }

  void _parseSlotTimeline(dynamic rawData) {
    final slot = this._armature!.getSlot(_getString(rawData, DataParser.NAME, ''));
    if (slot == null) {
      return;
    }

    TimelineData? displayTimeline;
    TimelineData? colorTimeline;
    this._slot = slot;

    if (_has(rawData, DataParser.DISPLAY_FRAME)) {
      displayTimeline = this._parseTimeline(rawData, null, DataParser.DISPLAY_FRAME, TimelineType.SlotDisplay,
          FrameValueType.Step, 0, this._parseSlotDisplayFrame);
    } else {
      displayTimeline = this._parseTimeline(rawData, null, DataParser.FRAME, TimelineType.SlotDisplay,
          FrameValueType.Step, 0, this._parseSlotDisplayFrame);
    }

    if (_has(rawData, DataParser.COLOR_FRAME)) {
      colorTimeline = this._parseTimeline(rawData, null, DataParser.COLOR_FRAME, TimelineType.SlotColor,
          FrameValueType.Int, 1, this._parseSlotColorFrame);
    } else {
      colorTimeline = this._parseTimeline(rawData, null, DataParser.FRAME, TimelineType.SlotColor,
          FrameValueType.Int, 1, this._parseSlotColorFrame);
    }

    if (displayTimeline != null) {
      this._animation!.addSlotTimeline(slot.name, displayTimeline);
    }

    if (colorTimeline != null) {
      this._animation!.addSlotTimeline(slot.name, colorTimeline);
    }

    this._slot = null;
  }

  int _parseFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._frameArray.length;
    _growInt(this._frameArray, 1);
    this._frameArray[frameOffset + BinaryOffset.FramePosition] = frameStart;

    return frameOffset;
  }

  int _parseTweenFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseFrame(rawData, frameStart, frameCount);

    if (frameCount > 0) {
      if (_has(rawData, DataParser.CURVE)) {
        final sampleCount = frameCount + 1;
        this._helpArray.clear();
        _growFloat(this._helpArray, sampleCount);
        final isOmited = this._samplingEasingCurve((rawData[DataParser.CURVE] as List<dynamic>).cast<num>(), this._helpArray);

        _growInt(this._frameArray, 1 + 1 + this._helpArray.length);
        this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.Curve;
        this._frameArray[frameOffset + BinaryOffset.FrameTweenEasingOrCurveSampleCount] =
            isOmited ? sampleCount : -sampleCount;
        for (var i = 0; i < sampleCount; ++i) {
          this._frameArray[frameOffset + BinaryOffset.FrameCurveSamples + i] =
              _jsRound(this._helpArray[i] * 10000.0).toInt();
        }
      } else {
        final noTween = -2.0;
        var tweenEasing = noTween;
        if (_has(rawData, DataParser.TWEEN_EASING)) {
          tweenEasing = _getNumber(rawData, DataParser.TWEEN_EASING, noTween);
        }

        if (tweenEasing == noTween) {
          _growInt(this._frameArray, 1);
          this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.None;
        } else if (tweenEasing == 0.0) {
          _growInt(this._frameArray, 1);
          this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.Line;
        } else if (tweenEasing < 0.0) {
          _growInt(this._frameArray, 1 + 1);
          this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.QuadIn;
          this._frameArray[frameOffset + BinaryOffset.FrameTweenEasingOrCurveSampleCount] =
              _jsRound(-tweenEasing * 100.0).toInt();
        } else if (tweenEasing <= 1.0) {
          _growInt(this._frameArray, 1 + 1);
          this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.QuadOut;
          this._frameArray[frameOffset + BinaryOffset.FrameTweenEasingOrCurveSampleCount] =
              _jsRound(tweenEasing * 100.0).toInt();
        } else {
          _growInt(this._frameArray, 1 + 1);
          this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.QuadInOut;
          this._frameArray[frameOffset + BinaryOffset.FrameTweenEasingOrCurveSampleCount] =
              _jsRound(tweenEasing * 100.0 - 100.0).toInt();
        }
      }
    } else {
      _growInt(this._frameArray, 1);
      this._frameArray[frameOffset + BinaryOffset.FrameTweenType] = TweenType.None;
    }

    return frameOffset;
  }

  int _parseSingleValueFrame(dynamic rawData, int frameStart, int frameCount) {
    var frameOffset = 0;
    switch (this._frameValueType) {
      case 0:
        {
          frameOffset = this._parseFrame(rawData, frameStart, frameCount);
          _growInt(this._frameArray, 1);
          this._frameArray[frameOffset + 1] =
              _getNumber(rawData, DataParser.VALUE, this._frameDefaultValue).toInt();
          break;
        }

      case 1:
        {
          frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
          final frameValueOffset = this._frameIntArray.length;
          _growInt(this._frameIntArray, 1);
          this._frameIntArray[frameValueOffset] =
              _jsRound(_getNumber(rawData, DataParser.VALUE, this._frameDefaultValue) * this._frameValueScale).toInt();
          break;
        }

      case 2:
        {
          frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
          final frameValueOffset = this._frameFloatArray.length;
          _growFloat(this._frameFloatArray, 1);
          this._frameFloatArray[frameValueOffset] =
              _getNumber(rawData, DataParser.VALUE, this._frameDefaultValue) * this._frameValueScale;
          break;
        }
    }

    return frameOffset;
  }

  int _parseDoubleValueFrame(dynamic rawData, int frameStart, int frameCount) {
    var frameOffset = 0;
    switch (this._frameValueType) {
      case 0:
        {
          frameOffset = this._parseFrame(rawData, frameStart, frameCount);
          _growInt(this._frameArray, 2);
          this._frameArray[frameOffset + 1] = _getNumber(rawData, DataParser.X, this._frameDefaultValue).toInt();
          this._frameArray[frameOffset + 2] = _getNumber(rawData, DataParser.Y, this._frameDefaultValue).toInt();
          break;
        }

      case 1:
        {
          frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
          final frameValueOffset = this._frameIntArray.length;
          _growInt(this._frameIntArray, 2);
          this._frameIntArray[frameValueOffset] =
              _jsRound(_getNumber(rawData, DataParser.X, this._frameDefaultValue) * this._frameValueScale).toInt();
          this._frameIntArray[frameValueOffset + 1] =
              _jsRound(_getNumber(rawData, DataParser.Y, this._frameDefaultValue) * this._frameValueScale).toInt();
          break;
        }

      case 2:
        {
          frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
          final frameValueOffset = this._frameFloatArray.length;
          _growFloat(this._frameFloatArray, 2);
          this._frameFloatArray[frameValueOffset] =
              _getNumber(rawData, DataParser.X, this._frameDefaultValue) * this._frameValueScale;
          this._frameFloatArray[frameValueOffset + 1] =
              _getNumber(rawData, DataParser.Y, this._frameDefaultValue) * this._frameValueScale;
          break;
        }
    }

    return frameOffset;
  }

  int _parseActionFrame(dynamic frame, int frameStart, int frameCount) {
    final actionFrame = frame as ActionFrame;
    final frameOffset = this._frameArray.length;
    final actionCount = actionFrame.actions.length;
    _growInt(this._frameArray, 1 + 1 + actionCount);
    this._frameArray[frameOffset + BinaryOffset.FramePosition] = frameStart;
    this._frameArray[frameOffset + BinaryOffset.FramePosition + 1] = actionCount; // Action count.

    for (var i = 0; i < actionCount; ++i) {
      // Action offsets.
      this._frameArray[frameOffset + BinaryOffset.FramePosition + 2 + i] = actionFrame.actions[i];
    }

    return frameOffset;
  }

  int _parseZOrderFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseFrame(rawData, frameStart, frameCount);

    if (_has(rawData, DataParser.Z_ORDER)) {
      final rawZOrder = rawData[DataParser.Z_ORDER] as List<dynamic>;
      if (rawZOrder.isNotEmpty) {
        final slotCount = this._armature!.sortedSlots.length;
        final unchanged = List<int>.filled(slotCount - (rawZOrder.length ~/ 2), 0);
        final zOrders = List<int>.filled(slotCount, 0);

        for (var i = 0; i < slotCount; ++i) {
          zOrders[i] = -1;
        }

        var originalIndex = 0;
        var unchangedIndex = 0;
        for (var i = 0, l = rawZOrder.length; i < l; i += 2) {
          final slotIndex = _intOf(rawZOrder[i]);
          final zOrderOffset = _intOf(rawZOrder[i + 1]);

          while (originalIndex != slotIndex) {
            unchanged[unchangedIndex++] = originalIndex++;
          }

          final index = originalIndex + zOrderOffset;
          zOrders[index] = originalIndex++;
        }

        while (originalIndex < slotCount) {
          unchanged[unchangedIndex++] = originalIndex++;
        }

        _growInt(this._frameArray, 1 + slotCount);
        this._frameArray[frameOffset + 1] = slotCount;

        var i = slotCount;
        while (i-- > 0) {
          if (zOrders[i] == -1) {
            this._frameArray[frameOffset + 2 + i] = unchanged[--unchangedIndex];
          } else {
            this._frameArray[frameOffset + 2 + i] = zOrders[i];
          }
        }

        return frameOffset;
      }
    }

    _growInt(this._frameArray, 1);
    this._frameArray[frameOffset + 1] = 0;

    return frameOffset;
  }

  int _parseBoneAllFrame(dynamic rawData, int frameStart, int frameCount) {
    this._helpTransform.identity();
    if (_has(rawData, DataParser.TRANSFORM)) {
      this._parseTransform(rawData[DataParser.TRANSFORM], this._helpTransform, 1.0);
    }

    // Modify rotation.
    var rotation = this._helpTransform.rotation;
    if (frameStart != 0) {
      if (this._prevClockwise == 0.0) {
        rotation = this._prevRotation + Transform.normalizeRadian(rotation - this._prevRotation);
      } else {
        if (this._prevClockwise > 0.0 ? rotation >= this._prevRotation : rotation <= this._prevRotation) {
          this._prevClockwise = this._prevClockwise > 0.0 ? this._prevClockwise - 1.0 : this._prevClockwise + 1.0;
        }

        rotation = this._prevRotation + rotation - this._prevRotation + Transform.PI_D * this._prevClockwise;
      }
    }

    this._prevClockwise = _getNumber(rawData, DataParser.TWEEN_ROTATE, 0.0);
    this._prevRotation = rotation;
    //
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    var frameFloatOffset = this._frameFloatArray.length;
    _growFloat(this._frameFloatArray, 6);
    this._frameFloatArray[frameFloatOffset++] = this._helpTransform.x;
    this._frameFloatArray[frameFloatOffset++] = this._helpTransform.y;
    this._frameFloatArray[frameFloatOffset++] = rotation;
    this._frameFloatArray[frameFloatOffset++] = this._helpTransform.skew;
    this._frameFloatArray[frameFloatOffset++] = this._helpTransform.scaleX;
    this._frameFloatArray[frameFloatOffset++] = this._helpTransform.scaleY;
    this._parseActionDataInFrame(rawData, frameStart, this._bone, this._slot);

    return frameOffset;
  }

  int _parseBoneTranslateFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    var frameFloatOffset = this._frameFloatArray.length;
    _growFloat(this._frameFloatArray, 2);
    this._frameFloatArray[frameFloatOffset++] = _getNumber(rawData, DataParser.X, 0.0);
    this._frameFloatArray[frameFloatOffset++] = _getNumber(rawData, DataParser.Y, 0.0);

    return frameOffset;
  }

  int _parseBoneRotateFrame(dynamic rawData, int frameStart, int frameCount) {
    // Modify rotation.
    var rotation = _getNumber(rawData, DataParser.ROTATE, 0.0) * Transform.DEG_RAD;

    if (frameStart != 0) {
      if (this._prevClockwise == 0.0) {
        rotation = this._prevRotation + Transform.normalizeRadian(rotation - this._prevRotation);
      } else {
        if (this._prevClockwise > 0.0 ? rotation >= this._prevRotation : rotation <= this._prevRotation) {
          this._prevClockwise = this._prevClockwise > 0.0 ? this._prevClockwise - 1.0 : this._prevClockwise + 1.0;
        }

        rotation = this._prevRotation + rotation - this._prevRotation + Transform.PI_D * this._prevClockwise;
      }
    }

    this._prevClockwise = _getNumber(rawData, DataParser.CLOCK_WISE, 0.0);
    this._prevRotation = rotation;
    //
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    var frameFloatOffset = this._frameFloatArray.length;
    _growFloat(this._frameFloatArray, 2);
    this._frameFloatArray[frameFloatOffset++] = rotation;
    this._frameFloatArray[frameFloatOffset++] = _getNumber(rawData, DataParser.SKEW, 0.0) * Transform.DEG_RAD;

    return frameOffset;
  }

  int _parseBoneScaleFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    var frameFloatOffset = this._frameFloatArray.length;
    _growFloat(this._frameFloatArray, 2);
    this._frameFloatArray[frameFloatOffset++] = _getNumber(rawData, DataParser.X, 1.0);
    this._frameFloatArray[frameFloatOffset++] = _getNumber(rawData, DataParser.Y, 1.0);

    return frameOffset;
  }

  int _parseSlotDisplayFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseFrame(rawData, frameStart, frameCount);
    _growInt(this._frameArray, 1);

    if (_has(rawData, DataParser.VALUE)) {
      this._frameArray[frameOffset + 1] = _getNumber(rawData, DataParser.VALUE, 0.0).toInt();
    } else {
      this._frameArray[frameOffset + 1] = _getNumber(rawData, DataParser.DISPLAY_INDEX, 0.0).toInt();
    }

    this._parseActionDataInFrame(rawData, frameStart, this._slot!.parent, this._slot);

    return frameOffset;
  }

  int _parseSlotColorFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    var colorOffset = -1;

    if (_has(rawData, DataParser.VALUE) || _has(rawData, DataParser.COLOR)) {
      final rawColor = _has(rawData, DataParser.VALUE) ? rawData[DataParser.VALUE] : rawData[DataParser.COLOR];
      if (rawColor is Map) {
        for (final k in rawColor.keys) {
          // Detects the presence of color.
          k;
          this._parseColorTransform(rawColor, this._helpColorTransform);
          colorOffset = this._colorArray.length;
          _growInt(this._colorArray, 8);
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.alphaMultiplier * 100.0).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.redMultiplier * 100.0).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.greenMultiplier * 100.0).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.blueMultiplier * 100.0).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.alphaOffset).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.redOffset).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.greenOffset).toInt();
          this._colorArray[colorOffset++] = _jsRound(this._helpColorTransform.blueOffset).toInt();
          colorOffset -= 8;
          break;
        }
      }
    }

    if (colorOffset < 0) {
      if (this._defaultColorOffset < 0) {
        this._defaultColorOffset = colorOffset = this._colorArray.length;
        _growInt(this._colorArray, 8);
        this._colorArray[colorOffset++] = 100;
        this._colorArray[colorOffset++] = 100;
        this._colorArray[colorOffset++] = 100;
        this._colorArray[colorOffset++] = 100;
        this._colorArray[colorOffset++] = 0;
        this._colorArray[colorOffset++] = 0;
        this._colorArray[colorOffset++] = 0;
        this._colorArray[colorOffset++] = 0;
      }

      colorOffset = this._defaultColorOffset;
    }

    final frameIntOffset = this._frameIntArray.length;
    _growInt(this._frameIntArray, 1);
    this._frameIntArray[frameIntOffset] = colorOffset;

    return frameOffset;
  }

  int _parseSlotDeformFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameFloatOffset = this._frameFloatArray.length;
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    final rawVertices = _has(rawData, DataParser.VERTICES) ? rawData[DataParser.VERTICES] as List<dynamic> : null;
    final offset = _getNumber(rawData, DataParser.OFFSET, 0.0).toInt(); // uint
    final vertexCount = this._intArray[this._mesh!.geometry.offset + BinaryOffset.GeometryVertexCount];
    final meshName = '${this._mesh!.parent!.name}_${this._slot!.name}_${this._mesh!.name}';
    final weight = this._mesh!.geometry.weight;

    var x = 0.0;
    var y = 0.0;
    var iB = 0;
    var iV = 0;
    if (weight != null) {
      final rawSlotPose = this._weightSlotPose[meshName]!;
      this._helpMatrixA.copyFromArray(rawSlotPose, 0);
      _growFloat(this._frameFloatArray, weight.count * 2);
      iB = weight.offset + BinaryOffset.WeigthBoneIndices + weight.bones.length;
    } else {
      _growFloat(this._frameFloatArray, vertexCount * 2);
    }

    for (var i = 0; i < vertexCount * 2; i += 2) {
      if (rawVertices == null) {
        // Fill 0.
        x = 0.0;
        y = 0.0;
      } else {
        if (i < offset || i - offset >= rawVertices.length) {
          x = 0.0;
        } else {
          x = _number(rawVertices[i - offset], 0.0);
        }

        if (i + 1 < offset || i + 1 - offset >= rawVertices.length) {
          y = 0.0;
        } else {
          y = _number(rawVertices[i + 1 - offset], 0.0);
        }
      }

      if (weight != null) {
        // If mesh is skinned, transform point by bone bind pose.
        final rawBonePoses = this._weightBonePoses[meshName]!;
        final vertexBoneCount = this._intArray[iB++];

        this._helpMatrixA.transformPoint(x, y, this._helpPoint, true);
        x = this._helpPoint.x;
        y = this._helpPoint.y;

        for (var j = 0; j < vertexBoneCount; ++j) {
          final boneIndex = this._intArray[iB++];
          this._helpMatrixB.copyFromArray(rawBonePoses, boneIndex * 7 + 1);
          this._helpMatrixB.invert();
          this._helpMatrixB.transformPoint(x, y, this._helpPoint, true);

          this._frameFloatArray[frameFloatOffset + iV++] = this._helpPoint.x;
          this._frameFloatArray[frameFloatOffset + iV++] = this._helpPoint.y;
        }
      } else {
        this._frameFloatArray[frameFloatOffset + i] = x;
        this._frameFloatArray[frameFloatOffset + i + 1] = y;
      }
    }

    if (frameStart == 0) {
      final frameIntOffset = this._frameIntArray.length;
      _growInt(this._frameIntArray, 1 + 1 + 1 + 1 + 1);
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformVertexOffset] = this._mesh!.geometry.offset;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformCount] = this._frameFloatArray.length - frameFloatOffset;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformValueCount] =
          this._frameFloatArray.length - frameFloatOffset;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformValueOffset] = 0;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformFloatOffset] =
          frameFloatOffset - this._animation!.frameFloatOffset;
      this._timelineArray[this._timeline!.offset + BinaryOffset.TimelineFrameValueCount] =
          frameIntOffset - this._animation!.frameIntOffset;
    }

    return frameOffset;
  }

  int _parseIKConstraintFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    var frameIntOffset = this._frameIntArray.length;
    _growInt(this._frameIntArray, 2);
    this._frameIntArray[frameIntOffset++] = _getBoolean(rawData, DataParser.BEND_POSITIVE, true) ? 1 : 0;
    this._frameIntArray[frameIntOffset++] = _jsRound(_getNumber(rawData, DataParser.WEIGHT, 1.0) * 100.0).toInt();

    return frameOffset;
  }

  List<ActionData> _parseActionData(dynamic rawData, int type, BoneData? bone, SlotData? slot) {
    final actions = <ActionData>[];

    if (rawData is String) {
      final action = ActionData();
      action.type = type;
      action.name = rawData;
      action.bone = bone;
      action.slot = slot;
      actions.add(action);
    } else if (rawData is List) {
      for (final rawAction in rawData) {
        final action = ActionData();

        if (_has(rawAction, DataParser.GOTO_AND_PLAY)) {
          action.type = ActionType.Play;
          action.name = _getString(rawAction, DataParser.GOTO_AND_PLAY, '');
        } else {
          if (_has(rawAction, DataParser.TYPE) && rawAction[DataParser.TYPE] is String) {
            action.type = DataParser._getActionType(rawAction[DataParser.TYPE] as String);
          } else {
            action.type = _getNumber(rawAction, DataParser.TYPE, type.toDouble()).toInt();
          }

          action.name = _getString(rawAction, DataParser.NAME, '');
        }

        if (_has(rawAction, DataParser.BONE)) {
          final boneName = _getString(rawAction, DataParser.BONE, '');
          action.bone = this._armature!.getBone(boneName);
        } else {
          action.bone = bone;
        }

        if (_has(rawAction, DataParser.SLOT)) {
          final slotName = _getString(rawAction, DataParser.SLOT, '');
          action.slot = this._armature!.getSlot(slotName);
        } else {
          action.slot = slot;
        }

        UserData? userData;

        if (_has(rawAction, DataParser.INTS)) {
          userData ??= UserData();

          final rawInts = rawAction[DataParser.INTS] as List<dynamic>;
          for (final rawValue in rawInts) {
            userData.addInt(_number(rawValue, 0.0));
          }
        }

        if (_has(rawAction, DataParser.FLOATS)) {
          userData ??= UserData();

          final rawFloats = rawAction[DataParser.FLOATS] as List<dynamic>;
          for (final rawValue in rawFloats) {
            userData.addFloat(_number(rawValue, 0.0));
          }
        }

        if (_has(rawAction, DataParser.STRINGS)) {
          userData ??= UserData();

          final rawStrings = rawAction[DataParser.STRINGS] as List<dynamic>;
          for (final rawValue in rawStrings) {
            userData.addString(rawValue as String);
          }
        }

        action.data = userData;
        actions.add(action);
      }
    }

    return actions;
  }

  int _parseDeformFrame(dynamic rawData, int frameStart, int frameCount) {
    final frameFloatOffset = this._frameFloatArray.length;
    final frameOffset = this._parseTweenFrame(rawData, frameStart, frameCount);
    final rawVertices = _has(rawData, DataParser.VERTICES)
        ? rawData[DataParser.VERTICES] as List<dynamic>
        : (_has(rawData, DataParser.VALUE) ? rawData[DataParser.VALUE] as List<dynamic> : null);
    final offset = _getNumber(rawData, DataParser.OFFSET, 0.0).toInt(); // uint
    final vertexCount = this._intArray[this._geometry!.offset + BinaryOffset.GeometryVertexCount];
    final weight = this._geometry!.weight;
    var x = 0.0;
    var y = 0.0;

    if (weight != null) {
      // TODO
    } else {
      _growFloat(this._frameFloatArray, vertexCount * 2);

      for (var i = 0; i < vertexCount * 2; i += 2) {
        if (rawVertices != null) {
          if (i < offset || i - offset >= rawVertices.length) {
            x = 0.0;
          } else {
            x = _number(rawVertices[i - offset], 0.0);
          }

          if (i + 1 < offset || i + 1 - offset >= rawVertices.length) {
            y = 0.0;
          } else {
            y = _number(rawVertices[i + 1 - offset], 0.0);
          }
        } else {
          x = 0.0;
          y = 0.0;
        }

        this._frameFloatArray[frameFloatOffset + i] = x;
        this._frameFloatArray[frameFloatOffset + i + 1] = y;
      }
    }

    if (frameStart == 0) {
      final frameIntOffset = this._frameIntArray.length;
      _growInt(this._frameIntArray, 1 + 1 + 1 + 1 + 1);
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformVertexOffset] = this._geometry!.offset;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformCount] = this._frameFloatArray.length - frameFloatOffset;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformValueCount] =
          this._frameFloatArray.length - frameFloatOffset;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformValueOffset] = 0;
      this._frameIntArray[frameIntOffset + BinaryOffset.DeformFloatOffset] =
          frameFloatOffset - this._animation!.frameFloatOffset;
      this._timelineArray[this._timeline!.offset + BinaryOffset.TimelineFrameValueCount] =
          frameIntOffset - this._animation!.frameIntOffset;
    }

    return frameOffset;
  }

  void _parseTransform(dynamic rawData, Transform transform, double scale) {
    transform.x = _getNumber(rawData, DataParser.X, 0.0) * scale;
    transform.y = _getNumber(rawData, DataParser.Y, 0.0) * scale;

    if (_has(rawData, DataParser.ROTATE) || _has(rawData, DataParser.SKEW)) {
      transform.rotation = Transform.normalizeRadian(_getNumber(rawData, DataParser.ROTATE, 0.0) * Transform.DEG_RAD);
      transform.skew = Transform.normalizeRadian(_getNumber(rawData, DataParser.SKEW, 0.0) * Transform.DEG_RAD);
    } else if (_has(rawData, DataParser.SKEW_X) || _has(rawData, DataParser.SKEW_Y)) {
      transform.rotation = Transform.normalizeRadian(_getNumber(rawData, DataParser.SKEW_Y, 0.0) * Transform.DEG_RAD);
      transform.skew = Transform.normalizeRadian(_getNumber(rawData, DataParser.SKEW_X, 0.0) * Transform.DEG_RAD) -
          transform.rotation;
    }

    transform.scaleX = _getNumber(rawData, DataParser.SCALE_X, 1.0);
    transform.scaleY = _getNumber(rawData, DataParser.SCALE_Y, 1.0);
  }

  void _parseColorTransform(dynamic rawData, ColorTransform color) {
    color.alphaMultiplier = _getNumber(rawData, DataParser.ALPHA_MULTIPLIER, 100.0) * 0.01;
    color.redMultiplier = _getNumber(rawData, DataParser.RED_MULTIPLIER, 100.0) * 0.01;
    color.greenMultiplier = _getNumber(rawData, DataParser.GREEN_MULTIPLIER, 100.0) * 0.01;
    color.blueMultiplier = _getNumber(rawData, DataParser.BLUE_MULTIPLIER, 100.0) * 0.01;
    color.alphaOffset = _getNumber(rawData, DataParser.ALPHA_OFFSET, 0.0);
    color.redOffset = _getNumber(rawData, DataParser.RED_OFFSET, 0.0);
    color.greenOffset = _getNumber(rawData, DataParser.GREEN_OFFSET, 0.0);
    color.blueOffset = _getNumber(rawData, DataParser.BLUE_OFFSET, 0.0);
  }

  void _parseGeometry(dynamic rawData, GeometryData geometry) {
    final rawVertices = rawData[DataParser.VERTICES] as List<dynamic>;
    final vertexCount = (rawVertices.length / 2).floor(); // uint
    var triangleCount = 0;
    final geometryOffset = this._intArray.length;
    final verticesOffset = this._floatArray.length;
    //
    geometry.offset = geometryOffset;
    geometry.data = this._data;
    //
    _growInt(this._intArray, 1 + 1 + 1 + 1);
    this._intArray[geometryOffset + BinaryOffset.GeometryVertexCount] = vertexCount;
    this._intArray[geometryOffset + BinaryOffset.GeometryFloatOffset] = verticesOffset;
    this._intArray[geometryOffset + BinaryOffset.GeometryWeightOffset] = -1; //
    //
    _growFloat(this._floatArray, vertexCount * 2);
    for (var i = 0, l = vertexCount * 2; i < l; ++i) {
      this._floatArray[verticesOffset + i] = _number(rawVertices[i], 0.0);
    }

    if (_has(rawData, DataParser.TRIANGLES)) {
      final rawTriangles = rawData[DataParser.TRIANGLES] as List<dynamic>;
      triangleCount = (rawTriangles.length / 3).floor(); // uint
      //
      _growInt(this._intArray, triangleCount * 3);
      for (var i = 0, l = triangleCount * 3; i < l; ++i) {
        this._intArray[geometryOffset + BinaryOffset.GeometryVertexIndices + i] = _intOf(rawTriangles[i]);
      }
    }
    // Fill triangle count.
    this._intArray[geometryOffset + BinaryOffset.GeometryTriangleCount] = triangleCount;

    if (_has(rawData, DataParser.UVS)) {
      final rawUVs = rawData[DataParser.UVS] as List<dynamic>;
      final uvOffset = verticesOffset + vertexCount * 2;
      _growFloat(this._floatArray, vertexCount * 2);
      for (var i = 0, l = vertexCount * 2; i < l; ++i) {
        this._floatArray[uvOffset + i] = _number(rawUVs[i], 0.0);
      }
    }

    if (_has(rawData, DataParser.WEIGHTS)) {
      final rawWeights = rawData[DataParser.WEIGHTS] as List<dynamic>;
      final weightCount = ((rawWeights.length - vertexCount) / 2).floor(); // uint
      final weightOffset = this._intArray.length;
      final floatOffset = this._floatArray.length;
      var weightBoneCount = 0;
      final sortedBones = this._armature!.sortedBones;
      final weight = WeightData();
      weight.count = weightCount;
      weight.offset = weightOffset;

      _growInt(this._intArray, 1 + 1 + weightBoneCount + vertexCount + weightCount);
      this._intArray[weightOffset + BinaryOffset.WeigthFloatOffset] = floatOffset;

      if (_has(rawData, DataParser.BONE_POSE)) {
        final rawSlotPose = (rawData[DataParser.SLOT_POSE] as List<dynamic>).cast<num>();
        final rawBonePoses = (rawData[DataParser.BONE_POSE] as List<dynamic>).cast<num>();
        final weightBoneIndices = List<int>.filled(weightBoneCount, 0);

        weightBoneCount = (rawBonePoses.length / 7).floor(); // uint
        if (weightBoneIndices.length != weightBoneCount) {
          weightBoneIndices.length = weightBoneCount;
        }

        for (var i = 0; i < weightBoneCount; ++i) {
          final rawBoneIndex = _intOf(rawBonePoses[i * 7]); // uint
          final bone = this._rawBones[rawBoneIndex];
          weight.addBone(bone);
          weightBoneIndices[i] = rawBoneIndex;
          this._intArray[weightOffset + BinaryOffset.WeigthBoneIndices + i] = sortedBones.indexOf(bone);
        }

        _growFloat(this._floatArray, weightCount * 3);
        this._helpMatrixA.copyFromArray(rawSlotPose, 0);

        var iW = 0;
        var iB = weightOffset + BinaryOffset.WeigthBoneIndices + weightBoneCount;
        var iV = floatOffset;
        for (var i = 0; i < vertexCount; ++i) {
          final iD = i * 2;
          final vertexBoneCount = this._intArray[iB++] = _intOf(rawWeights[iW++]); // uint

          var x = this._floatArray[verticesOffset + iD];
          var y = this._floatArray[verticesOffset + iD + 1];
          this._helpMatrixA.transformPoint(x, y, this._helpPoint);
          x = this._helpPoint.x;
          y = this._helpPoint.y;

          for (var j = 0; j < vertexBoneCount; ++j) {
            final rawBoneIndex = _intOf(rawWeights[iW++]); // uint
            final boneIndex = weightBoneIndices.indexOf(rawBoneIndex);
            this._helpMatrixB.copyFromArray(rawBonePoses, boneIndex * 7 + 1);
            this._helpMatrixB.invert();
            this._helpMatrixB.transformPoint(x, y, this._helpPoint);
            this._intArray[iB++] = boneIndex;
            this._floatArray[iV++] = _number(rawWeights[iW++], 0.0);
            this._floatArray[iV++] = this._helpPoint.x;
            this._floatArray[iV++] = this._helpPoint.y;
          }
        }
      } else {
        final rawBones = rawData[DataParser.BONES] as List<dynamic>;
        weightBoneCount = rawBones.length;

        for (var i = 0; i < weightBoneCount; i++) {
          final rawBoneIndex = _intOf(rawBones[i]);
          final bone = this._rawBones[rawBoneIndex];
          weight.addBone(bone);
          this._intArray[weightOffset + BinaryOffset.WeigthBoneIndices + i] = sortedBones.indexOf(bone);
        }

        _growFloat(this._floatArray, weightCount * 3);
        var iW = 0;
        var iV = 0;
        var iB = weightOffset + BinaryOffset.WeigthBoneIndices + weightBoneCount;
        var iF = floatOffset;
        for (var i = 0; i < weightCount; i++) {
          final vertexBoneCount = _intOf(rawWeights[iW++]);
          this._intArray[iB++] = vertexBoneCount;

          for (var j = 0; j < vertexBoneCount; j++) {
            final boneIndex = _intOf(rawWeights[iW++]);
            final boneWeight = _number(rawWeights[iW++], 0.0);
            final x = _number(rawVertices[iV++], 0.0);
            final y = _number(rawVertices[iV++], 0.0);

            this._intArray[iB++] = rawBones.indexOf(boneIndex);
            this._floatArray[iF++] = boneWeight;
            this._floatArray[iF++] = x;
            this._floatArray[iF++] = y;
          }
        }
      }

      geometry.weight = weight;
    }
  }

  void _parseArray(dynamic rawData) {
    this._intArray.length = 0;
    this._floatArray.length = 0;
    this._frameIntArray.length = 0;
    this._frameFloatArray.length = 0;
    this._frameArray.length = 0;
    this._timelineArray.length = 0;
    this._colorArray.length = 0;
  }

  void _modifyArray() {
    // Align.
    if (this._intArray.length % Int16List.bytesPerElement != 0) {
      this._intArray.add(0);
    }

    if (this._frameIntArray.length % Int16List.bytesPerElement != 0) {
      this._frameIntArray.add(0);
    }

    if (this._frameArray.length % Int16List.bytesPerElement != 0) {
      this._frameArray.add(0);
    }

    if (this._timelineArray.length % Uint16List.bytesPerElement != 0) {
      this._timelineArray.add(0);
    }

    if (this._timelineArray.length % Int16List.bytesPerElement != 0) {
      this._colorArray.add(0);
    }

    final l1 = this._intArray.length * Int16List.bytesPerElement;
    final l2 = this._floatArray.length * Float32List.bytesPerElement;
    final l3 = this._frameIntArray.length * Int16List.bytesPerElement;
    final l4 = this._frameFloatArray.length * Float32List.bytesPerElement;
    final l5 = this._frameArray.length * Int16List.bytesPerElement;
    final l6 = this._timelineArray.length * Uint16List.bytesPerElement;
    final l7 = this._colorArray.length * Int16List.bytesPerElement;
    final lTotal = l1 + l2 + l3 + l4 + l5 + l6 + l7;
    //
    final binary = Uint8List(lTotal);
    final intArray = Int16List.view(binary.buffer, 0, this._intArray.length);
    final floatArray = Float32List.view(binary.buffer, l1, this._floatArray.length);
    final frameIntArray = Int16List.view(binary.buffer, l1 + l2, this._frameIntArray.length);
    final frameFloatArray = Float32List.view(binary.buffer, l1 + l2 + l3, this._frameFloatArray.length);
    final frameArray = Int16List.view(binary.buffer, l1 + l2 + l3 + l4, this._frameArray.length);
    final timelineArray = Uint16List.view(binary.buffer, l1 + l2 + l3 + l4 + l5, this._timelineArray.length);
    final colorArray = Int16List.view(binary.buffer, l1 + l2 + l3 + l4 + l5 + l6, this._colorArray.length);

    for (var i = 0, l = this._intArray.length; i < l; ++i) {
      intArray[i] = this._intArray[i];
    }

    for (var i = 0, l = this._floatArray.length; i < l; ++i) {
      floatArray[i] = this._floatArray[i];
    }

    for (var i = 0, l = this._frameIntArray.length; i < l; ++i) {
      frameIntArray[i] = this._frameIntArray[i];
    }

    for (var i = 0, l = this._frameFloatArray.length; i < l; ++i) {
      frameFloatArray[i] = this._frameFloatArray[i];
    }

    for (var i = 0, l = this._frameArray.length; i < l; ++i) {
      frameArray[i] = this._frameArray[i];
    }

    for (var i = 0, l = this._timelineArray.length; i < l; ++i) {
      timelineArray[i] = this._timelineArray[i];
    }

    for (var i = 0, l = this._colorArray.length; i < l; ++i) {
      colorArray[i] = this._colorArray[i];
    }

    this._data!.binary = binary;
    this._data!.intArray = intArray;
    this._data!.floatArray = floatArray;
    this._data!.frameIntArray = frameIntArray;
    this._data!.frameFloatArray = frameFloatArray;
    this._data!.frameArray = frameArray;
    this._data!.timelineArray = timelineArray;
    this._data!.colorArray = colorArray;
    this._defaultColorOffset = -1;
  }

  @override
  DragonBonesData? parseDragonBonesData(dynamic rawData, [double scale = 1.0]) {
    final version = _getString(rawData, DataParser.VERSION, '');
    final compatibleVersion = _getString(rawData, DataParser.COMPATIBLE_VERSION, '');

    if (DataParser.DATA_VERSIONS.contains(version) || DataParser.DATA_VERSIONS.contains(compatibleVersion)) {
      final data = DragonBonesData();
      data.version = version;
      data.name = _getString(rawData, DataParser.NAME, '');
      data.frameRate = _getNumber(rawData, DataParser.FRAME_RATE, 24.0);

      if (data.frameRate == 0.0) {
        // Data error.
        data.frameRate = 24.0;
      }

      if (_has(rawData, DataParser.ARMATURE)) {
        this._data = data;
        this._parseArray(rawData);

        final rawArmatures = rawData[DataParser.ARMATURE] as List<dynamic>;
        for (final rawArmature in rawArmatures) {
          data.addArmature(this._parseArmature(rawArmature, scale));
        }

        if (this._data!.binary == null) {
          // DragonBones.webAssembly ? 0 : null;
          this._modifyArray();
        }

        if (_has(rawData, DataParser.STAGE)) {
          data.stage = data.getArmature(_getString(rawData, DataParser.STAGE, ''));
        } else if (data.armatureNames.isNotEmpty) {
          data.stage = data.getArmature(data.armatureNames[0]);
        }

        this._data = null;
      }

      if (_has(rawData, DataParser.TEXTURE_ATLAS)) {
        this._rawTextureAtlases = rawData[DataParser.TEXTURE_ATLAS] as List<dynamic>;
      }

      return data;
    } else {
      // Upstream asserts: "Nonsupport data version: <version>".
    }

    return null;
  }

  @override
  bool parseTextureAtlasData(dynamic rawData, TextureAtlasData textureAtlasData, [double scale = 1.0]) {
    if (rawData == null) {
      if (this._rawTextureAtlases == null || this._rawTextureAtlases!.isEmpty) {
        return false;
      }

      final rawTextureAtlas = this._rawTextureAtlases![this._rawTextureAtlasIndex++];
      this.parseTextureAtlasData(rawTextureAtlas, textureAtlasData, scale);

      if (this._rawTextureAtlasIndex >= this._rawTextureAtlases!.length) {
        this._rawTextureAtlasIndex = 0;
        this._rawTextureAtlases = null;
      }

      return true;
    }

    // Texture format.
    textureAtlasData.width = _getNumber(rawData, DataParser.WIDTH, 0.0);
    textureAtlasData.height = _getNumber(rawData, DataParser.HEIGHT, 0.0);
    textureAtlasData.scale = scale == 1.0 ? (1.0 / _getNumber(rawData, DataParser.SCALE, 1.0)) : scale;
    textureAtlasData.name = _getString(rawData, DataParser.NAME, '');
    textureAtlasData.imagePath = _getString(rawData, DataParser.IMAGE_PATH, '');

    if (_has(rawData, DataParser.SUB_TEXTURE)) {
      final rawTextures = rawData[DataParser.SUB_TEXTURE] as List<dynamic>;
      for (var i = 0, l = rawTextures.length; i < l; ++i) {
        final rawTexture = rawTextures[i];
        final frameWidth = _getNumber(rawTexture, DataParser.FRAME_WIDTH, -1.0);
        final frameHeight = _getNumber(rawTexture, DataParser.FRAME_HEIGHT, -1.0);
        final textureData = textureAtlasData.createTexture();

        textureData.rotated = _getBoolean(rawTexture, DataParser.ROTATED, false);
        textureData.name = _getString(rawTexture, DataParser.NAME, '');
        textureData.region.x = _getNumber(rawTexture, DataParser.X, 0.0);
        textureData.region.y = _getNumber(rawTexture, DataParser.Y, 0.0);
        textureData.region.width = _getNumber(rawTexture, DataParser.WIDTH, 0.0);
        textureData.region.height = _getNumber(rawTexture, DataParser.HEIGHT, 0.0);

        if (frameWidth > 0.0 && frameHeight > 0.0) {
          textureData.frame = TextureData.createRectangle();
          textureData.frame!.x = _getNumber(rawTexture, DataParser.FRAME_X, 0.0);
          textureData.frame!.y = _getNumber(rawTexture, DataParser.FRAME_Y, 0.0);
          textureData.frame!.width = frameWidth;
          textureData.frame!.height = frameHeight;
        }

        textureAtlasData.addTexture(textureData);
      }
    }

    return true;
  }

  static ObjectDataParser? _objectDataParserInstance;

  /// - Deprecated, please refer to {@link dragonBones.BaseFactory#parseDragonBonesData()}.
  static ObjectDataParser getInstance() {
    if (ObjectDataParser._objectDataParserInstance == null) {
      ObjectDataParser._objectDataParserInstance = ObjectDataParser();
    }

    return ObjectDataParser._objectDataParserInstance!;
  }
}

/// @private
class ActionFrame {
  int frameStart = 0;
  final List<int> actions = <int>[];
}
