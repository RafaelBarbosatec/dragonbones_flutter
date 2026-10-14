#!/usr/bin/env bash
# Downloads fixtures for features the runtime does not evaluate yet, so the
# roadmap has real assets to implement and verify against.
#
# Staged here, deliberately NOT in the oracle sweep yet:
#
#   shizuku/shizuku_ske.json                slotAlpha, slotZIndex, Surface bones
#                                           and their timelines, animation blend
#                                           (progress/parameter). Version 5.6,
#                                           117 surface bones, 489 animations.
#   binary/mecha_1002_101d_show_ske.dbbin   the binary `.dragonbones` container
#                                           (magic `DBDT` + embedded JSON).
#
# The sweep picks each one up as its feature lands. The revisions are pinned so
# the fixtures cannot drift.
#
#   tool/ground_truth/fetch_features.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

SITE_SHA="${DRAGONBONES_SITE_SHA:-2c5d1750170a988e0e32b41227eab86f66ce17de}"
JS_SHA="${DRAGONBONES_JS_SHA:-64b6c69ae35777c2404be68c9192e2c56906079e}"

SITE="https://raw.githubusercontent.com/DragonBones/dragonbones.github.io/$SITE_SHA"
JS="https://raw.githubusercontent.com/DragonBones/DragonBonesJS/$JS_SHA"

DEST="test/fixtures/features"
mkdir -p "$DEST/shizuku" "$DEST/binary"

fetch() {
  local url="$1" out="$2"
  if [ -s "$out" ]; then
    echo "skip   $out"
    return
  fi
  curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$out.tmp"
  mv "$out.tmp" "$out"
  echo "fetch  $out"
}

# shizuku: the EyeTracking demo (Haxe/XFL export). Its texture atlas is embedded
# in the skeleton under "textureAtlas", so there is no separate `_tex.json`.
fetch "$SITE/demo/EyeTracking/resource/shizuku/shizuku_ske.json" \
  "$DEST/shizuku/shizuku_ske.json"

# The same asset the JSON fixtures come from, in its binary container.
fetch "$JS/Cocos/Demos/assets/resources/mecha_1002_101d_show/mecha_1002_101d_show_ske.dbbin" \
  "$DEST/binary/mecha_1002_101d_show_ske.dbbin"

echo
echo "features fixtures -> $DEST"
ls -l "$DEST/shizuku" "$DEST/binary"
