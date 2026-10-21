# Changelog

## 0.4.0

**Animated IK, `Surface` bones and animation blend nodes.** Three features that
the parser already decoded but the runtime never executed now reach the
armature: an IK constraint follows its timeline, a `Surface` bone deforms its
mesh through a per-cell affine transform, and an export that nests one animation
inside another starts and drives those child states. A skeleton JSON that embeds
its own atlases (`"textureAtlas"`) also loads without registering the atlas by
hand.

**Animated IK constraints.** `AnimationState._updateTimelines()` was a no-op, so
`IKConstraintTimeline` data was parsed and silently dropped: a constraint kept
its static `weight` / `bendPositive` for the whole clip.

- `IKConstraintTimelineState` is wired into the constraint switch, plus the pose
  timeline that restores the constraint's rest values when an animation declares
  no IK timeline for it.
- The frame semantics are upstream's, including the non-obvious part: the
  official runtime reads `_currentA` / `_currentB` — the value the timeline
  arrived at the *start* of the segment — not the interpolated `_resultA` /
  `_resultB`. An animated weight therefore **steps** at frame boundaries instead
  of tweening, and a non-tween frame never applies. That is reproduced
  deliberately: "fixing" it would be a silent divergence from every other
  DragonBones player.
- Verified by a hand-authored fixture (`test/fixtures/features/ik`): no asset in
  the SDK animates IK — they only use it statically — so the fixture drives
  `weight` and `bendPositive` across frames. The pose oracle compares it frame
  by frame (25 frames, 4 bones, max error 4.98e-7).

**`Surface` bones.** `BaseFactory._buildBones` always created a plain `Bone`, so
a skeleton with `"type": "surface"` crashed on the cast to `Surface` (and
`SurfaceTimelineState` did not exist).

- `Surface` is now created for `BoneType.Surface`: it builds its vertex grid,
  applies the parent's transform per cell, caches the hull and the inside/outside
  affine matrices, and rebuilds them when the deform data is dirty.
- `SurfaceTimelineState` blends the frame's deform values into the surface and
  marks the transform dirty; pose timelines for a surface are handled separately
  from `BoneAllTimelineState`.
- `buildMeshGeometry` accepts an optional `Surface` and poses each vertex through
  `Surface`'s per-cell matrix instead of a single bone matrix — this was the
  branch that used to be documented as unported.
- Verified against `shizuku`, the only fixture that contains a Surface bone:
  13 frames, 65.507 mesh values, max error 5.0e-7.

**Animation blend nodes (`animationTimelines`).** The parser already produced
`AnimationProgress` / `AnimationWeight` / `AnimationParameter` timeline data, but
`AnimationState.addState()` was empty and `Animation._parseAnimations` did not
exist, so nested animations were never started.

- Playing a parent animation now fades in each animation named in
  `animationData.animationTimelines`, disables its action, stops it at the parent's
  timeline, and attaches it with its own blend timelines. Parent states are
  ordered before their children so the parent is updated first.
- `AnimationProgress` (E1D) drives the child's `positionX` / `positionY` and
  `weight`; `AnimationWeight` and `AnimationParameter` follow the upstream
  switch. The child's `weight` is applied through the normal blend states, so no
  renderer change is needed.
- Verified against `shizuku` (`blendType: E1D`): 13 frames, 65.507 mesh values,
  max error 5.0e-7.

**Embedded texture atlases.** `BaseFactory.parseDragonBonesData` registered the
skeleton but not the atlases carried inside it, so single-file exports failed to
resolve regions and fell back to the "region missing" placeholder. It now loops
over the embedded `textureAtlas` entries and adds each one, matching the official
runtime.

**Oracle coverage.** The pose oracle went from 53 to 56 assets and from 759.801
to **1.353.695 numeric comparisons** (205.259 mesh values over 1.228
nested-armature slots), all within 5e-7; the event oracle still replays 174
scenarios / 1.919 events. Two new test files (`ik_test.dart`,
`shizuku_test.dart`) cover the features directly, and both were checked to fail
with the feature disabled — 18° of IK error and 18 units of blend offset
respectively — so they are not passing by accident.

No public API change.

## 0.3.0

**`SlotAlpha` / `BoneAlpha` timelines.** The alpha timelines from the newer
`timeline` array format now reach the armature: `SlotAlpha` fades a slot, and
`BoneAlpha` fades a bone and its children. `AlphaTimelineState` already existed
— it is now instantiated, mirroring upstream's
`AnimationState._updateBoneAndSlotTimelines`.

- `TimelineType.BoneAlpha` and `TimelineType.SlotAlpha` are wired into the
  timeline switch, each getting its own blend state (`BlendState.BONE_ALPHA` /
  `SLOT_ALPHA`).
- The effective alpha (`_globalAlpha`, the product down the bone hierarchy) is
  folded into `Slot.colorValues`, so a renderer gets it with no change: the
  colour's `alphaMultiplier` already carries it.
- The oracle now dumps that effective alpha (`dump.js` multiplies by
  `_globalAlpha`, which is `1.0` for every other asset), and a new fixture —
  `test/fixtures/features/alpha`, hand-authored in the `timeline` format because
  the SDK demos predate alpha timelines — is checked frame by frame: a `0.25`
  slot alpha under a `0.5` bone alpha lands on the effective `0.125`.

**`SlotZIndex` timeline.** A slot's z-index can now be animated. When it blends
it sets `_zIndexDirty`, and the armature re-sorts its slots and re-stamps
`_zOrder` on the next update — so the draw order actually changes, not just a
number.

- New `SlotZIndexTimelineState` (ported from upstream), wired into the slot
  timeline switch with `BlendState.SLOT_Z_INDEX`.
- `Slot._zIndex` is now a `double`, matching upstream's `number` (a blended
  z-index can be fractional; the sort only compares it).
- Verified by `test/fixtures/features/zindex`, hand-authored with two slots whose
  order swaps: the draw list is `[back, front]`, then `[front, back]`, then
  `[back, front]`, matching the official runtime exactly.

## 0.2.0

**Animation events.** The runtime no longer only *draws* an animation — it
reports what happens on the timeline, in the order the official runtime reports
it. This was the last gap that broke a game rather than merely limiting it: with
no events there is no way to play a footstep, spawn a projectile or open a
hitbox on a specific frame, and no way to know an animation finished.

```dart
armature.eventDispatcher.addDBEventListener(EventObject.COMPLETE, (event) {
  print('${event.animationState!.name} finished');
});
```

- **`EventObject`** and a full **`IEventDispatcher`**, ported from upstream. The
  dispatcher is the *binding's* to implement, exactly as upstream intends:
  `IArmatureProxy` now extends `IEventDispatcher` (see *Breaking* below).
- **Frame events and sound events** (`"events"` / `"sound"` on a timeline frame),
  including whatever the animator attached — `actionData`, and the `ints` /
  `floats` / `strings` of its `UserData`.
- **Lifecycle events**: `start`, `loopComplete`, `complete`, `fadeIn`,
  `fadeOut`, `fadeInComplete`, `fadeOutComplete`.
- **`gotoAndPlay` actions** are queued on the armature and run after the pose is
  settled, so a nested armature can be started from its own display data — and
  so a listener may safely play another animation from inside a callback.
- **Events are dispatched after the frame is advanced**, never during it
  (`DragonBones.bufferEvent` → dispatched at the end of `DragonBones.advanceTime`).
- **Child-armature propagation**: playing an animation on a parent now plays the
  same-named animation on every nested child that declares one. This was ported
  as "milestone 2" and had been skipped; without it a composite character (a body
  plus its equipment) would only partly change pose.
- A `soundEvent` is delivered twice — once on the armature and once on
  `DragonBones.eventManager`. That is upstream behaviour, not duplication: audio
  belongs to the application.
- **Listening to nothing costs nothing**: as upstream, an event is only built
  when `hasDBEventListener` reports a listener.

**Fixed: a crash when a `displayFrame` timeline swaps a child armature.** The
port's `WorldClock.remove` shrank the list, and `advanceTime` walked it with a
length captured up front — so disposing an armature *during* the walk (which is
exactly what swapping a slot's nested armature does) shifted the list under the
loop and walked off the end. Upstream blanks the entry and compacts in place,
and that is now what this port does. `mecha_1004d`, whose `attack_01` /
`skill_01` / `skill_03` swap a weapon armature mid-animation, is the fixture that
catches it. (Not new in 0.2.0 — the bug was latent, and only a test that
exercises actions could find it.)

**Breaking**, all of it to match upstream's shape:

- `IArmatureProxy` now `implements IEventDispatcher`, so a custom proxy must also
  provide `hasDBEventListener`, `addDBEventListener`, `removeDBEventListener` and
  `dispatchDBEvent`. `addDBEventListener` takes `void Function(EventObject)`
  (upstream's `(listener, thisObject)` pair is dropped — Dart closures capture
  their own context).
- `Armature.eventDispatcher` returns the proxy, as before, but is now useful.
- The `DragonBones` hub constructor takes an optional `eventManager`. Upstream
  requires it; here it is optional so a headless consumer that only wants frame
  events can omit it.

**Also:**

- `HeadlessFactory` accepts an optional `proxyFactory`, to observe or route the
  events of every armature it builds — including nested children, which are built
  mid-update.
- `HeadlessArmatureDisplay` now carries a working dispatcher, so the headless
  factory is a complete binding for logic, not just geometry.
- `Armature.dragonBones` exposes the hub, so a binding can advance the clock
  instead of the armature (which is what makes events dispatch).
- `WorldClock` gained upstream's `clear()`, and `add` now sets `value.clock`
  (upstream does; the port relied on callers to do it).

Verification: the new `tool/check_events_against_oracle.dart` replays every
fixture twice (`playTimes: 1` and `2`) and compares the **event sequence** —
frame, type, name, time, armature, animation state, bone, slot — against the
official runtime. **47 fixtures, 174 scenarios, 1,919 events, 0 mismatches.** The
pose oracle is unchanged and still passes (757,701 comparisons).

That harness also had to be fixed before it could exist: it fed the reference
runtime JSON parsed in a *different* `vm` realm, and the official parser tests
`rawData instanceof Array` in `_parseActionData` — which is false across realms,
so every action had been silently dropped. See `tool/ground_truth/dump_events.js`.

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
