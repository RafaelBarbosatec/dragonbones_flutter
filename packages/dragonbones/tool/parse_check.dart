// Standalone structural verification for the pure-Dart DragonBones data layer.
//
// Reads the format-5.5 fixture `test/fixtures/Dragon_ske.json`, parses it with
// `ObjectDataParser`, and asserts the parsed model against (a) the fixture's own
// raw JSON and (b) the official-runtime oracle in `tool/ground_truth/out/`.
//
// Run from the package directory:
//   dart run tool/parse_check.dart
//
// This was originally a hand-rolled `dragonbones` library that `part`ed the
// geom / model / parser sources in, because the umbrella library did not
// compile yet at that milestone. It compiles now, so this is a plain consumer
// of `package:dragonbones/dragonbones.dart` — which is also what makes it a
// check of the *public* API rather than of the internals.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

int _checks = 0;
int _failures = 0;
final List<String> _failMessages = <String>[];

void expect(bool condition, String message) {
  _checks++;
  if (!condition) {
    _failures++;
    _failMessages.add(message);
    print('  FAIL: $message');
  }
}

/// Finds [relative] by walking up from the current directory (and next to the
/// script), so the check works from the repository root or the package dir.
File _findFile(String relative) {
  final candidates = <Directory>[];
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    candidates.add(dir);
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  candidates.add(File.fromUri(Platform.script).parent.parent.parent); // .../packages/dragonbones

  for (final candidate in candidates) {
    final file = File('${candidate.path}/$relative');
    if (file.existsSync()) return file;
  }
  return File(relative);
}

bool near(double a, double b, [double eps = 1e-4]) => (a - b).abs() <= eps;

/// True when two angles are the same modulo a full turn.
bool sameAngle(double aRadians, double bRadians) => Transform.normalizeRadian(aRadians - bRadians).abs() <= 1e-4;

double _num(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return fallback;
}

/// One decoded key frame: its start time and its float values.
class DecodedFrame {
  DecodedFrame(this.start, this.values);
  final int start;
  final List<double> values;
}

/// Reads a timeline's key frames back out of the DragonBones binary arrays,
/// mirroring exactly what the runtime's timeline states do.
List<DecodedFrame> _decodeTimeline(TimelineData timeline, AnimationData animation, DragonBonesData data) {
  final ta = data.timelineArray!;
  final fa = data.frameArray!;
  final ffa = data.frameFloatArray!;

  final keyFrameCount = ta[timeline.offset + BinaryOffset.TimelineKeyFrameCount];
  final valueCount = ta[timeline.offset + BinaryOffset.TimelineFrameValueCount];
  final valueOffset = ta[timeline.offset + BinaryOffset.TimelineFrameValueOffset];

  final frames = <DecodedFrame>[];
  for (var i = 0; i < keyFrameCount; i++) {
    // Stored frame offsets are relative to the animation's frame-array offset.
    final frameOffset = ta[timeline.offset + BinaryOffset.TimelineFrameOffset + i] + animation.frameOffset;
    final start = fa[frameOffset + BinaryOffset.FramePosition];
    final values = <double>[];
    for (var j = 0; j < valueCount; j++) {
      // Float timelines append `valueCount` values per key frame, contiguous
      // from the animation's float-array offset.
      values.add(ffa[animation.frameFloatOffset + valueOffset + i * valueCount + j]);
    }
    frames.add(DecodedFrame(start, values));
  }

  return frames;
}

const Map<String, int> _boneTimelineTypes = <String, int>{
  'translateFrame': 11, // TimelineType.BoneTranslate
  'rotateFrame': 12, // TimelineType.BoneRotate
  'scaleFrame': 13, // TimelineType.BoneScale
  'frame': 10, // TimelineType.BoneAll
};

void main() {
  final skeFile = _findFile('test/fixtures/Dragon_ske.json');
  final texFile = _findFile('test/fixtures/Dragon_tex.json');
  expect(skeFile.existsSync(), 'fixture exists: ${skeFile.path}');
  expect(texFile.existsSync(), 'atlas fixture exists: ${texFile.path}');

  final rawSke = jsonDecode(skeFile.readAsStringSync()) as Map<String, dynamic>;
  final rawTex = jsonDecode(texFile.readAsStringSync()) as Map<String, dynamic>;
  final rawArmature = (rawSke['armature'] as List<dynamic>)[0] as Map<String, dynamic>;

  final parser = ObjectDataParser();
  final data = parser.parseDragonBonesData(rawSke, 1.0);
  expect(data != null, 'parseDragonBonesData returned non-null');
  if (data == null) {
    _report();
    return;
  }

  // ---- Top-level DragonBonesData -------------------------------------------------
  expect(data.version == '5.5', 'data.version == 5.5 (was ${data.version})');
  expect(data.name == rawSke['name'], 'data.name matches fixture (${data.name})');
  expect(near(data.frameRate, 24.0), 'data.frameRate == 24 (was ${data.frameRate})');
  expect(data.armatureNames.length == 1, 'exactly one armature');
  expect(data.armatureNames.first == 'Dragon', "armature name is 'Dragon'");

  final armature = data.getArmature('Dragon');
  expect(armature != null, 'getArmature("Dragon") non-null');
  if (armature == null) {
    _report();
    return;
  }

  print('DragonBonesData: name=${data.name} version=${data.version} frameRate=${data.frameRate} '
      'armatures=${data.armatureNames}');
  print('Binary arrays: int=${data.intArray!.length} float=${data.floatArray!.length} '
      'frameInt=${data.frameIntArray!.length} frameFloat=${data.frameFloatArray!.length} '
      'frame=${data.frameArray!.length} timeline=${data.timelineArray!.length} color=${data.colorArray!.length} '
      'frameIndices=${data.frameIndices.length}');

  // ---- Armature ------------------------------------------------------------------
  expect(armature.name == 'Dragon', "armature.name == 'Dragon'");
  expect(near(armature.frameRate, 24.0), 'armature.frameRate == 24 (was ${armature.frameRate})');
  expect(armature.parent == data, 'armature.parent links back to DragonBonesData');

  final rawBoneNames =
      (rawArmature['bone'] as List<dynamic>).map((b) => (b as Map<String, dynamic>)['name'] as String).toList();
  final rawSlotNames =
      (rawArmature['slot'] as List<dynamic>).map((s) => (s as Map<String, dynamic>)['name'] as String).toList();

  expect(armature.bones.length == 19, '19 bones (was ${armature.bones.length})');
  expect(armature.slots.length == 18, '18 slots (was ${armature.slots.length})');
  expect(armature.sortedBones.length == 19, '19 sorted bones');

  final parsedBoneOrder = armature.sortedBones.map((b) => b.name).toList();
  expect(parsedBoneOrder.length == rawBoneNames.length, 'bone count matches fixture');
  expect(parsedBoneOrder.join(',') == rawBoneNames.join(','),
      'sortedBones order == fixture bone[].name order\n    parsed: $parsedBoneOrder\n    fixture: $rawBoneNames');
  expect(armature.bones.keys.join(',') == rawBoneNames.join(','), 'bones map preserves fixture order');

  final parsedSlotOrder = armature.sortedSlots.map((s) => s.name).toList();
  expect(parsedSlotOrder.join(',') == rawSlotNames.join(','), 'sortedSlots order == fixture slot[].name order');

  // ---- Skin / sprite displays ----------------------------------------------------
  final skin = armature.defaultSkin;
  expect(skin != null, 'defaultSkin present');
  if (skin == null) {
    _report();
    return;
  }
  expect(skin.name == 'default', "unnamed skin is registered as 'default' (was '${skin.name}')");

  var parsedDisplayCount = 0;
  var imageDisplayCount = 0;
  final displayNames = <String>[];
  for (final rawSkinSlot in (rawArmature['skin'] as List<dynamic>)[0]['slot'] as List<dynamic>) {
    final slotName = (rawSkinSlot as Map<String, dynamic>)['name'] as String;
    final rawDisplays = (rawSkinSlot['display'] as List<dynamic>?) ?? const <dynamic>[];
    final parsedDisplays = skin.getDisplays(slotName);
    expect(parsedDisplays != null, 'skin has displays for slot "$slotName"');
    if (parsedDisplays == null) continue;

    expect(parsedDisplays.length == rawDisplays.length,
        'slot "$slotName" display count ${parsedDisplays.length} == ${rawDisplays.length}');

    for (var i = 0; i < rawDisplays.length; i++) {
      final rawDisplay = rawDisplays[i] as Map<String, dynamic>;
      final display = parsedDisplays[i];
      parsedDisplayCount++;
      expect(display != null, 'display $i of slot "$slotName" parsed');
      if (display == null) continue;
      expect(display is ImageDisplayData, 'display "$slotName[$i]" is a sprite (ImageDisplayData)');
      final rawName = rawDisplay['name'] as String;
      expect(display.name == rawName, 'display name "$slotName[$i]" == "$rawName" (was ${display.name})');
      expect(display.path == display.name, 'display path falls back to display name');
      if (display is ImageDisplayData) {
        imageDisplayCount++;
        expect(display.pivot.x == 0.5 && display.pivot.y == 0.5, 'default pivot is (0.5, 0.5)');
      }
      displayNames.add(display.name);
    }
  }
  expect(parsedDisplayCount == 18, '18 sprite displays resolved (was $parsedDisplayCount)');
  expect(imageDisplayCount == 18, 'all 18 displays are sprites (was $imageDisplayCount)');

  // ---- Texture atlas -------------------------------------------------------------
  final atlas = TextureAtlasData();
  final atlasOk = parser.parseTextureAtlasData(rawTex, atlas, 1.0);
  expect(atlasOk, 'parseTextureAtlasData returned true');
  expect(atlas.width == 1024.0, 'atlas width == 1024 (was ${atlas.width})');
  expect(atlas.height == 1024.0, 'atlas height == 1024 (was ${atlas.height})');
  expect(atlas.imagePath == 'Dragon_tex.png', 'atlas imagePath');
  expect(atlas.textures.length == 18, 'atlas has 18 SubTextures (was ${atlas.textures.length})');

  var resolvedTextures = 0;
  for (final name in displayNames) {
    final texture = atlas.getTexture(name);
    expect(texture != null, 'sprite "$name" resolves to a TextureData');
    if (texture != null) {
      resolvedTextures++;
      expect(texture.name == name, 'resolved texture name matches "$name"');
    }
  }
  expect(resolvedTextures == 18, 'all 18 sprites resolve to a texture (was $resolvedTextures)');

  // ---- Animations ----------------------------------------------------------------
  final animationNames = armature.animationNames;
  expect(animationNames.join(',') == 'stand,walk,jump,fall',
      "animation names == [stand,walk,jump,fall] (was $animationNames)");
  expect(armature.animations.length == 4, '4 animations');

  final rawAnimations = rawArmature['animation'] as List<dynamic>;
  expect(rawAnimations.length == 4, 'fixture has 4 animations');

  print('\nArmature ${armature.name}: ${armature.sortedBones.length} bones, ${armature.slots.length} slots, '
      'skin displays=$parsedDisplayCount, animations=$animationNames');
  print('Bones:   $parsedBoneOrder');
  print('Slots:   $parsedSlotOrder');

  for (final rawAnimation in rawAnimations) {
    final raw = rawAnimation as Map<String, dynamic>;
    final animationName = raw['name'] as String;
    final animation = armature.getAnimation(animationName);
    expect(animation != null, 'animation "$animationName" present');
    if (animation == null) continue;

    final rawFrameCount = (raw['duration'] as num).toInt();
    final expectedDuration = rawFrameCount / armature.frameRate;
    expect(animation.frameCount == rawFrameCount,
        '$animationName.frameCount == $rawFrameCount (was ${animation.frameCount})');
    expect(near(animation.duration, expectedDuration),
        '$animationName.duration == $expectedDuration (was ${animation.duration})');
    expect(animation.slotTimelines.isEmpty, '$animationName has no slot timelines');

    final rawBoneTimelines = (raw['bone'] as List<dynamic>?) ?? const <dynamic>[];
    var decodedTimelines = 0;

    for (final rawBoneTimeline in rawBoneTimelines) {
      final rawTimeline = rawBoneTimeline as Map<String, dynamic>;
      final boneName = rawTimeline['name'] as String;
      final parsedTimelines = animation.boneTimelines[boneName];
      expect(parsedTimelines != null, '$animationName: bone timeline for "$boneName" exists');
      if (parsedTimelines == null) continue;

      for (final entry in _boneTimelineTypes.entries) {
        final key = entry.key;
        if (!rawTimeline.containsKey(key)) continue;
        final rawFrames = rawTimeline[key] as List<dynamic>;

        final matching = parsedTimelines.where((t) => t.type == entry.value).toList();
        expect(matching.length == 1, '$animationName/$boneName/$key: one parsed timeline');
        if (matching.isEmpty) continue;
        final timeline = matching.first;
        decodedTimelines++;

        final ta = data.timelineArray!;
        final keyFrameCount = ta[timeline.offset + BinaryOffset.TimelineKeyFrameCount];
        expect(keyFrameCount == rawFrames.length,
            '$animationName/$boneName/$key keyFrameCount $keyFrameCount == ${rawFrames.length}');

        final decoded = _decodeTimeline(timeline, animation, data);
        expect(decoded.length == rawFrames.length, '$animationName/$boneName/$key decoded frame count');

        // Expected key-frame start times = cumulative durations.
        var expectedStart = 0;
        for (var i = 0; i < rawFrames.length; i++) {
          final rawFrame = rawFrames[i] as Map<String, dynamic>;
          final label = '$animationName/$boneName/$key frame[$i]';

          expect(decoded[i].start == expectedStart, '$label start ${decoded[i].start} == $expectedStart');

          if (key == 'translateFrame') {
            final rawX = _num(rawFrame['x']);
            final rawY = _num(rawFrame['y']);
            expect(near(decoded[i].values[0], rawX), '$label x ${decoded[i].values[0]} == $rawX');
            expect(near(decoded[i].values[1], rawY), '$label y ${decoded[i].values[1]} == $rawY');
          } else if (key == 'rotateFrame') {
            final rawDeg = _num(rawFrame['rotate']);
            final rawSkewDeg = _num(rawFrame['skew']);
            expect(sameAngle(decoded[i].values[0], rawDeg * Transform.DEG_RAD),
                '$label rotate ${decoded[i].values[0]} == ${rawDeg * Transform.DEG_RAD} rad ($rawDeg deg)');
            expect(sameAngle(decoded[i].values[1], rawSkewDeg * Transform.DEG_RAD),
                '$label skew ${decoded[i].values[1]} == $rawSkewDeg deg');
          }

          // Tween type for the first frame (fixture uses tweenEasing: 0 -> Line).
          final frameOffset =
              data.timelineArray![timeline.offset + BinaryOffset.TimelineFrameOffset + i] + animation.frameOffset;
          final tweenType = data.frameArray![frameOffset + BinaryOffset.FrameTweenType];
          if (rawFrames.length > 1 && i == 0) {
            expect(
                tweenType == 1, // TweenType.Line
                '$label first-frame tween == Line (was $tweenType)');
          }

          expectedStart += ((rawFrame['duration'] as num?) ?? 1).toInt();
        }
      }
    }
    expect(decodedTimelines > 0, '$animationName decoded at least one bone timeline');
    print('  animation "$animationName": frameCount=${animation.frameCount} duration=${animation.duration} '
        'boneTimelines=${animation.boneTimelines.length} decodedTimelines=$decodedTimelines');
  }

  // ---- Independent ground truth (official runtime oracle) ------------------------
  const oracleFiles = <String, String>{
    'stand': 'tool/ground_truth/out/Dragon_stand.json',
    'walk': 'tool/ground_truth/out/Dragon_walk.json',
    'jump': 'tool/ground_truth/out/Dragon_jump.json',
    'fall': 'tool/ground_truth/out/Dragon_fall.json',
  };

  final orderReason = armature.sortedBones.map((b) => b.name).toList();
  for (final entry in oracleFiles.entries) {
    final oracleFile = _findFile(entry.value);
    expect(oracleFile.existsSync(), 'oracle exists: ${oracleFile.path}');
    if (!oracleFile.existsSync()) continue;
    final oracle = jsonDecode(oracleFile.readAsStringSync()) as Map<String, dynamic>;

    expect(oracle['armatureName'] == 'Dragon', 'oracle[${entry.key}].armatureName');
    expect((oracle['animationNames'] as List<dynamic>).join(',') == 'stand,walk,jump,fall',
        'oracle[${entry.key}].animationNames');
    expect(near(_num(oracle['frameRate']), 24.0), 'oracle[${entry.key}].frameRate');
    expect(_num(oracle['boneCount']).toInt() == 19, 'oracle[${entry.key}].boneCount');
    expect(_num(oracle['slotCount']).toInt() == 18, 'oracle[${entry.key}].slotCount');

    final oracleAnimation = armature.getAnimation(entry.key);
    if (oracleAnimation != null) {
      expect(near(_num(oracle['duration']), oracleAnimation.duration),
          'oracle[${entry.key}].duration == parsed (${oracleAnimation.duration})');
      expect(_num(oracle['totalFrames']).toInt() == oracleAnimation.frameCount,
          'oracle[${entry.key}].totalFrames == parsed frameCount (${oracleAnimation.frameCount})');
    }

    final firstFrame = (oracle['frames'] as List<dynamic>).first as Map<String, dynamic>;
    final oracleBones = ((firstFrame['state'] as Map<String, dynamic>)['bones'] as List<dynamic>)
        .map((b) => (b as Map<String, dynamic>)['name'] as String)
        .toList();
    expect(oracleBones.join(',') == orderReason.join(','),
        'oracle[${entry.key}] runtime bone order == parsed sortedBones order');
  }

  _report();
}

void _report() {
  print('\n${_checks - _failures}/$_checks assertions passed.');
  if (_failures == 0) {
    print('RESULT: PASS');
    exit(0);
  }
  print('RESULT: FAIL ($_failures failed)');
  for (final message in _failMessages.take(40)) {
    print('  - $message');
  }
  exit(1);
}
