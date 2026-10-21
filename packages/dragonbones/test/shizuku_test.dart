// Surface bones and animation blending, both exercised by the official
// EyeTracking demo (`test/fixtures/features/shizuku`). Verified frame by frame
// against the official runtime by `tool/check_against_oracle.dart`
// (`feature_shizuku__PARAM_BREATH` and `feature_shizuku__B_BROW.03`); this
// states the behaviour in a readable form.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';
import 'package:test/test.dart';

Directory _fixture() {
  for (final candidate in <String>[
    'test/fixtures/features/shizuku',
    '../../test/fixtures/features/shizuku',
  ]) {
    final directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError('shizuku fixture not found — run from packages/dragonbones');
}

late HeadlessFactory _factory;
late DragonBonesData _data;

Armature _build() => _factory.buildArmature('shizuku', _data.name)!;

void main() {
  setUpAll(() {
    _factory = HeadlessFactory();
    _data = _factory.parseDragonBonesData(
      jsonDecode(File('${_fixture().path}/shizuku_ske.json').readAsStringSync()),
    )!;
  });

  test('surface bones are built as Surface, not as plain Bone', () {
    final armature = _build();
    final bones = armature.getBones();

    expect(bones, hasLength(135));
    expect(bones.whereType<Surface>(), hasLength(117));
    // Every surface solves a transform, and none of them may be NaN.
    for (final surface in bones.whereType<Surface>()) {
      expect(surface.globalTransformMatrix.a.isFinite, isTrue, reason: surface.name);
      expect(surface.globalTransformMatrix.ty.isFinite, isTrue, reason: surface.name);
    }
  });

  test('a mesh parented to a Surface is posed through its per-cell transform', () {
    final armature = _build();
    armature.animation.play('PARAM_BREATH', 1);

    final draw = armature.buildDrawList();
    final slot = draw.firstWhere((d) => d.slotName == 'D_CLOTHES.04');

    // Values dumped from the official runtime for frame 0. Without the surface
    // branch these would be the mesh's rest vertices (-153.11, -115.87).
    expect(slot.mesh!.vertices[0], closeTo(-134.656763, 1e-4));
    expect(slot.mesh!.vertices[1], closeTo(-708.367862, 1e-4));
  });

  test('a blend parent starts its child animation states', () {
    final armature = _build();
    armature.animation.play('B_BROW.03', 1);

    // `blendType: "1d"` + AnimationProgress timelines: the three child
    // animations are started as child states of B_BROW.03.
    expect(armature.animation.getState('B_BROW.03_00'), isNotNull);

    expect(armature.animation.getState('B_BROW.03_01'), isNotNull);
    expect(armature.animation.getState('B_BROW.03_02'), isNotNull);

    // Frame 1: the blended pose the official runtime dumps. Without the child
    // states this bone lands on -982.107 instead.
    armature.advanceTime(1 / 30);
    expect(armature.getBone('B_BROW.01')!.globalTransformMatrix.ty, closeTo(-964.082887, 1e-3));
  });
}
