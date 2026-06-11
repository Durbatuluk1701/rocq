#!/bin/sh

set -ex

export COQBIN=${BIN:-}
export PATH="${BIN:+$BIN:}$PATH"

if [ -n "${ROCQFORMAT:-}" ] && [ -x "${ROCQFORMAT}" ]; then
  :
elif command -v rocqformat >/dev/null 2>&1; then
  ROCQFORMAT=rocqformat
elif [ -n "${BIN:-}" ] && [ -x "${BIN}/rocqformat" ]; then
  ROCQFORMAT="${BIN}/rocqformat"
elif [ -x "_build/default/rocqformat/main.exe" ]; then
  ROCQFORMAT="_build/default/rocqformat/main.exe"
elif [ -x "../_build/default/rocqformat/main.exe" ]; then
  ROCQFORMAT="../_build/default/rocqformat/main.exe"
else
  echo "rocqformat not found"
  exit 1
fi

if [ -n "${BIN:-}" ] && [ -x "${BIN}/rocq" ]; then
  COQC="${BIN}rocq c"
elif command -v rocq >/dev/null 2>&1; then
  COQC="rocq c"
elif [ -x "_build/install/default/bin/rocq" ]; then
  COQC="_build/install/default/bin/rocq c"
elif [ -x "../_build/install/default/bin/rocq" ]; then
  COQC="../_build/install/default/bin/rocq c"
else
  COQC=""
fi

diff() {
  command diff -a -u --strip-trailing-cr "$1" "$2"
}

prelude_available() {
  [ -n "$COQC" ] || return 1
  work="$1"
  mkdir -p "$work"
  printf 'From Stdlib Require Import Init.\n' > "$work/prelude_check.v"
  $COQC -q "$work/prelude_check.v" >/dev/null 2>&1
}

run_case_smoke() {
  case_dir="$1"
  format_args="$2"
  compile_args="$3"

  case_name=$(basename "$case_dir")
  extra_args=""
  if [ -f "$case_dir/args" ]; then
    extra_args=$(cat "$case_dir/args")
  fi

  workdir="$case_dir/_run"
  rm -rf "$workdir"
  mkdir -p "$workdir"
  cp "$case_dir/input.v" "$workdir/input.v"

  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/input.v" \
    > "$workdir/output.v"

  if [ -z "$COQC" ]; then
    echo "rocqformat: COQC not found, cannot compile $case_name"
    exit 1
  fi
  cp "$workdir/output.v" "$workdir/compile.v"
  # shellcheck disable=SC2086
  $COQC $compile_args "$workdir/compile.v"

  # Strict idempotency on formatted output (including a third pass).
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/output.v" \
    > "$workdir/output2.v"
  diff "$workdir/output.v" "$workdir/output2.v"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/output2.v" \
    > "$workdir/output3.v"
  diff "$workdir/output2.v" "$workdir/output3.v"

  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args --check "$workdir/output.v"
}

vo_basename() {
  base=$(basename "$1" .v)
  echo "${base}.vo"
}

# Compare logical content of two .glob files, ignoring source locations and
# the location-sensitive digest header.
compare_glob_semantics() {
  glob_a="$1"
  glob_b="$2"
  sed 's/[0-9]*:[0-9]*//g' "$glob_a" | tail -n +2 > "$workdir/glob_a.norm"
  sed 's/[0-9]*:[0-9]*//g' "$glob_b" | tail -n +2 > "$workdir/glob_b.norm"
  diff "$workdir/glob_a.norm" "$workdir/glob_b.norm"
}

run_case() {
  case_dir="$1"
  format_args="$2"
  compile_args="$3"
  compile_enabled="$4"

  case_name=$(basename "$case_dir")
  extra_args=""
  if [ -f "$case_dir/args" ]; then
    extra_args=$(cat "$case_dir/args")
  fi
  if [ -f "$case_dir/no_compile" ]; then
    compile_enabled=no
  fi

  workdir="$case_dir/_run"
  rm -rf "$workdir"
  mkdir -p "$workdir"
  cp "$case_dir/input.v" "$workdir/input.v"

  # Format unformatted input and compare to golden output.
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/input.v" \
    > "$workdir/output.v"
  diff "$case_dir/expected.v" "$workdir/output.v"

  # Formatted output must compile when compilation is enabled.
  if [ "$compile_enabled" = "yes" ]; then
    if [ -z "$COQC" ]; then
      echo "rocqformat: COQC not found, cannot compile $case_name"
      exit 1
    fi
    sem_dir="$workdir/semantic"
    rm -rf "$sem_dir"
    mkdir -p "$sem_dir"
    cp "$workdir/input.v" "$sem_dir/Invariance.v"
    # shellcheck disable=SC2086
    $COQC $compile_args "$sem_dir/Invariance.v"
    cp "$sem_dir/Invariance.glob" "$sem_dir/baseline.glob"
    cp "$workdir/output.v" "$sem_dir/Invariance.v"
    # shellcheck disable=SC2086
    $COQC $compile_args "$sem_dir/Invariance.v"
    compare_glob_semantics "$sem_dir/baseline.glob" "$sem_dir/Invariance.glob"
    cp "$workdir/output.v" "$workdir/compile.v"
    # shellcheck disable=SC2086
    $COQC $compile_args "$workdir/compile.v"
    # Formatting must not break an already-compiled file.
    cp "$workdir/compile.v" "$workdir/reformat.v"
    # shellcheck disable=SC2086
    $ROCQFORMAT $format_args $extra_args "$workdir/reformat.v" \
      > "$workdir/reformat.out"
    cp "$workdir/reformat.out" "$workdir/recompile.v"
    # shellcheck disable=SC2086
    $COQC $compile_args "$workdir/recompile.v"
  fi

  # Strict idempotency: f(f(x)) = f(x) and f(f(f(x))) = f(x).
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/output.v" \
    > "$workdir/output2.v"
  diff "$workdir/output.v" "$workdir/output2.v"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/output2.v" \
    > "$workdir/output3.v"
  diff "$workdir/output2.v" "$workdir/output3.v"

  # Formatting must be idempotent on the golden file.
  cp "$case_dir/expected.v" "$workdir/idempotent.v"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args --check "$workdir/idempotent.v"

  # Second pass must not change already formatted files.
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra_args "$workdir/idempotent.v" \
    > "$workdir/idempotent.out"
  diff "$case_dir/expected.v" "$workdir/idempotent.out"

  # --check must reject input that still needs formatting.
  if ! diff -q "$case_dir/input.v" "$case_dir/expected.v" >/dev/null 2>&1; then
    cp "$case_dir/input.v" "$workdir/check.v"
    # shellcheck disable=SC2086
    if $ROCQFORMAT $format_args $extra_args --check "$workdir/check.v" \
        >/dev/null 2>&1; then
      echo "rocqformat: expected --check to fail for $case_name"
      exit 1
    fi
  fi
}

cd misc/rocqformat/

BOOT_FORMAT_ARGS="-q -boot -noinit"
BOOT_COMPILE_ARGS="-q -boot -noinit"

for case_dir in cases/*/; do
  case_name=$(basename "$case_dir")
  case "$case_name" in
    _cli) continue ;;
  esac
  run_case "$case_dir" "$BOOT_FORMAT_ARGS" "$BOOT_COMPILE_ARGS" yes
done

# Prelude-backed cases (proofs, notations, stdlib). Require full Rocq install.
PRELUDE_WORK=cases_prelude/_prelude_check
if prelude_available "$PRELUDE_WORK"; then
  PRELUDE_FORMAT_ARGS="-q"
  PRELUDE_COMPILE_ARGS="-q"
  for case_dir in cases_prelude/*/; do
    [ -d "$case_dir" ] || continue
    case_name=$(basename "$case_dir")
    case "$case_name" in
      _*) continue ;;
    esac
    run_case_smoke "$case_dir" "$PRELUDE_FORMAT_ARGS" "$PRELUDE_COMPILE_ARGS"
  done
else
  echo "SKIP prelude cases (Rocq prelude not available in this environment)"
fi

# CLI integration: -o and -i.
cli_dir=cases/_cli
rm -rf "$cli_dir"
mkdir -p "$cli_dir"
cp cases/basic/input.v "$cli_dir/input.v"

$ROCQFORMAT $BOOT_FORMAT_ARGS -o "$cli_dir/output.v" "$cli_dir/input.v"
diff cases/basic/expected.v "$cli_dir/output.v"

cp cases/basic/input.v "$cli_dir/inplace.v"
$ROCQFORMAT $BOOT_FORMAT_ARGS -i "$cli_dir/inplace.v"
diff cases/basic/expected.v "$cli_dir/inplace.v"

# Negative test: --check must exit non-zero on badly formatted input.
printf 'Definition   x:=0.\n' > "$cli_dir/bad.v"
if $ROCQFORMAT $BOOT_FORMAT_ARGS --check "$cli_dir/bad.v" >/dev/null 2>&1; then
  echo "rocqformat: expected --check to fail on badly formatted file"
  exit 1
fi

# Partial formatting: without --continue-on-error, a file with a failing command
# must abort; with the flag, valid commands are still formatted.
partial_dir=cases/partial_format
if [ -d "$partial_dir" ]; then
  partial_work="$partial_dir/_partial_cli"
  rm -rf "$partial_work"
  mkdir -p "$partial_work"
  cp "$partial_dir/input.v" "$partial_work/input.v"
  if $ROCQFORMAT $BOOT_FORMAT_ARGS "$partial_work/input.v" \
      > "$partial_work/no_flag.out" 2>/dev/null; then
    echo "rocqformat: expected formatting to fail without --continue-on-error"
    exit 1
  fi
  # shellcheck disable=SC2086
  $ROCQFORMAT $BOOT_FORMAT_ARGS --continue-on-error "$partial_work/input.v" \
    > "$partial_work/with_flag.out"
  diff "$partial_dir/expected.v" "$partial_work/with_flag.out"
fi
