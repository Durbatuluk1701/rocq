#!/usr/bin/env bash
# CI entry point: build rocq-core + stdlib, then run rocqformat bulk tests.
set -euo pipefail

ci_dir="$(dirname "$0")"
. "${ci_dir}/ci-common.sh"

git_download stdlib

if [ "$DOWNLOAD_ONLY" ]; then exit 0; fi

(
  make dunestrap COQ_SPLIT=1 DUNESTRAPOPT="-p rocq-core"
  dune build -p rocq-runtime,rocq-core,rocqformat
  dune install -p rocq-runtime,rocq-core,rocqformat --prefix="$CI_INSTALL_DIR"
)

(
  cd "${CI_BUILD_DIR}/stdlib"
  dev/with-rocq-wrap.sh dune build --root . --only-packages=rocq-stdlib @install
  dev/with-rocq-wrap.sh dune install --root . rocq-stdlib --prefix="$CI_INSTALL_DIR"
)

export BIN="$CI_INSTALL_DIR/bin/"
export STDLIB_ROOT="${CI_BUILD_DIR}/stdlib"
export ROCQFORMAT="${BIN}rocqformat"
export ROCQFORMAT_BULK=1

(
  cd test-suite
  make misc/rocqformat_bulk.log
)
