# Feature fixtures

Assets for the timeline features: the hand-authored `alpha` and `zindex` ones are
already in the oracle sweep, and the downloaded ones (`shizuku`, the binary
container) are committed so the remaining work has real, reproducible material —
they stay out of the sweep until their features land.

Fetch/refresh the downloaded ones with:

```bash
tool/ground_truth/fetch_features.sh
```

The revisions are pinned in that script. `tool/ground_truth/feature_usage.py`
reports which of these features each fixture exercises.

| Fixture | Exercises | Status |
| --- | --- | --- |
| `alpha/alpha_ske.json` | `slotAlpha` + `boneAlpha`, hand-authored in the `timeline` format | **swept** (`feature_alpha`) |
| `zindex/zindex_ske.json` | `slotZIndex`, hand-authored in the `timeline` format | **swept** (`feature_zindex`) |
| `shizuku/shizuku_ske.json` | `Surface` (117 bones, 198 timelines), animation `blendType` (progress/parameter), plus `slotAlpha`/`slotZIndex` | staged — blocks on Surface + blend |
| `binary/mecha_1002_101d_show_ske.dbbin` | the binary `.dragonbones` container (`DBDT` magic, embedded JSON) | staged — blocks on the binary parser |

## alpha

A minimal armature (two bones, one slot) hand-authored in the newer `timeline`
array format, with a `slotAlpha` timeline on the slot and a `boneAlpha` timeline
on the child bone. It is the first feature fixture in the oracle sweep
(`feature_alpha`): the effective alpha is `0.25` (slot) × `0.5` (bone) = `0.125`
on the frames where both are active.

## zindex

A minimal armature (one bone, two slots) hand-authored in the `timeline` format,
with a `slotZIndex` timeline on `front`. The draw order flips from
`[back, front]` to `[front, back]` and back, which the oracle confirms frame by
frame (`feature_zindex`).

## shizuku

The EyeTracking demo from the official DragonBones site, exported at version
5.6: 135 bones, 131 slots, **489 animations**. The texture atlas is embedded in
the skeleton under `"textureAtlas"` (five atlases), so there is no separate
`_tex.json`.

It is large and only a handful of its animations use the interesting features
(`PARAM_*`, `B_*`, `D_*`). When it joins the sweep, target those animations
individually rather than dumping all 489.

The current runtime **cannot build it yet**: `_buildBones` always creates a
plain `Bone`, and a `Surface` bone hits a failed cast. That is expected — it is
the fixture for the Surface work.

## binary

The same `mecha_1002_101d_show` asset the JSON fixtures use, in its container
form (`DBDT` header followed by a JSON header and typed arrays). Kept for the
binary-parser work.
