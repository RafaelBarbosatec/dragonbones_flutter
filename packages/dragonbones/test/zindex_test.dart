// SlotZIndex: a timeline that animates a slot's z-index. The armature re-sorts
// its slots, so this changes the draw order, not just a number.
//
// Verified frame by frame against the official runtime by
// `tool/check_against_oracle.dart` (the `feature_zindex` target); this states the
// behaviour in a readable form. The fixture is hand-authored because the SDK
// demos predate the separate z-index timeline.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';
import 'package:test/test.dart';

Directory _fixture() {
  for (final candidate in <String>[
    'test/fixtures/features/zindex',
    '../../test/fixtures/features/zindex',
  ]) {
    final directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError('zindex fixture not found — run from packages/dragonbones');
}

Armature _build() {
  final dir = _fixture();
  final factory = HeadlessFactory();
  final data = factory.parseDragonBonesData(
    jsonDecode(File('${dir.path}/zindex_ske.json').readAsStringSync()),
  )!;
  factory.parseTextureAtlasData(
    jsonDecode(File('${dir.path}/zindex_tex.json').readAsStringSync()),
    null,
    data.name,
  );
  return factory.buildArmature('zindex_test', data.name)!;
}

void main() {
  test('a SlotZIndex timeline reorders the draw list', () {
    final armature = _build();
    armature.animation.play('idle', 1);

    // `front` moves from a tie (insertion order) to in front of `back`, then
    // behind it again — the same order the official runtime dumps.
    final expected = <int, List<String>>{
      4: <String>['back', 'front'],
      12: <String>['front', 'back'],
      20: <String>['back', 'front'],
    };

    for (var frame = 0; frame <= 20; frame++) {
      if (frame > 0) {
        armature.advanceTime(1 / 24);
      }
      final want = expected[frame];
      if (want == null) {
        continue;
      }

      final order = armature.buildDrawList().map((data) => data.slotName).toList();
      expect(order, want, reason: 'frame $frame');
    }
  });
}
