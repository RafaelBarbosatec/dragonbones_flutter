#!/usr/bin/env python3
"""Count how many real fixtures use each "parsed but not evaluated" feature.

No Dart involved: pure JSON walk over test/fixtures/**. Used to prioritise the
roadmap against evidence instead of vibes.

    python3 tool/ground_truth/feature_usage.py

The roadmap is ordered against these numbers, so the bugs this script used to
carry mattered: it looked under `tool/test/fixtures` (so it always reported "0
assets") and treated every display's texture `path` as a path constraint. Both
are fixed here, and the newer `"timeline"` array format (numeric types) is
covered alongside the legacy per-group arrays.
"""
import glob
import json
import os
from collections import defaultdict

# tool/ground_truth -> repository root -> test/fixtures
ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "test", "fixtures"
)

# Timeline type numbers, per the port's TimelineType enum.
TYPE_MAP = {
    23: "slot-zindex",
    24: "slot-alpha",
    30: "ik-timeline",
    50: "surface-timeline",
    60: "bone-alpha",
}

# feature -> set of fixture asset dirs that use it
hits = defaultdict(set)
# feature -> set of human-readable examples
examples = defaultdict(set)


def _mark(feature, asset, example=None):
    hits[feature].add(asset)
    examples[feature].add(example or asset)


def walk(node, feature, asset):
    """Recursively find any dict carrying `feature` as a key with a truthy value."""
    if isinstance(node, dict):
        if node.get(feature):
            _mark(feature, asset)
        for value in node.values():
            walk(value, feature, asset)
    elif isinstance(node, list):
        for value in node:
            walk(value, feature, asset)


def scan_skeleton(path):
    asset = os.path.dirname(path)
    with open(path) as handle:
        try:
            data = json.load(handle)
        except json.JSONDecodeError:
            return

    # Frame events: {"evt": ...} anywhere, or an "actions" / "defaultActions"
    # list on a frame.
    walk(data, "evt", asset)
    walk(data, "actions", asset)
    walk(data, "defaultActions", asset)
    # Animation blending (newer exports set `blendType` on the animation).
    walk(data, "blendType", asset)

    for armature in data.get("armature", []):
        # Path constraints live on the armature under "path". A display's
        # texture `path` is a different thing, which is why this is not a walk.
        for _ in armature.get("path", []) or []:
            _mark("path", asset)

        # Surface bones: numeric (1) in 5.x exports, the "surface" string in
        # the 5.6 XFL-style export.
        for bone in armature.get("bone", []) or []:
            if bone.get("type") in (1, "surface"):
                _mark("surface-bone", asset)

        for animation in armature.get("animation", []) or []:
            # Newer format: a single `timeline` array carrying numeric types.
            for timeline in animation.get("timeline", []) or []:
                key = TYPE_MAP.get(timeline.get("type"))
                if key:
                    _mark(key, asset, f"{asset} :: timeline :: {timeline.get('name')}")
            # Legacy format: per-group arrays, the type implied by the key.
            for group in ("bone", "slot", "ik", "ffd"):
                for timeline in animation.get(group, []) or []:
                    key = TYPE_MAP.get(timeline.get("type"))
                    if key:
                        _mark(key, asset, f"{asset} :: {group} :: {timeline.get('name')}")
            # IK timelines may live under anim["ik"] without a type key.
            if animation.get("ik"):
                _mark("ik-timeline", asset, f"{asset} :: ik group")


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "**", "*ske*.json"), recursive=True))
    print(f"scanned {len(files)} skeleton files\n")
    for path in files:
        scan_skeleton(path)

    order = [
        "actions",
        "defaultActions",
        "evt",
        "ik-timeline",
        "path",
        "surface-bone",
        "surface-timeline",
        "slot-zindex",
        "slot-alpha",
        "bone-alpha",
        "blendType",
    ]
    for key in order:
        count = len(hits[key])
        if count == 0:
            print(f"{key:20s} 0 assets  -- no fixture exercises this")
            continue
        print(f"{key:20s} {count:2d} assets")
        for example in sorted(examples[key])[:4]:
            print(f"                      e.g. {example}")
    print()


if __name__ == "__main__":
    main()
