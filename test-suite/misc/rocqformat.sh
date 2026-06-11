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

ROCQFORMAT_BASE_ARGS="-q -boot -noinit"

diff() {
  command diff -a -u --strip-trailing-cr "$1" "$2"
}

run_case() {
  case_dir="$1"
  case_name=$(basename "$case_dir")
  extra_args=""
  if [ -f "$case_dir/args" ]; then
    extra_args=$(cat "$case_dir/args")
  fi

  workdir="$case_dir/_run"
  rm -rf "$workdir"
  mkdir -p "$workdir"
  cp "$case_dir/input.v" "$workdir/input.v"

  # Format unformatted input and compare to golden output.
  # shellcheck disable=SC2086
  $ROCQFORMAT $ROCQFORMAT_BASE_ARGS $extra_args "$workdir/input.v" \
    > "$workdir/output.v"
  diff "$case_dir/expected.v" "$workdir/output.v"

  # Formatting must be idempotent on the golden file.
  cp "$case_dir/expected.v" "$workdir/idempotent.v"
  # shellcheck disable=SC2086
  $ROCQFORMAT $ROCQFORMAT_BASE_ARGS $extra_args --check "$workdir/idempotent.v"

  # Second pass must not change already formatted files.
  # shellcheck disable=SC2086
  $ROCQFORMAT $ROCQFORMAT_BASE_ARGS $extra_args "$workdir/idempotent.v" \
    > "$workdir/idempotent.out"
  diff "$case_dir/expected.v" "$workdir/idempotent.out"

  # --check must reject input that still needs formatting.
  if ! diff -q "$case_dir/input.v" "$case_dir/expected.v" >/dev/null 2>&1; then
    cp "$case_dir/input.v" "$workdir/check.v"
    # shellcheck disable=SC2086
    if $ROCQFORMAT $ROCQFORMAT_BASE_ARGS $extra_args --check "$workdir/check.v" \
        >/dev/null 2>&1; then
      echo "rocqformat: expected --check to fail for $case_name"
      exit 1
    fi
  fi
}

cd misc/rocqformat/

for case_dir in cases/*/; do
  case_name=$(basename "$case_dir")
  case "$case_name" in
    _cli) continue ;;
  esac
  run_case "$case_dir"
done

# CLI integration: -o and -i.
cli_dir=cases/_cli
rm -rf "$cli_dir"
mkdir -p "$cli_dir"
cp cases/basic/input.v "$cli_dir/input.v"

$ROCQFORMAT $ROCQFORMAT_BASE_ARGS -o "$cli_dir/output.v" "$cli_dir/input.v"
diff cases/basic/expected.v "$cli_dir/output.v"

cp cases/basic/input.v "$cli_dir/inplace.v"
$ROCQFORMAT $ROCQFORMAT_BASE_ARGS -i "$cli_dir/inplace.v"
diff cases/basic/expected.v "$cli_dir/inplace.v"
