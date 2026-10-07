# Findings — DragonBones on Flame/Bonfire

Investigation notes, with sources. Written before any code, so the decisions
below are traceable.

## 1. What the Godot plugin actually is

`DragonBones/Godot-DragonBones` (the repo that started this) is a **GDExtension** —
C++ on top of `godot-cpp`, authored by Daylily-Zeleen, adopted into the official
DragonBones org. Godot 4.2+, targets DragonBones Pro 5.6 assets, MIT.
*Improved from* [`gddragonbones`](https://github.com/sanja-sa/gddragonbones).

| Part | LOC | Useful for Flutter? |
| --- | ---: | --- |
| `src/` — Godot binding | 4,745 | ❌ engine-specific — **but ~2.7k of it is the render layer, which is a valuable reference** |
| `thirdparty/dragonBones` — C++ runtime | 19,384 | ✅ the official runtime, vendored |
| `thirdparty/rapidjson` | — | ❌ (Dart has `dart:convert`) |

The vendored runtime is **byte-identical to the official
[DragonBonesCPP](https://github.com/DragonBones/DragonBonesCPP)** — verified by
md5 of `armature/Bone.cpp` (`ea88ca3577a1…`, 406 lines, both sides).

**Takeaway:** we do not port the Godot plugin. We take its *render contract* as
reference and choose our own runtime source.

## 2. Nothing exists for Dart/Flutter

| Check | Result |
| --- | --- |
| `gh search repos "dragonbones flame"` | empty |
| `gh search repos "dragonbones flutter"` | empty |
| `gh api search/code?q=dragonbones+language:dart` | only `stagexl_dragonbones` and unrelated hits |
| pub.dev `flame_bones`, `flame_dragonbones`, `bonfire_bones`, `dragonbones_flutter`, `flame_dragon_bones` | all **404 — names free** |

The one prior Dart port, [`bp74/StageXL_DragonBones`](https://github.com/bp74/StageXL_DragonBones):

- last commit **2020-09-19**, published as `stagexl_dragonbones` 0.3.2
- SDK constraint `>=2.9.0 <3.0.0` → **does not resolve on Dart 3**
- only **1,343 LOC** and its parser is `dragon_bones_parser_json4.dart` — the
  **old 4.x format**
- rendering is coupled to **StageXL**, a different engine

So it is not reusable. It is, however, *evidence that a Dart port is tractable*.

## 3. Flame's position

- [flame-engine/flame#1516](https://github.com/flame-engine/flame/issues/1516) (2022, closed) —
  spydon: *"export your animation to a spritesheet … Otherwise I can recommend Rive"*.
- [flame-engine/flame#3788](https://github.com/flame-engine/flame/issues/3788) (**open**, 2025-12-08) —
  *"spine 2D animation as well as Rive animations are not free … Dragonbones is a
  free alternative to Spine 2D animations."* spydon's reply:

  > "Duplicate of #1516, but I'll keep this one open. We're not planning on
  > implementing this from the core team, but if anyone feels like creating a
  > bridge package to live in the monorepo we're more than happy to review it and
  > take it in."

- Existing bridges follow exactly that shape: `flame_spine`, `flame_rive`,
  `flame_lottie`, `flame_svg`. Flame **core has no mesh/vertices component**
  (grepping `flame-engine/flame` for `drawVertices` / `VerticesComponent` finds
  nothing) — the bridge owns its rendering.

## 4. Rendering: feasible on `Canvas`

Godot's mesh display feeds the renderer this structure (from
`src/mesh_display.cpp`):

```
DrawData = { transform, vertices[], indices[], colors[], uvs[], texture, blend_mode, zOrder }
```

grouped by `zOrder`, batched by texture + blend mode. The Flutter equivalent is
direct:

| DragonBones | Flutter |
| --- | --- |
| `vertices` + `indices` + `uvs` | `ui.Vertices.raw(VertexMode.triangles, …, textureCoordinates: …)` |
| per-vertex `colors` | `Vertices(colors: …)` |
| `blend_mode` | `Canvas.drawVertices(…, BlendMode)` (`plus` for additive) |
| `texture` per slot | one draw call per texture (the runtime already batches this way) |
| `zOrder` | draw order / Flame `priority` |
| plain sprite slot | `drawImageRect` / `drawRawAtlas` (batchable) |

Two notes that matter:

- **Deformation is CPU-side.** DragonBones skins vertices against bone matrices in
  the runtime (`DeformVertices`), not in a shader. That is portable Dart with **no
  custom shaders required**.
- ⚠️ **ColorTransform has multipliers *and* offsets.** Per-vertex `colors` in
  `drawVertices` can only *multiply*. Additive offsets would need a
  `ColorFilter.matrix` per draw call. Most exports only use alpha/colour
  multipliers, so v1 is probably fine — but this is the first thing to verify in
  the renderer.

## 5. Two routes, and why pure Dart wins

| | **A. Pure Dart port** | **B. FFI onto DragonBonesCPP** |
| --- | --- | --- |
| Work | port the runtime + write the Flame component | C shim + FFI bindings + per-platform builds |
| LOC | ~18k full, ~9–12k for a v1 subset | ~3–5k |
| Flutter **web** | ✅ works | ❌ (wasm only) |
| pub.dev | ✅ pure source | ⚠️ prebuilt binaries |
| Build infra | **none** | CMake / Gradle / CocoaPods per OS |
| Correctness risk | medium (translation) | **low** (mature runtime) |
| Precedent | `flame_lottie` | `spine_flutter` |

**Decision: route A, porting from TypeScript.** Reasons:

- [DragonBonesJS](https://github.com/DragonBones/DragonBonesJS) core is
  **18,331 LOC**, the most maintained runtime (853★, pushed 2026-01) and the
  format's reference implementation.
- Decisive: the **C++ runtime manages memory manually** (object pooling,
  refcounting, `returnToPool`). Porting that to Dart would be work thrown away —
  Dart's GC does it. TypeScript is GC'd, structurally close to Dart
  (`Map<string, T>`, `Float32Array` → `Float32List`, same class semantics).
- Route A stays pure Dart, so it works on web, needs no toolchain, and can be
  published as source.

## 6. Risks / open questions

| Risk | Status |
| --- | --- |
| **Editor** | `dragonbones.com` is **down** (connection timeout, both apex and www). Successor is **Loongbones** (`loongbones.com` and `loongbones.app` both live; the runtime itself prints `Website: http://www.loongbones.app/`). |
| **Runtimes** | alive & maintained: DragonBonesJS (push 2026-01), DragonBonesCPP (push 2025-07, MIT), DragonBonesCSharp (push 2026-05). |
| Format stability | 5.5/5.6 JSON is stable and fully readable by the 5.7 runtime. |
| `drawVertices` colour offsets | see §4 — needs a renderer spike. |
| Visual verification | no Flutter SDK on the dev box used for this spike → the renderer must be validated on a real machine or via golden tests in CI. |

## 7. Verification strategy

The oracle harness (`tool/ground_truth/dump.js`) drives the **official runtime**
headlessly — a `BaseFactory` subclass whose `_buildArmature`/`_buildSlot` return
no-op shells, so no GPU or engine is involved — and dumps, per frame:

- every bone's `globalTransformMatrix` (`[a, b, c, d, tx, ty]`),
- every slot's `displayIndex` and `ColorTransform`.

The Dart port replays the same frames and asserts equality within a float
tolerance. A green diff means the port is correct **without rendering anything**.

To capture deformed mesh vertices as oracle data, `_updateMesh` must be
implemented in the harness the way engines do it (skin vertices against bone
matrices) — that is milestone 2 work.

---

## 8. Milestone 2 — meshes, FFD and nested armatures (what it actually took)

Four things had to be discovered the hard way. Each is now encoded in the code
and in the oracle, with a comment explaining why.

### 8.1 The port was dropping `_onClear()` — and that broke more than pooling

The port skips upstream's object pool (Dart has a GC) and constructs objects
directly. That looked harmless, but upstream's `BaseObject.borrowObject` is:

```ts
const object = new objectConstructor();
object._onClear();          // always, even on a brand new object
return object;
```

`_onClear()` is not merely "reset a recycled object" — it is where a subclass
establishes its default state. `ArmatureDisplayData`, `MeshDisplayData`,
`PathDisplayData` and `BoundingBoxDisplayData` set their `type` there and
**nowhere else**. Without the call, every subclass kept the base default
`DisplayType.Image`, so:

* a slot holding a nested armature crashed on load
  (`type 'ArmatureDisplayData' is not a subtype of type 'ImageDisplayData'`),
* mesh slots were silently treated as sprites.

Fix: `BaseObject`'s constructor calls `_onClear()`. Safe in Dart because a
subclass's field initializers run *before* the superclass constructor body
(verified empirically), so every field in the chain is initialised by then.

This is the general lesson: **when a port drops a mechanism, check what else that
mechanism was doing.** Here the pool was load-bearing for initialisation.

### 8.2 Mesh deformation is not in the runtime — it is in the *binding*

`Slot._updateMesh()` is abstract in the core runtime and **no implementation
exists there**. Every engine writes its own. So the oracle for mesh geometry is
`.ref/egret-binding/EgretSlot.ts`, transcribed verbatim into
`tool/ground_truth/dump.js`, and then separately into
`packages/dragonbones/lib/src/render/mesh_geometry.dart`.

Two paths, both CPU-side (no shaders anywhere in DragonBones deformation):

| Path | Algorithm |
| --- | --- |
| plain mesh | rest vertices × armature scale, plus deform offsets |
| skinned mesh | per vertex, sum over bones: `(boneMatrix × (localOffset × scale + deform)) × weight` |

Storage is in the shared flat arrays on `DragonBonesData`
(`Int16List intArray` / `Float32List floatArray`), reached through
`geometry.offset` and `weight.offset`. Offsets are stored in the **int16** array,
so anything past 32767 wraps negative and needs `+= 65536` — upstream calls this
"Fixed out of bounds bug" and it is load-bearing.

Mesh UVs are normalised to the atlas **sub-texture** (0..1 across `region`), not
to the whole atlas — confirmed by `MeshNode.drawMesh(bitmapX, bitmapY,
bitmapWidth, bitmapHeight, ...)` and by the mesh bounding box matching the region
size (`tou`: 178.3×214.9 vs region 176×213).

### 8.3 FFD needed `DeformTimelineState`, and the fixture check that missed it

`龙`'s `stand` animation looked timeline-less at first: the timelines live under
the `ffd` key, not `timeline`. Once found, the missing piece was clear —
`DeformTimelineState` (a *blend* timeline, so its target is a `BlendState`, not
the slot), plus the lazy `displayFrame.updateDeformVertices()` and the pose
fallback. The parser already read the data (`_parseSlotDeformFrame`); only the
animation side was missing.

Symptom if you skip it: mesh vertices that should breathe stay frozen, and the
oracle diff lights up on every mesh with deform.

### 8.4 Three more JS→Dart growth bugs

Same family as the three already documented in the port: `weightBoneIndices` was
created with `List<int>.filled(0, 0)` and then grown with `.length = n`, which
throws on a fixed-length Dart list — so **`龙` had never actually been parsed**.
The int array also relied on JS's auto-grow-on-write for the per-weight-bone
index table, which Dart needs reserved explicitly (`_growInt`).

### 8.5 Nested armatures: two real bugs, both silent

`mecha_1004d` packs four armatures into one file, three of them mounted on slots
of the first. Two things were wrong:

1. `_getSlotDisplay` returned `childArmature.display` (the engine proxy).
   Upstream returns the **`Armature` itself** — `Slot._updateDisplay` tests
   `_display is Armature` to adopt the child and wire its clock, parent and
   animation. Returning the proxy left the child permanently un-animated, with
   no error.
2. The draw list only walked the top-level armature's slots, so the weapon and
   effect armatures were built and updated but never drawn.

Fix: return the child `Armature`, and flatten children into `buildDrawList()` —
a slot with a child contributes the child's slots in its place, with the parent
slot's matrix composed onto theirs. That mirrors what an engine does by
parenting the child's display object to the slot's display (`EgretSlot._addDisplay`
→ `addChild`), and it means a renderer never has to know child armatures exist.

The composition direction matters and is easy to get backwards: in this runtime
`m.copyFrom(x); m.concat(y)` means "apply x, then y", so the **child** goes in
first. Inverted, the child is silently mirrored about the origin.

### 8.6 Result

```
172925 numeric comparisons, 0 mismatches (tolerance 0.0001)
21173 mesh values, 118 nested-armature slots
RESULT: PASS
```

targets: `Dragon` ×5 (sprites), `龙` (60 bones, 5 meshes — 2 skinned — with
animated FFD), `mecha_1004d` (nested armatures). `mecha` peaks at 5.2e-5 rather
than 5e-7 purely because composing two matrices per child slot compounds the
reference dumps' own rounding.
