#!/usr/bin/env python3
"""Count how many real fixtures use each 'parsed but not evaluated' feature.

No Dart involved: pure JSON walk over test/fixtures/**. Used to prioritise the
roadmap against evidence instead of vibes.
"""
import json
import glob
import os
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test", "fixtures")

# feature -> set of fixture asset dirs that use it
hits = defaultdict(set)
# feature -> set of human-readable examples
examples = defaultdict(set)


def walk(node, feature, asset):
    """Recursively find any dict carrying `feature` as a key with a truthy value."""
    if isinstance(node, dict):
        if node.get(feature):
            hits[feature].add(asset)
            examples[feature].add(asset)
        for v in node.values():
            walk(v, feature, asset)
    elif isinstance(node, list):
        for v in node:
            walk(v, feature, asset)


def scan_skeleton(path):
    asset = os.path.dirname(path)
    with open(path) as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError:
            return
    armatures = data.get("armature", [])

    # frame events: {"evt": ...} or an "actions" / "defaultActions" list
    walk(data, "evt", asset)
    walk(data, "actions", asset)
    walk(data, "defaultActions", asset)

    # path constraints
    walk(data, "path", asset)
    # animation blending
    walk(data, "blend", asset)

    for arm in armatures:
        # Surface bones: BoneType.Surface == 1
        for bone in arm.get("bone", []):
            if bone.get("type") == 1:
                hits["surface-bone"].add(asset)
                examples["surface-bone"].add(asset)
        # skin mesh slots that reference a "path" constraint also land in walk().

        # timeline type numbers, per the port's TimelineType enum
        TYPE_MAP = {
            23: "slot-zindex",
            24: "slot-alpha",
            60: "bone-alpha",
            30: "ik-timeline",
            50: "surface-timeline",
        }
        for anim in arm.get("animation", []):
            for group in ("bone", "slot", "ik", "ffd"):
                for tl in anim.get(group, []):
                    t = tl.get("type")
                    if t in TYPE_MAP:
                        key = TYPE_MAP[t]
                        hits[key].add(asset)
                        examples[key].add(f"{asset} :: {group} :: {tl.get('name')}")
            # ik timelines may live under anim["ik"] without a type key
            if anim.get("ik"):
                hits["ik-timeline"].add(asset)
                examples["ik-timeline"].add(f"{asset} :: ik group")


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "**", "*ske*.json"), recursive=True))
    print(f"scanned {len(files)} skeleton files\n")
    for f in files:
        scan_skeleton(f)

    order = [
        "evt",
        "actions",
        "defaultActions",
        "ik-timeline",
        "path",
        "surface-bone",
        "surface-timeline",
        "slot-zindex",
        "slot-alpha",
        "bone-alpha",
        "blend",
    ]
    for key in order:
        n = len(hits[key])
        if n == 0:
            print(f"{key:20s} 0 assets  -- no fixture exercises this")
            continue
        print(f"{key:20s} {n:2d} assets")
        for ex in sorted(examples[key])[:4]:
            print(f"                      e.g. {ex}")
    print()


if __name__ == "__main__":
    main()
