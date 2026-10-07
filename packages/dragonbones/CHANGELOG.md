# Changelog

## 0.1.0

First release. A pure-Dart runtime for the DragonBones 5.x skeletal animation
format, with **zero dependencies** — it runs on a bare Dart SDK, including on the
web and headless.

It evaluates armatures, bone translate/rotate/scale/all timelines, slot display
and colour timelines, deform (FFD) timelines, FFD and skinned deformable meshes,
IK constraints and nested child armatures, and exposes the posed result as a
framework-agnostic draw list (`Armature.buildDrawList()`).

Verification is the point of this package: the whole runtime is diffed frame by
frame against the official DragonBones runtime, across three hand-picked fixtures
and all 44 demo assets from the DragonBones Unity SDK — **757,701 numeric
comparisons, 0 mismatches**. See the repository for the harness
(`tool/ground_truth/`) and the raw results.

### Known limitations in this release

Everything below is *parsed* but not *evaluated*, which means a file using it
loads and mostly animates, then is subtly wrong rather than failing loudly:

- **Animation events** (`EventObject`) are not ported — no `loopComplete` /
  `complete` / frame events, so gameplay cannot yet be driven from an animation.
- **IK constraint timelines** are not ported. Static IK is applied and verified;
  *animated* IK weight/bend is ignored.
- **Path constraints** (`PathConstraint`) are parsed but never built.
- **`Surface` bones** have model classes only; the timeline is never created.
- **`SlotZIndex` timeline** is not ported (static z-order works).
- **`BoneAlpha` / `SlotAlpha` timelines** are not ported (`AlphaTimelineState`
  exists but is never instantiated; `SlotColor`, which carries an alpha
  multiplier, does work).
- **Animation blend timelines** (`AnimationProgress`, `AnimationWeight`,
  `AnimationParameter`) are not ported.
- **Binary `.dragonbones` input** is not supported — JSON export only.
- **No object pooling**, unlike upstream: Dart's GC handles it. The single
  biggest structural deviation, and it is not benchmarked.
