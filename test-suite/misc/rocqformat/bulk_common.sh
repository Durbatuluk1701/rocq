# Shared helpers for rocqformat bulk corpus tests.
# shellcheck shell=sh

bulk_repo_root() {
  # test-suite/misc/rocqformat -> repository root
  CDPATH= cd "$(dirname "$0")/../../.." && pwd
}

bulk_resolve_tools() {
  if [ -n "${ROCQFORMAT:-}" ] && [ -x "${ROCQFORMAT}" ]; then
    :
  elif command -v rocqformat >/dev/null 2>&1; then
    ROCQFORMAT=rocqformat
  elif [ -n "${BIN:-}" ] && [ -x "${BIN}/rocqformat" ]; then
    ROCQFORMAT="${BIN}/rocqformat"
  elif [ -x "$REPO_ROOT/_build/default/rocqformat/main.exe" ]; then
    ROCQFORMAT="$REPO_ROOT/_build/default/rocqformat/main.exe"
  else
    echo "rocqformat bulk: rocqformat not found"
    return 1
  fi

  if [ -n "${BIN:-}" ] && [ -x "${BIN}/rocq" ]; then
    COQC="${BIN}rocq c"
  elif command -v rocq >/dev/null 2>&1; then
    COQC="rocq c"
  elif [ -x "$REPO_ROOT/_build/install/default/bin/rocq" ]; then
    COQC="$REPO_ROOT/_build/install/default/bin/rocq c"
  else
    COQC=""
  fi
}

bulk_find_vo_root() {
  for cand in \
    "$REPO_ROOT/_build/default/theories" \
    "$REPO_ROOT/_build/install/default/lib/rocq-core/theories"
  do
    if [ -f "$cand/Corelib/Init/Prelude.vo" ]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  if command -v rocq >/dev/null 2>&1; then
    rocq_where=$(rocq c -where 2>/dev/null | tail -1)
    for cand in \
      "$rocq_where/user-contrib" \
      "$rocq_where/../rocq-core/theories" \
      "$(dirname "$rocq_where")/rocq-core/theories"
    do
      if [ -f "$cand/Corelib/Init/Prelude.vo" ]; then
        printf '%s' "$cand"
        return 0
      fi
    done
  fi
  return 1
}

bulk_find_stdlib_vo_root() {
  stdlib_root=$1
  for cand in \
    "$stdlib_root/_build/default/theories" \
    "$stdlib_root/_build/install/default/lib/rocq-stdlib/theories"
  do
    if [ -f "$cand/Lists/List.vo" ] || [ -f "$cand/Arith/Nat.vo" ]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

bulk_corelib_format_args() {
  printf '%s' "-q -R $REPO_ROOT/theories/Corelib Corelib -Q $REPO_ROOT/theories/Ltac2 Ltac2"
}

bulk_corelib_compile_args() {
  vo_root=$1
  printf '%s' "-q -R $vo_root/Corelib Corelib -Q $vo_root/Ltac2 Ltac2"
}

bulk_stdlib_format_args() {
  stdlib_src=$1
  printf '%s' "-q -R $REPO_ROOT/theories/Corelib Corelib -Q $REPO_ROOT/theories/Ltac2 Ltac2 -Q $stdlib_src Stdlib"
}

bulk_stdlib_compile_args() {
  corelib_vo=$1
  stdlib_vo=$2
  printf '%s' "-q -R $corelib_vo/Corelib Corelib -Q $corelib_vo/Ltac2 Ltac2 -Q $stdlib_vo Stdlib"
}

bulk_diff() {
  command diff -a -u --strip-trailing-cr "$1" "$2"
}

# Test one .v file from a corpus.
# $1 = path relative to corpus root (e.g. Corelib/Init/Nat.v or Arith/Nat.v)
# $2 = absolute path to source file
# $3 = corpus label (corelib, ltac2, stdlib)
# $4 = format arguments
# $5 = compile arguments
bulk_test_file() {
  rel=$1
  src=$2
  corpus=$3
  format_args=$4
  compile_args=$5

  work_file="$BULK_WORK/$corpus/$rel"
  mkdir -p "$(dirname "$work_file")"
  cp "$src" "$work_file"

  # shellcheck disable=SC2086
  if ! $COQC $compile_args "$work_file" >/dev/null 2>&1; then
    echo "rocqformat bulk: SKIP $corpus/$rel (does not compile in isolation)"
    BULK_SKIPPED=$((BULK_SKIPPED + 1))
    return 0
  fi

  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args "$work_file" > "$work_file.formatted"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args "$work_file.formatted" > "$work_file.formatted2"
  bulk_diff "$work_file.formatted" "$work_file.formatted2"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args --check "$work_file.formatted"

  if ! cmp -s "$work_file" "$work_file.formatted" >/dev/null 2>&1; then
    BULK_CHANGED=$((BULK_CHANGED + 1))
  else
    BULK_UNCHANGED=$((BULK_UNCHANGED + 1))
  fi

  cp "$work_file.formatted" "$work_file"
  # shellcheck disable=SC2086
  if ! $COQC $compile_args "$work_file" >/dev/null 2>&1; then
    echo "rocqformat bulk: formatted file does not compile: $corpus/$rel"
    BULK_FAILED=$((BULK_FAILED + 1))
    return 1
  fi

  BULK_PASSED=$((BULK_PASSED + 1))
  return 0
}

bulk_run_corpus() {
  corpus=$1
  src_root=$2
  rel_prefix=$3
  format_args=$4
  compile_args=$5

  echo "rocqformat bulk: scanning $corpus under $src_root"
  # shellcheck disable=SC2044
  for src in $(find "$src_root" -type f -name '*.v' | sort); do
    rel=${src#"$src_root"/}
    if [ -n "$rel_prefix" ]; then
      rel="$rel_prefix/$rel"
    fi
  # shellcheck disable=SC2086
    bulk_test_file "$rel" "$src" "$corpus" "$format_args" "$compile_args" || return 1
  done
}
