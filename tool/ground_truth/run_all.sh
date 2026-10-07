#!/usr/bin/env bash
# Regenera TODOS os gabaritos a partir dos assets de teste.
# Requer: node  (o runtime de referência é obtido por fetch_runtime.sh)
set -euo pipefail
cd "$(dirname "$0")/../.."

FIX=test/fixtures
OUT=tool/ground_truth/out
mkdir -p "$OUT"

for anim in stand walk jump fall; do
  node tool/ground_truth/dump.js "$FIX/Dragon_ske.json" "$FIX/Dragon_tex.json" \
    "$anim" "$OUT/Dragon_$anim.json"
done

# pose de repouso: sem play() -> valida hierarquia de ossos e composição de
# matriz SEM a camada de animação (checkpoint intermediário do port)
node tool/ground_truth/dump.js "$FIX/Dragon_ske.json" "$FIX/Dragon_tex.json" \
  - "$OUT/Dragon_rest.json"

# asset 龙 (chinês): 60 ossos, malhas deformáveis, IK
node tool/ground_truth/dump.js "$FIX/龙_ske.json" "$FIX/龙_tex.json" \
  stand "$OUT/Long_stand.json"

# mecha_1004d: quatro armatures num arquivo, três aninhadas em slots da primeira
node tool/ground_truth/dump.js example/assets/mecha_1004d/ske.json \
  example/assets/mecha_1004d/tex.json walk "$OUT/Mecha_walk.json"

echo
echo "gabaritos gerados em $OUT:"
ls -la "$OUT"
