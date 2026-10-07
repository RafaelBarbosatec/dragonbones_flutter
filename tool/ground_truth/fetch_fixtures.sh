#!/usr/bin/env bash
# Downloads the DragonBones Unity SDK demo assets used as test fixtures.
#
# Only the JSON (skeleton + atlas) is fetched by default: the geometry oracle
# never opens the atlas image, it reads regions and names straight out of the
# tex JSON. Pass --with-images to also fetch the 11 MB of atlases, which the
# Flutter render test needs if you want to rasterise these characters.
#
#   tool/ground_truth/fetch_fixtures.sh               # JSON only (committed)
#   tool/ground_truth/fetch_fixtures.sh --with-images # + atlases (gitignored)
#
# The revision is pinned so the fixtures cannot drift under us; bump
# DRAGONBONES_UNITY_SHA and regenerate tool/ground_truth/unity_fixtures.txt to
# move to a newer SDK snapshot.
set -euo pipefail
cd "$(dirname "$0")/../.."

SHA="${DRAGONBONES_UNITY_SHA:-45202d3a11ea537b120482e58eab7c1d404bc6a4}"
BASE="https://raw.githubusercontent.com/DragonBones/DragonBonesUnity/${SHA}/Assets/DragonBones/Demos/Resources"
LIST="tool/ground_truth/unity_fixtures.txt"
DEST="test/fixtures/unity"

WITH_IMAGES=0
for arg in "$@"; do
  case "$arg" in
    --with-images) WITH_IMAGES=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ ! -f "$LIST" ]; then
  echo "missing $LIST" >&2
  exit 2
fi

downloaded=0
skipped=0
failed=0

while IFS= read -r rel; do
  [ -n "$rel" ] || continue

  case "$rel" in
    *.png)
      if [ "$WITH_IMAGES" -eq 0 ]; then continue; fi
      ;;
  esac

  out="$DEST/$rel"
  if [ -s "$out" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  mkdir -p "$(dirname "$out")"
  if curl -fsSL --retry 3 --retry-delay 1 "$BASE/$rel" -o "$out.tmp"; then
    mv "$out.tmp" "$out"
    downloaded=$((downloaded + 1))
  else
    rm -f "$out.tmp"
    echo "FAILED: $rel" >&2
    failed=$((failed + 1))
  fi
done < "$LIST"

echo "fixtures: $downloaded downloaded, $skipped already present, $failed failed"
if [ "$failed" -ne 0 ]; then
  exit 1
fi

if [ "$WITH_IMAGES" -eq 0 ]; then
  echo "(atlas images skipped — pass --with-images to fetch them)"
fi
