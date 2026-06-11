#!/bin/sh

set -ex

export COQBIN=${BIN:-}
export PATH="${BIN:+$BIN:}$PATH"

if [ -n "${ROCQFORMAT:-}" ] && [ -x "${ROCQFORMAT}" ]; then
  :
elif command -v rocqformat >/dev/null 2>&1; then
  ROCQFORMAT=rocqformat
elif [ -x "${BIN}/rocqformat" ]; then
  ROCQFORMAT="${BIN}/rocqformat"
elif [ -x "_build/default/rocqformat/main.exe" ]; then
  ROCQFORMAT="_build/default/rocqformat/main.exe"
else
  echo "rocqformat not found"
  exit 1
fi

diff() {
  command diff -a -u --strip-trailing-cr "$1" "$2"
}

cd misc/rocqformat/
rm -rf _test
mkdir _test
cp test.v _test

cd _test

$ROCQFORMAT -q -boot -noinit test.v > test.formatted.real

diff ../test.formatted test.formatted.real

$ROCQFORMAT -q -boot -noinit --check test.v

cd ..
cp comments-unformatted.v _test/comments.v
cd _test

$ROCQFORMAT -q -boot -noinit comments.v > comments.formatted.real

diff ../comments.formatted comments.formatted.real

$ROCQFORMAT -q -boot -noinit --check ../comments.v
