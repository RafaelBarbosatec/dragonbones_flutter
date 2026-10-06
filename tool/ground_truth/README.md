# Ground truth (the oracle)

This directory wraps the **official DragonBones runtime** so we can compare the
Dart port against it, number by number, without rendering anything.

The trick: DragonBones separates the *runtime* (parsing, skeleton, animation,
deformation) from the *engine binding* (drawing). Each engine — Egret, Pixi,
Phaser, Godot — supplies small subclasses that do the drawing. Supply no-op
subclasses instead and the runtime runs **headlessly in node**.

`dump.js` therefore defines:

- `HeadlessArmatureDisplay` — a no-op `IArmatureProxy`
  (`dbInit`/`dbUpdate`/`dbClear`/listeners).
- `HeadlessSlot` — a `Slot` with every abstract render method stubbed
  (`_updateFrame`, `_updateMesh`, `_updateTransform`, …).
- `HeadlessTextureAtlasData` / `HeadlessTextureData` — atlas shells.
- `HeadlessFactory` — a `BaseFactory` whose `_buildArmature`/`_buildSlot` return
  the shells above.

Each class needs a `static toString()` — that string is the object-pool key used
by `BaseObject.borrowObject`, and it throws without one.

## Usage

```bash
# one asset
node dump.js <ske.json> <tex.json> <animationName> <out.json>

# everything
run_all.sh
```

## Output shape

```jsonc
{
  "runtimeVersion": "5.7.000",   // official runtime version used as oracle
  "formatVersion": "5.5",        // version of the exported asset
  "frameRate": 24,
  "armatureName": "Dragon",
  "animationNames": ["stand", "walk", "jump", "fall"],
  "animation": "stand",
  "duration": 1.25,
  "totalFrames": 30,
  "boneCount": 19,
  "slotCount": 18,
  "frames": [
    {
      "frame": 0,
      "time": 0.0,
      "state": {
        "bones": [{ "name": "root", "matrix": [a, b, c, d, tx, ty] }],
        "slots": [{ "name": "tailTip", "displayIndex": 0, "color": [aM, rM, gM, bM, aO, rO, gO, bO] }]
      }
    }
  ]
}
```

Frames are sampled one per animation frame, advancing the armature by
`1 / frameRate` each step, starting from the un-advanced state at `frame 0`.

## Known gap

`_updateMesh` is stubbed, so **deformed mesh vertices are not in the dump yet**.
Capturing them requires implementing the engine-side skinning (applying bone
matrices to weighted vertices) the way Egret/Pixi do — that is milestone 2.
Bone matrices, slot display indices and slot colours are captured today.
