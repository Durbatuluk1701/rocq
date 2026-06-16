#!/bin/sh
# Bulk rocqformat tests over in-repo Corelib/Ltac2 and external Stdlib.
#
# For each .v file that compiles in isolation:
#   1. format -> idempotent output (--check passes)
#   2. formatted file still compiles
#
# Requires a built rocq-core (Prelude.vo on disk). Stdlib is optional;
# set STDLIB_ROOT or run misc/rocqformat/fetch_stdlib.sh first.
#
# Set ROCQFORMAT_BULK=1 to enable (opt-in for the main test-suite).
# Set ROCQFORMAT_BULK_SKIP=1 to force skip.

set -eu

if [ "${ROCQFORMAT_BULK_SKIP:-0}" = 1 ]; then
  echo "SKIP rocqformat bulk (ROCQFORMAT_BULK_SKIP=1)"
  exit 0
fi

if [ "${ROCQFORMAT_BULK:-0}" != 1 ]; then
  echo "SKIP rocqformat bulk (set ROCQFORMAT_BULK=1 to enable)"
  exit 0
fi

export COQBIN=${BIN:-}
export PATH="${BIN:+$BIN:}$PATH"

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=misc/rocqformat/bulk_common.sh
. "$SCRIPT_DIR/rocqformat/bulk_common.sh"

BULK_WORK="$SCRIPT_DIR/rocqformat/_bulk"
BULK_PASSED=0
BULK_FAILED=0
BULK_SKIPPED=0
BULK_CHANGED=0
BULK_UNCHANGED=0

bulk_resolve_tools || exit 1

if [ -z "$COQC" ]; then
  echo "SKIP rocqformat bulk (rocq not found)"
  exit 0
fi

VO_ROOT=$(bulk_find_vo_root) || {
  echo "SKIP rocqformat bulk (rocq-core not built; build with: dune build -p rocq-core)"
  exit 0
}

COQLIB=$(bulk_find_coqlib) || {
  echo "SKIP rocqformat bulk (coqlib not found; install with: dune build -p rocq-runtime,rocq-core,rocqformat)"
  exit 0
}

RUNTIME_LIB=$(bulk_find_runtime_lib) || {
  echo "SKIP rocqformat bulk (rocq-runtime not found; build with: dune build -p rocq-runtime)"
  exit 0
}
export ROCQRUNTIMELIB="$RUNTIME_LIB"

rm -rf "$BULK_WORK"
mkdir -p "$BULK_WORK"

FORMAT_CORELIB=$(bulk_corelib_format_args "$COQLIB")
COMPILE_CORELIB=$(bulk_corelib_compile_args "$COQLIB" "$VO_ROOT")

echo "rocqformat bulk: using vo root $VO_ROOT"
echo "rocqformat bulk: using coqlib $COQLIB"
echo "rocqformat bulk: using runtime $RUNTIME_LIB"

bulk_run_corpus corelib "$REPO_ROOT/theories/Corelib" Corelib \
  "$FORMAT_CORELIB" "$COMPILE_CORELIB"

bulk_run_corpus ltac2 "$REPO_ROOT/theories/Ltac2" Ltac2 \
  "$FORMAT_CORELIB" "$COMPILE_CORELIB"

# External Stdlib (rocq-prover/stdlib)
STDLIB_ROOT=${STDLIB_ROOT:-}
if [ -z "$STDLIB_ROOT" ] && [ -d "$SCRIPT_DIR/rocqformat/_stdlib/theories" ]; then
  STDLIB_ROOT="$SCRIPT_DIR/rocqformat/_stdlib"
fi
if [ -z "$STDLIB_ROOT" ] && [ "${ROCQFORMAT_BULK_FETCH_STDLIB:-0}" = 1 ]; then
  "$SCRIPT_DIR/rocqformat/fetch_stdlib.sh" "$SCRIPT_DIR/rocqformat/_stdlib"
  STDLIB_ROOT="$SCRIPT_DIR/rocqformat/_stdlib"
fi

if [ -n "$STDLIB_ROOT" ] && [ -d "$STDLIB_ROOT/theories" ]; then
  STDLIB_SRC="$STDLIB_ROOT/theories"
  STDLIB_VO=$(bulk_find_stdlib_vo_root "$STDLIB_ROOT") || STDLIB_VO=""
  if [ -z "$STDLIB_VO" ]; then
    echo "rocqformat bulk: stdlib sources at $STDLIB_ROOT but .vo files missing"
    echo "rocqformat bulk: build with: (cd $STDLIB_ROOT && dune build -p rocq-stdlib)"
    echo "SKIP stdlib corpus"
  else
    FORMAT_STDLIB=$(bulk_stdlib_format_args "$COQLIB" "$STDLIB_SRC")
    COMPILE_STDLIB=$(bulk_stdlib_compile_args "$COQLIB" "$VO_ROOT" "$STDLIB_VO")
    bulk_run_corpus stdlib "$STDLIB_SRC" Stdlib \
      "$FORMAT_STDLIB" "$COMPILE_STDLIB"
  fi
else
  echo "SKIP stdlib corpus (set STDLIB_ROOT or run misc/rocqformat/fetch_stdlib.sh)"
fi

echo "rocqformat bulk summary: passed=$BULK_PASSED failed=$BULK_FAILED skipped=$BULK_SKIPPED changed=$BULK_CHANGED unchanged=$BULK_UNCHANGED"

if [ "$BULK_FAILED" -gt 0 ]; then
  exit 1
fi

if [ "$BULK_PASSED" -eq 0 ]; then
  echo "rocqformat bulk: no files tested"
  exit 1
fi

# Formatter should be capable of improving at least some real-world files.
if [ "$BULK_CHANGED" -eq 0 ] && [ "$BULK_UNCHANGED" -gt 0 ]; then
  echo "rocqformat bulk: warning: formatter changed no files (corpus may already be canonical)"
fi

exit 0
