#!/usr/bin/env bash
# Regenerates the animation-event reference dumps.
#
# Separate from run_all.sh on purpose: those are pose dumps (9 MB, committed) and
# nothing here may perturb them. These are event sequences — small, and covering
# every fixture rather than the hand-picked ladder, because start/loopComplete/
# complete fire for every animation there is.
#
# Requires: node  (the reference runtime is obtained by fetch_runtime.sh)
#           test/fixtures/unity/*  (fetch_fixtures.sh)
set -euo pipefail
cd "$(dirname "$0")/../.."

FIX=test/fixtures
OUT=tool/ground_truth/out
mkdir -p "$OUT"

# The three named fixtures, so the ladder assets are covered too.
node tool/ground_truth/dump_events.js "$FIX/Dragon_ske.json" "$FIX/Dragon_tex.json" \
  "$OUT/events__Dragon.json" Dragon >/dev/null
node tool/ground_truth/dump_events.js "$FIX/龙_ske.json" "$FIX/龙_tex.json" \
  "$OUT/events__Long.json" 龙 >/dev/null
node tool/ground_truth/dump_events.js example/assets/mecha_1004d/ske.json \
  example/assets/mecha_1004d/tex.json "$OUT/events__mecha_1004d.json" mecha_1004d >/dev/null

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
    out="$OUT/events__unity__${slug}.json"

    if node tool/ground_truth/dump_events.js "$ske" "$tex" "$out" "$id" >/dev/null 2>"$OUT/.err.tmp"; then
      swept=$((swept + 1))
    else
      failed=$((failed + 1))
      echo "EVENT DUMP FAILED: $id"
      sed 's/^/    /' "$OUT/.err.tmp" | head -4
    fi
  done < <(find "$FIX/unity" -name '*_ske.json' | sort)
  rm -f "$OUT/.err.tmp"
  echo "event sweep: $swept dumps written, $failed failed"
else
  echo "unity fixtures not present (run tool/ground_truth/fetch_fixtures.sh)"
fi

echo
echo "gabaritos de evento em $OUT:"
ls "$OUT" | grep -c '^events__' | sed 's/^/  arquivos: /'
