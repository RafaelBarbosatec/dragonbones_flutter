# dragonbones

A pure-Dart runtime for **DragonBones** skeletal animation (text/JSON format 5.x).

The point of this package is that it has **zero dependencies** — no Flutter, no
platform channels, no third-party packages. That makes it verifiable with a bare
Dart SDK and usable anywhere Dart runs, including the web.

```dart
import 'dart:convert';
import 'package:dragonbones/dragonbones.dart';

final factory = HeadlessFactory();
factory.parseDragonBonesData(jsonDecode(skeJson), 'Dragon');
factory.parseTextureAtlasData(jsonDecode(texJson), null, 'Dragon');

final armature = factory.buildArmature('Dragon', 'Dragon')!;
armature.animation.play('stand');
armature.advanceTime(1 / 24);
```

`HeadlessFactory` is a concrete `BaseFactory` that binds no renderer at all. A
real binding (see `flame_dragon_bones`) subclasses `BaseFactory` and `Slot`
instead and draws the displays.

## Correctness

This is a faithful transcription of the upstream TypeScript runtime
(`DragonBonesJS`). Rather than trust that, it is **diffed against the official
runtime**:

```
tool/parse_check.dart            structural: 1527 assertions over the parsed model
tool/check_against_oracle.dart   replays the fixture frame by frame and compares
                                 every bone matrix + slot display index against
                                 dumps produced by the official runtime
```

Current result on the `Dragon` fixture:

```
  rest     2 frames, 19 bones, max error 4.945e-7  OK
  stand   31 frames, 19 bones, max error 4.997e-7  OK
  walk    21 frames, 19 bones, max error 4.983e-7  OK
  jump     6 frames, 19 bones, max error 4.987e-7  OK
  fall     6 frames, 19 bones, max error 4.989e-7  OK

8712 comparisons, 0 mismatches (tolerance 0.0001)
RESULT: PASS
```

An error of ~5e-7 is the rounding precision of the reference dumps themselves,
so the port is effectively exact. Both scripts run in CI on every push.

## What is implemented

- geom: `Matrix`, `Transform`, `Point`, `Rectangle`, `ColorTransform`
- model: the full 5.x data model (armature, bone, slot, skin, display, animation,
  timeline, texture atlas, user data), including mesh/geometry/weight data
- parser: `ObjectDataParser` for the **text/JSON** format, incl. the binary frame
  array encoding
- armature: `Armature`, `Bone`, `Slot` (with the render hooks left abstract),
  `TransformObject`
- animation: `WorldClock`, `Animation`, `AnimationState` and the timeline states
  (bone translate/rotate/scale/all, slot display/color, action, z-order)

## What is NOT implemented (yet)

- binary `.dragonbones` input (`BinaryDataParser`) — JSON only
- **deform meshes / FFD timelines and skin weights** — parsed, but not evaluated.
  This is milestone 2; the `_updateMesh` hook is a no-op.
- **IK and path constraints** — parsed, not applied (`_buildConstraints` is empty)
- nested child armatures (always resolve to a plain display)
- `Surface` (BoneType.Surface)
- event dispatching (`EventObject` is not ported)

## Deviations from upstream (deliberate)

- **No object pooling.** Upstream implements a per-class pool
  (`BaseObject.borrowObject`). Dart's GC handles this, so objects are constructed
  directly. This is the single biggest structural difference.
- **JS array growth.** Upstream grows arrays with `list.length = n`, which in JS
  creates holes. Dart cannot do that for non-nullable element types, so those
  sites were rewritten to append.
- **An upstream bug was NOT transcribed.** `Slot.set displayFrameCount`, removal
  branch, reads `for (let i = prevCount - 1; i < value; --i)` — the condition is
  never true, so the loop body never runs. The port uses `i >= value` so the
  removal actually happens.
- Unused-member and redundant-cast lints are silenced in `analysis_options.yaml`
  because a transcription keeps members a given milestone does not exercise yet.
