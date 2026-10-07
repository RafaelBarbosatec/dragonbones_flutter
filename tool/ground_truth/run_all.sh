#!/usr/bin/env bash
# Regenerates every reference dump from the test assets.
#
# Requires: node  (the reference runtime is obtained by fetch_runtime.sh)
#           test/fixtures/unity/*  (fetch_fixtures.sh)
#
# Every asset gets one dump, playing whichever animation it declares first
# (`auto`), so adding a fixture never means editing this script.
set -euo pipefail
cd "$(dirname "$0")/../.."

FIX=test/fixtures
OUT=tool/ground_truth/out
mkdir -p "$OUT"

# ---------------------------------------------------------------- named set
# Hand-picked ladder, dumped on every animation so the fine-grained checks have
# something stable to compare against frame by frame.
for anim in stand walk jump fall; do
  node tool/ground_truth/dump.js "$FIX/Dragon_ske.json" "$FIX/Dragon_tex.json" \
    "$anim" "$OUT/Dragon_$anim.json" Dragon
done

# rest pose: no play() -> validates the bone hierarchy and matrix composition
# WITHOUT the animation layer (an intermediate checkpoint for the port)
node tool/ground_truth/dump.js "$FIX/Dragon_ske.json" "$FIX/Dragon_tex.json" \
  - "$OUT/Dragon_rest.json" Dragon

# 龙 (Chinese): 60 bones, deformable meshes, FFD timelines, IK
node tool/ground_truth/dump.js "$FIX/龙_ske.json" "$FIX/龙_tex.json" \
  stand "$OUT/Long_stand.json" 龙

# mecha_1004d: four armatures in one file, three nested inside slots of the first
node tool/ground_truth/dump.js example/assets/mecha_1004d/ske.json \
  example/assets/mecha_1004d/tex.json walk "$OUT/Mecha_walk.json" mecha_1004d

# ------------------------------------------------------------ Unity SDK sweep
# Every demo asset from DragonBones/DragonBonesUnity, one dump each.
if [ -d "$FIX/unity" ]; then
  swept=0
  failed=0
  while IFS= read -r ske; do
    dir="$(dirname "$ske")"
    prefix="$(basename "$ske" _ske.json)"
    tex="$dir/${prefix}_tex.json"
    [ -f "$tex" ] || tex='-'

    id="${dir#$FIX/unity/}"
    slug="$(printf '%s' "$id" | sed 's|/|__|g')"
    out="$OUT/unity__${slug}.json"

    if node tool/ground_truth/dump.js "$ske" "$tex" auto "$out" "$id" >/dev/null 2>"$OUT/.err.tmp"; then
      swept=$((swept + 1))
    else
      failed=$((failed + 1))
      echo "DUMP FAILED: $id"
      sed 's/^/    /' "$OUT/.err.tmp" | head -4
    fi
  done < <(find "$FIX/unity" -name '*_ske.json' | sort)
  rm -f "$OUT/.err.tmp"
  echo "unity sweep: $swept dumps written, $failed failed"
else
  echo "unity fixtures not present (run tool/ground_truth/fetch_fixtures.sh)"
fi

echo
echo "gabaritos gerados em $OUT:"
ls "$OUT" | wc -l | sed 's/^/  arquivos: /'
