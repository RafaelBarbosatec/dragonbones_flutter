// Guards the *staged* fixtures under `test/fixtures/features`: assets for
// features the runtime parses but does not evaluate yet (Surface bones,
// slotAlpha / slotZIndex, animation blend, and the binary container).
//
// They are committed so the roadmap has something real to implement against.
// This test does not evaluate them (the runtime cannot, yet) — it only asserts
// they are still the assets we think they are, so a silent swap cannot weaken
// the future verification. The oracle sweep picks them up feature by feature.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Locates `test/fixtures/features` whether the tests run from
/// `packages/dragonbones` (as CI does) or from the repository root.
Directory _features() {
  for (final candidate in <String>[
    'test/fixtures/features',
    '../../test/fixtures/features',
  ]) {
    final directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError('feature fixtures not found — run from packages/dragonbones');
}

void main() {
  test('the staged feature fixtures are present', () {
    final dir = _features();
    expect(File('${dir.path}/shizuku/shizuku_ske.json').existsSync(), isTrue);
    expect(
      File('${dir.path}/binary/mecha_1002_101d_show_ske.dbbin').existsSync(),
      isTrue,
    );
  });

  test('shizuku still exercises slotAlpha, slotZIndex, Surface and blend', () {
    final dir = _features();
    final json = jsonDecode(
      File('${dir.path}/shizuku/shizuku_ske.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(json['version'], '5.6');

    final surfaceBones = <String>[];
    final timelineTypes = <int>{};
    var hasBlend = false;

    for (final armature in (json['armature'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      for (final bone in (armature['bone'] as List<dynamic>? ?? const [])) {
        final map = bone as Map<String, dynamic>;
        if (map['type'] == 'surface' || map['type'] == 1) {
          surfaceBones.add(map['name'] as String);
        }
      }

      for (final animation in (armature['animation'] as List<dynamic>? ?? const [])) {
        final map = animation as Map<String, dynamic>;
        if (map['blendType'] != null) {
          hasBlend = true;
        }
        for (final timeline in (map['timeline'] as List<dynamic>? ?? const [])) {
          final type = (timeline as Map<String, dynamic>)['type'];
          if (type is int) {
            timelineTypes.add(type);
          }
        }
      }
    }

    expect(surfaceBones, isNotEmpty, reason: 'Surface bones are why this fixture was picked');
    // slotZIndex = 23, slotAlpha = 24, Surface = 50 (the port's TimelineType).
    expect(timelineTypes, containsAll(<int>[23, 24, 50]));
    expect(hasBlend, isTrue, reason: 'the animation progress/parameter timelines need blendType');
  });

  test('the binary container keeps its DBDT magic', () {
    final bytes = File('${_features().path}/binary/mecha_1002_101d_show_ske.dbbin').readAsBytesSync();
    expect(bytes.length, greaterThan(4));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'DBDT');
  });
}
