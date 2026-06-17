#!/bin/sh
# Shallow-clone rocq-prover/stdlib for bulk formatter tests.
set -eu

DEST=${1:-$(CDPATH= cd "$(dirname "$0")" && pwd)/_stdlib}
REF=${STDLIB_REF:-master}
URL=${STDLIB_URL:-https://github.com/rocq-prover/stdlib.git}

if [ -d "$DEST/.git" ]; then
  echo "stdlib checkout already present at $DEST"
  exit 0
fi

echo "Cloning stdlib ($REF) into $DEST"
git clone --depth 1 --branch "$REF" "$URL" "$DEST"
