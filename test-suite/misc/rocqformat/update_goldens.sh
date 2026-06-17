#!/bin/sh
# Regenerate expected.v golden files from input.v for all cases.
# Run from the repository root after building rocqformat.

set -e

ROCQFORMAT="${ROCQFORMAT:-_build/default/rocqformat/main.exe}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$ROCQFORMAT" ]; then
  echo "rocqformat not found at $ROCQFORMAT"
  exit 1
fi

update_dir() {
  dir="$1"
  format_args="$2"
  extra=""
  [ -f "$dir/args" ] && extra=$(cat "$dir/args")
  echo "Updating $dir"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args $extra "$dir/input.v" > "$dir/expected.v"
}

for dir in "$ROOT"/cases/*/; do
  [ -d "$dir" ] || continue
  case "$(basename "$dir")" in
    _cli) continue ;;
  esac
  update_dir "$dir" "-q -boot -noinit"
done

if [ -d "$ROOT/cases_prelude" ]; then
  echo "Note: prelude cases use smoke tests (no golden files)."
  echo "Optional: add expected.v manually and switch to golden tests."
fi

echo "Golden files updated."
