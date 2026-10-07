// Plays *every* animation of every bundled example asset, to its full duration,
// frame by frame. `check_example_assets.dart` only plays the first animation for
// 24 frames, which never reaches a `displayFrame` timeline that swaps a slot to a
// nested child armature — the path that throws
// "type 'ArmatureDisplayData' is not a subtype of type 'ImageDisplayData'".
//
//   dart run tool/assets/sweep_example_assets.dart
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/example/assets').existsSync() &&
        Directory('${dir.path}/packages/dragonbones').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('could not find the repository root');
}

void main() {
  final assets = Directory('${_repoRoot().path}/example/assets');
  final dirs = assets
      .listSync(recursive: true)
      .whereType<Directory>()
      .where((d) => File('${d.path}/ske.json').existsSync() && File('${d.path}/tex.json').existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var animationsPlayed = 0;
  var framesAdvanced = 0;
  var failures = 0;

  for (final dir in dirs) {
    final name = dir.path.substring(assets.path.length + 1);
    try {
      final factory = HeadlessFactory();
      final data = factory.parseDragonBonesData(
        jsonDecode(File('${dir.path}/ske.json').readAsStringSync()),
      );
      if (data == null) {
        print('FAIL $name: skeleton did not parse');
        failures++;
        continue;
      }
      factory.parseTextureAtlasData(
        jsonDecode(File('${dir.path}/tex.json').readAsStringSync()),
        null,
        data.name,
      );
      for (final armatureName in data.armatureNames) {
        final armature = factory.buildArmature(armatureName, data.name);
        if (armature == null) {
          print('FAIL $name/$armatureName: did not build');
          failures++;
          continue;
        }
        for (final animName in armature.armatureData.animationNames) {
          final anim = armature.armatureData.getAnimation(animName);
          if (anim == null) continue;
          final fps = armature.armatureData.frameRate > 0 ? armature.armatureData.frameRate : 24.0;
          final total = (anim.duration * fps).ceil() + 2;
          armature.animation.play(animName);
          for (var f = 0; f < total; f++) {
            try {
              armature.advanceTime(1.0 / fps);
              armature.buildDrawList();
              framesAdvanced++;
            } on Object catch (error, stack) {
              failures++;
              print('FAIL $name/$armatureName/$animName frame $f: $error');
              print('${stack}'.split('\n').take(4).join('\n'));
              break;
            }
          }
          animationsPlayed++;
        }
      }
    } on Object catch (error, stack) {
      failures++;
      print('FAIL $name: $error');
      print('${stack}'.split('\n').take(4).join('\n'));
    }
  }

  print('');
  print('$animationsPlayed animations, $framesAdvanced frames advanced over '
      '${dirs.length} characters');
  print(failures > 0 ? 'RESULT: FAIL ($failures)' : 'RESULT: PASS');
  if (failures > 0) exit(1);
}
