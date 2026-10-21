// Animated IK (`IKConstraintTimelineState`). Verified frame by frame against
// the official runtime by `tool/check_against_oracle.dart` (`feature_ik`); this
// states the behaviour in a readable form.
//
// The fixture is hand-authored (`test/fixtures/features/ik`): no bundled SDK
// demo animates an IK constraint — they only use static IK, which already
// passes elsewhere.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dragonbones/dragonbones.dart';
import 'package:test/test.dart';

Directory _fixture() {
  for (final candidate in <String>[
    'test/fixtures/features/ik',
    '../../test/fixtures/features/ik',
  ]) {
    final directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError('ik fixture not found — run from packages/dragonbones');
}

Armature _build() {
  final factory = HeadlessFactory();
  final data = factory.parseDragonBonesData(
    jsonDecode(File('${_fixture().path}/ik_ske.json').readAsStringSync()),
  )!;
  return factory.buildArmature('ik_test', data.name)!;
}

double _rotation(Armature armature, String bone) {
  final matrix = armature.getBone(bone)!.globalTransformMatrix;
  return math.atan2(matrix.b, matrix.a);
}

void main() {
  test('an IK timeline steps bendPositive/weight at frame boundaries', () {
    final armature = _build();
    armature.animation.play('idle', 1);

    // The timeline keyframes are: (bend=true, weight=0) at frame 0,
    // (bend=false, weight=1) at frame 8, (bend=true, weight=0.5) at 16.
    //
    // Upstream reads the *start-of-segment* value (`_currentB`) rather than the
    // interpolated one, so the weight steps instead of tweening: frames 1-7
    // are weight 0 (the chain stays straight), frame 8 jumps to weight 1.
    for (var frame = 1; frame <= 7; frame++) {
      armature.advanceTime(1 / 24);
      expect(_rotation(armature, 'upper'), closeTo(0.0, 1e-9), reason: 'frame $frame');
    }

    // Frame 8: weight 1, bendPositive false — the chain aims at the target.
    armature.advanceTime(1 / 24);
    expect(_rotation(armature, 'upper'), closeTo(0.2861, 1e-4), reason: 'frame 8');
    expect(_rotation(armature, 'lower'), closeTo(0.2861, 1e-4), reason: 'frame 8');
  });

  test('the IK pose follows the target while the weight is active', () {
    final armature = _build();
    armature.animation.play('idle', 1);

    // Advance to frame 15: weight is still 1, but the target has moved, so the
    // solved angle differs from frame 8.
    for (var frame = 0; frame < 15; frame++) {
      armature.advanceTime(1 / 24);
    }

    expect(_rotation(armature, 'upper'), closeTo(0.3612, 1e-4));
  });
}
