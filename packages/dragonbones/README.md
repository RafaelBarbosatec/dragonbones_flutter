# dragonbones

A pure-Dart runtime for **DragonBones** skeletal animation (text/JSON format 5.x).

The defining property of this package is that it has **zero dependencies** — no
Flutter, no platform channels, no third-party packages. That is not minimalism
for its own sake:

- it can be **verified with a bare Dart SDK**, with no GPU and no device, which
  is how the maths is proven correct (see [Correctness](#correctness));
- it runs **anywhere Dart runs**, including the web and headless on a server;
- it can back a Flutter renderer, a Flame component, a Bonfire `GameComponent`,
  or your own `Canvas` code, without dragging an engine along.

```dart
import 'dart:convert';
import 'package:dragonbones/dragonbones.dart';

final factory = HeadlessFactory();
factory.parseDragonBonesData(jsonDecode(skeJson), 'Dragon');
factory.parseTextureAtlasData(jsonDecode(texJson), null, 'Dragon');

final armature = factory.buildArmature('Dragon', 'Dragon')!;
armature.animation.play('stand');
armature.advanceTime(1 / 24);

// Read back the frame as a framework-agnostic draw list.
for (final slot in armature.buildDrawList()) {
  print('${slot.name}: ${slot.matrix}');
}
```

`HeadlessFactory` is a concrete `BaseFactory` that binds no renderer at all. A
real binding subclasses `BaseFactory` and `Slot` instead, and draws the displays
— that is exactly what
[`dragonbones_flutter`](https://pub.dev/packages/dragonbones_flutter) does.

## Correctness

This is a faithful transcription of the upstream TypeScript runtime
(`DragonBonesJS`) — but a transcription is a claim, not a proof, so it is
**diffed against the official runtime**:

```
tool/parse_check.dart            structural: 1527 assertions over the parsed model
tool/check_against_oracle.dart   replays every fixture frame by frame and compares
                                 bone matrices, slot draw data, posed mesh vertices
                                 and nested-armature slots against dumps produced
                                 by the official runtime
```

Result on the current commit:

```
757701 numeric comparisons over 51 assets (51 clean, 0 failing)
74245 mesh values, 1228 nested-armature slots
RESULT: PASS
```

~5e-7 is the rounding precision of the reference dumps themselves, so the port is
effectively exact. Both scripts run in CI on every push.

The 51 assets are the hand-picked ladder (`Dragon`, `龙`, `mecha_1004d`) plus the
entire DragonBones **Unity SDK** demo set — nested armatures, skinned meshes,
animated FFD, active IK constraints and skin swapping. One of them
(`you_xin/body`) is 71 frames, 70 bones, 6,816 slot draw data and 47,357 mesh
values in a single asset.

## What is implemented

- **geom**: `Matrix`, `Transform`, `Point`, `Rectangle`, `ColorTransform`
- **model**: the full 5.x data model — armature, bone, slot, skin, display,
  animation, timeline, texture atlas, user data, including mesh/geometry/weight
  data and constraints
- **parser**: `ObjectDataParser` for the **text/JSON** format, including the
  packed binary frame arrays that format 5.5 embeds in the JSON
- **armature**: `Armature`, `Bone`, `Slot` (render hooks left abstract),
  `TransformObject`, `IKConstraint`
- **animation**: `WorldClock`, `Animation`, `AnimationState` and the timeline
  states — bone all/translate/rotate/scale, slot display/colour, action, z-order,
  and **deform (FFD)**
- **render**: `Armature.buildDrawList()`, which flattens nested child armatures
  and emits the complete per-slot geometry a renderer needs

## What is NOT implemented

Each of these is *parsed* but not *evaluated*, so a file using it will load and
mostly animate, then be subtly wrong rather than fail loudly.

- **Animation events** (`EventObject`) — the dispatcher and the action/loop/
  complete/fade hooks are not ported. You cannot drive gameplay from an
  animation yet.
- **IK constraint timelines** (`IKConstraintTimelineState`) — **static** IK is
  applied (and verified). **Animated** IK weight/bend is ignored.
- **Path constraints** (`PathConstraint`) — data parsed, never built.
- **`Surface` bones** (`SurfaceTimelineState`) — model classes only.
- **`SlotZIndex` timeline** — static z-order works; an animated z-index is ignored.
- **`BoneAlpha` / `SlotAlpha` timelines** — `AlphaTimelineState` exists but is
  never instantiated. The `SlotColor` timeline, which carries an alpha
  multiplier, does work.
- **Animation blend timelines** (`AnimationProgress`, `AnimationWeight`,
  `AnimationParameter`).
- **Binary `.dragonbones` input** (`BinaryDataParser`) — JSON export only.

## Deviations from upstream (deliberate)

- **No object pooling.** Upstream implements a per-class pool
  (`BaseObject.borrowObject`). Dart's GC handles this, so objects are constructed
  directly. This is the single biggest structural difference from the reference
  implementation, and it has not been benchmarked.
- **JS array growth.** Upstream grows arrays with `list.length = n`, which in JS
  creates holes. Dart cannot do that for non-nullable element types, so those
  sites were rewritten to append.
- **An upstream bug was NOT transcribed.** `Slot.set displayFrameCount`, removal
  branch, reads `for (let i = prevCount - 1; i < value; --i)` — the condition is
  never true, so the upstream loop body never runs. The port uses `i >= value` so
  the removal actually happens.
- Unused-member and redundant-cast lints are silenced in `analysis_options.yaml`,
  because a transcription keeps members a given milestone does not exercise yet.

## See also

- **Documentation site** — <https://docs.page/RafaelBarbosatec/dragonbones_flutter>
- [`dragonbones_flutter`](https://pub.dev/packages/dragonbones_flutter) — the
  `Canvas` renderer.
- The repository, for the oracle harness and the reference dumps:
  <https://github.com/RafaelBarbosatec/dragonbones_flutter>.

## Licence

MIT. The DragonBones runtime and format are MIT (© DragonBones team and
contributors).
