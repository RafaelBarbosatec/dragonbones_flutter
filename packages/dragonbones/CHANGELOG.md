# Changelog

## 0.1.1

Packaging and hygiene release after the first publish. No change to the
animation maths — the frame-by-frame oracle diff in CI re-verifies that on every
push (757,701 numeric comparisons, 0 mismatches).

**pub.dev score fixes.** The 0.1.0 archive lost 30 of 160 pub points, all of it
recoverable:

- `description` shortened from 182 to 171 characters — pub.dev rejects anything
  over 180, and that alone cost the whole 10-point "valid `pubspec.yaml`"
  section.
- `publish_to: none` removed. It was deliberate while nothing was published, but
  it also made pub.dev unable to verify the `repository` URL: pana requires the
  repository's own pubspec to *not* carry `publish_to`.
- The 50 lint findings from pub.dev's rule set (`package:lints/core.yaml`) are
  fixed, and `analysis_options.yaml` now mirrors that exact rule set so a clean
  local `dart analyze` is the same clean run pub.dev sees. It also sets
  `formatter: page_width: 120`, which is what the sources are formatted to.
- Added `example/example.dart`: a runnable, dependency-free example that parses
  an embedded export, animates it and prints the posed draw list
  (`dart run example/example.dart`).

**Renamed** (two identifiers, both on `@private` classes): `SlotData.DEFAULT_COLOR`
is now `SlotData.defaultColor`, and `IKConstraintData.AddBone` is now
`IKConstraintData.addBone`.

**Also in this release:**

- `WorldClock.add` dropped an `&& value != this` guard that could never be false
  (the comparison was between unrelated types, since `WorldClock` does not
  implement `IAnimatable`). Upstream has no such guard.
- `tool/parse_check.dart` is now an ordinary consumer of the public library,
  instead of a hand-rolled `dragonbones` library that `part`ed the internals in.
- CI gates formatting, because pub.dev scores it.

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
