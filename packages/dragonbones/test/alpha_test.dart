// SlotAlpha / BoneAlpha: the dedicated alpha timelines from the newer
// `timeline` array format. Verified frame by frame against the official runtime
// by `tool/check_against_oracle.dart` (the `feature_alpha` target); this states
// the behaviour in a readable form.
//
// The fixture is hand-authored (`test/fixtures/features/alpha`) because the
// bundled SDK demos predate the separate alpha timelines.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';
import 'package:test/test.dart';

/// Locates `test/fixtures/features/alpha` whether the tests run from
/// `packages/dragonbones` (as CI does) or from the repository root.
Directory _fixture() {
  for (final candidate in <String>[
    'test/fixtures/features/alpha',
    '../../test/fixtures/features/alpha',
  ]) {
    final directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError('alpha fixture not found — run from packages/dragonbones');
}

Armature _build() {
  final dir = _fixture();
  final factory = HeadlessFactory();
  final data = factory.parseDragonBonesData(
    jsonDecode(File('${dir.path}/alpha_ske.json').readAsStringSync()),
  )!;
  factory.parseTextureAtlasData(
    jsonDecode(File('${dir.path}/alpha_tex.json').readAsStringSync()),
    null,
    data.name,
  );
  return factory.buildArmature('alpha_test', data.name)!;
}

void main() {
  test('slot and bone alpha multiply into the effective slot alpha', () {
    final armature = _build();
    armature.animation.play('idle', 1);

    // slot alpha alone (0.25), then under a 0.5 bone alpha (0.125), then the
    // bone alone (0.5). These are the values the official runtime dumps.
    final expected = <int, double>{0: 1.0, 8: 0.25, 12: 0.125, 17: 0.5};

    for (var frame = 0; frame <= 17; frame++) {
      if (frame > 0) {
        armature.advanceTime(1 / 24);
      }
      final want = expected[frame];
      if (want == null) {
        continue;
      }

      final list = armature.buildDrawList();
      expect(list, hasLength(1), reason: 'frame $frame');
      // `color[0]` is the effective alpha: colour transform * `_globalAlpha`.
      expect(list.single.color[0], closeTo(want, 1e-6), reason: 'frame $frame');
    }
  });
}
