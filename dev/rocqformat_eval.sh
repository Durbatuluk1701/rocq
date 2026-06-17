#!/usr/bin/env bash
# Evaluate rocqformat on Corelib/Stdlib corpora.
set -euo pipefail

REPO_ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
OUT_DIR="${ROCQFORMAT_EVAL_DIR:-/tmp/rocqformat_eval}"
ROCQFORMAT="${ROCQFORMAT:-$REPO_ROOT/_build/default/rocqformat/main.exe}"
export ROCQRUNTIMELIB="${ROCQRUNTIMELIB:-$REPO_ROOT/_build/default}"

BOOT_ARGS="-q -boot -noinit -R $REPO_ROOT/theories/Corelib Corelib -Q $REPO_ROOT/theories/Ltac2 Ltac2 --continue-on-error"
VO_ARGS="-q -boot -noinit -R $REPO_ROOT/_build/default/theories/Corelib Corelib -Q $REPO_ROOT/_build/default/theories/Ltac2 Ltac2 --continue-on-error"

mkdir -p "$OUT_DIR"/{diffs,errors}

has_require() {
  grep -q '^Require' "$1"
}

format_corpus() {
  local label=$1 src_root=$2 stdlib_mode=${3:-0}
  local summary="$OUT_DIR/${label}_summary.tsv"
  local changed="$OUT_DIR/${label}_changed.txt"
  local unchanged="$OUT_DIR/${label}_unchanged.txt"
  local skipped="$OUT_DIR/${label}_skipped.txt"
  local failed="$OUT_DIR/${label}_failed.txt"
  : >"$changed"; : >"$unchanged"; : >"$skipped"; : >"$failed"
  echo -e "rel\tstatus\tdiff_lines\tmode\tnote" >"$summary"

  while IFS= read -r src; do
    rel="${src#"$src_root"/}"
    safe="${rel//\//__}"
    args=$BOOT_ARGS
    mode=boot
    if has_require "$src"; then
      args=$VO_ARGS
      mode=vo
    fi
    if [ "$stdlib_mode" = 1 ]; then
      args="$args -Q $src_root Stdlib"
      if has_require "$src"; then
        mode=stdlib-vo
      else
        mode=stdlib-boot
      fi
    fi
    if ! $ROCQFORMAT $args "$src" >"$OUT_DIR/work_${safe}.fmt" 2>"$OUT_DIR/errors/${safe}.err"; then
      echo "$rel" >>"$failed"
      echo -e "$rel\tfailed\t0\t$mode\tformat error" >>"$summary"
      continue
    fi
    if cmp -s "$src" "$OUT_DIR/work_${safe}.fmt"; then
      echo "$rel" >>"$unchanged"
      echo -e "$rel\tunchanged\t0\t$mode\t" >>"$summary"
    else
      echo "$rel" >>"$changed"
      diff_lines=$(diff -u "$src" "$OUT_DIR/work_${safe}.fmt" 2>/dev/null | wc -l | tr -d ' ') || diff_lines=0
      diff -u "$src" "$OUT_DIR/work_${safe}.fmt" >"$OUT_DIR/diffs/${safe}.diff" || true
      echo -e "$rel\tchanged\t$diff_lines\t$mode\t" >>"$summary"
    fi
  done < <(find "$src_root" -type f -name '*.v' | sort)

  echo "=== $label ==="
  echo "changed=$(wc -l <"$changed") unchanged=$(wc -l <"$unchanged") failed=$(wc -l <"$failed")"
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"/{diffs,errors}
format_corpus corelib "$REPO_ROOT/theories/Corelib" 0

STDLIB_ROOT="${STDLIB_ROOT:-$REPO_ROOT/test-suite/misc/rocqformat/_stdlib/theories}"
if [ -d "$STDLIB_ROOT" ]; then
  format_corpus stdlib "$STDLIB_ROOT" 1
else
  echo "skip stdlib: $STDLIB_ROOT not found"
fi

echo "Report: $OUT_DIR"
