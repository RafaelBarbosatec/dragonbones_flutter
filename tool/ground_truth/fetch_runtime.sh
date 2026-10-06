#!/usr/bin/env bash
# Obtém o runtime OFICIAL do DragonBones (TypeScript) e compila para JS,
# produzindo tool/ground_truth/vendor/dragonBones.js — que é o gabarito usado
# para validar o port Dart.
#
# É o pacote `DragonBones/src/dragonBones/**` (núcleo puro, sem engine),
# compilado a partir do tsconfig.json que o próprio repositório oficial traz.
set -euo pipefail
cd "$(dirname "$0")"

VENDOR=vendor
SRC="$VENDOR/DragonBonesJS"
mkdir -p "$VENDOR"

if [ ! -d "$SRC" ]; then
  git clone --depth 1 https://github.com/DragonBones/DragonBonesJS.git "$SRC"
fi

cd "$SRC/DragonBones"
# O tsconfig oficial tem opções deprecadas no TS 5.x; compilamos ignorando os
# avisos (o output é gerado corretamente).
npx --yes -p typescript@5.4.5 tsc -p tsconfig.json --ignoreDeprecations 5.0 || true
test -f out/dragonBones.js || { echo "FALHOU: out/dragonBones.js não gerado"; exit 1; }

cp out/dragonBones.js "$OLDPWD/vendor/dragonBones.js"
cd "$OLDPWD"
echo "ok -> $(pwd)/vendor/dragonBones.js ($(wc -c < vendor/dragonBones.js) bytes)"
