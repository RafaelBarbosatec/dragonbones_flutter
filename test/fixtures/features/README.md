# Staged feature fixtures

Assets for features the runtime **parses but does not evaluate yet**. They are
committed here so the roadmap work has real, reproducible material to implement
and verify against — they are deliberately **not** in the oracle sweep, which
picks each one up when its feature lands.

Fetch/refresh them with:

```bash
tool/ground_truth/fetch_features.sh
```

The revisions are pinned in that script. `tool/ground_truth/feature_usage.py`
reports which of these features each fixture exercises.

| Fixture | Exercises | Blocks on |
| --- | --- | --- |
| `shizuku/shizuku_ske.json` | `slotAlpha` (9 timelines), `slotZIndex` (36), `Surface` (117 bones, 198 timelines), animation `blendType` (progress/parameter) | Surface bones + the alpha/zIndex timelines |
| `binary/mecha_1002_101d_show_ske.dbbin` | the binary `.dragonbones` container (`DBDT` magic, embedded JSON) | the binary data parser |

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
