# Shared helpers for rocqformat bulk corpus tests.
# shellcheck shell=sh

bulk_repo_root() {
  # test-suite/misc/rocqformat -> repository root
  CDPATH= cd "$(dirname "$0")/../../.." && pwd
}

bulk_bin_dir() {
  CDPATH= cd "$(dirname "$1")" && pwd
}

bulk_same_prefix() {
  [ "$(bulk_bin_dir "$1")" = "$(bulk_bin_dir "$2")" ]
}

bulk_install_prefix() {
  bin_dir=$1
  CDPATH= cd "$bin_dir/.." && pwd
}

bulk_resolve_tools() {
  if [ -n "${BIN:-}" ] && [ -x "${BIN}/rocq" ] && [ -x "${BIN}/rocqformat" ]; then
    ROCQFORMAT="${BIN}rocqformat"
    COQC="${BIN}rocq c"
    BULK_BIN_DIR=$(bulk_bin_dir "${BIN}rocq")
    return 0
  fi

  install_bin="$REPO_ROOT/_build/install/default/bin"
  if [ -x "$install_bin/rocq" ] && [ -x "$install_bin/rocqformat" ]; then
    BIN="$install_bin/"
    ROCQFORMAT="$install_bin/rocqformat"
    COQC="$install_bin/rocq c"
    BULK_BIN_DIR=$install_bin
    return 0
  fi

  if [ -n "${ROCQFORMAT:-}" ] && [ -x "${ROCQFORMAT}" ]; then
    paired_rocq="$(bulk_bin_dir "$ROCQFORMAT")/rocq"
    if [ -x "$paired_rocq" ]; then
      COQC="$paired_rocq c"
      BULK_BIN_DIR=$(bulk_bin_dir "$ROCQFORMAT")
      return 0
    fi
  fi

  if command -v rocqformat >/dev/null 2>&1 && command -v rocq >/dev/null 2>&1; then
    ROCQFORMAT=$(command -v rocqformat)
    rocq_bin=$(command -v rocq)
    if bulk_same_prefix "$ROCQFORMAT" "$rocq_bin"; then
      COQC="$rocq_bin c"
      BULK_BIN_DIR=$(bulk_bin_dir "$rocq_bin")
      return 0
    fi
    echo "rocqformat bulk: rocqformat and rocq are from different install prefixes"
    echo "rocqformat bulk: build with: dune build -p rocq-runtime,rocq-core,rocqformat"
    return 1
  fi

  echo "rocqformat bulk: paired rocqformat/rocq not found"
  echo "rocqformat bulk: build with: dune build -p rocq-runtime,rocq-core,rocqformat"
  return 1
}

bulk_find_coqlib() {
  for cand in \
    "${ROCQLIB:-}" \
    "$REPO_ROOT/_build/install/default/lib/coq" \
    "${BULK_BIN_DIR:+$(bulk_install_prefix "$BULK_BIN_DIR")/lib/coq}"
  do
    if [ -n "$cand" ] && [ -f "$cand/theories/Init/Prelude.vo" ]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

bulk_find_runtime_lib() {
  for cand in \
    "${ROCQRUNTIMELIB:-}" \
    "$REPO_ROOT/_build/install/default/lib/rocq-runtime" \
    "${BULK_BIN_DIR:+$(bulk_install_prefix "$BULK_BIN_DIR")/lib/rocq-runtime}"
  do
    if [ -n "$cand" ] && [ -d "$cand/plugins" ]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
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
  if [ -n "${BULK_BIN_DIR:-}" ]; then
  cand="$(bulk_install_prefix "$BULK_BIN_DIR")/lib/rocq-core/theories"
    if [ -f "$cand/Corelib/Init/Prelude.vo" ]; then
      printf '%s' "$cand"
      return 0
    fi
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
  coqlib=$1
  printf '%s' "-q -coqlib $coqlib -R $REPO_ROOT/theories/Corelib Corelib -Q $REPO_ROOT/theories/Ltac2 Ltac2"
}

bulk_corelib_compile_args() {
  coqlib=$1
  vo_root=$2
  printf '%s' "-q -coqlib $coqlib -R $vo_root/Corelib Corelib -Q $vo_root/Ltac2 Ltac2"
}

bulk_stdlib_format_args() {
  coqlib=$1
  stdlib_src=$2
  printf '%s' "-q -coqlib $coqlib -R $REPO_ROOT/theories/Corelib Corelib -Q $REPO_ROOT/theories/Ltac2 Ltac2 -Q $stdlib_src Stdlib"
}

bulk_stdlib_compile_args() {
  coqlib=$1
  corelib_vo=$2
  stdlib_vo=$3
  printf '%s' "-q -coqlib $coqlib -R $corelib_vo/Corelib Corelib -Q $corelib_vo/Ltac2 Ltac2 -Q $stdlib_vo Stdlib"
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
  work_base="${work_file%.v}"
  work_orig="${work_base}.orig.v"
  work_fmt="${work_base}.fmt.v"
  work_fmt2="${work_base}.fmt2.v"
  mkdir -p "$(dirname "$work_file")"
  cp "$src" "$work_file"
  cp "$work_file" "$work_orig"

  # shellcheck disable=SC2086
  if ! $COQC $compile_args "$work_file" >/dev/null 2>&1; then
    echo "rocqformat bulk: SKIP $corpus/$rel (does not compile in isolation)"
    BULK_SKIPPED=$((BULK_SKIPPED + 1))
    return 0
  fi

  # shellcheck disable=SC2086
  if ! $ROCQFORMAT $format_args "$work_file" > "$work_fmt"; then
    echo "rocqformat bulk: formatting failed: $corpus/$rel"
    BULK_FAILED=$((BULK_FAILED + 1))
    return 1
  fi

  # Compile formatted output under the original module name (basename).
  cp "$work_fmt" "$work_file"
  # shellcheck disable=SC2086
  if ! $COQC $compile_args "$work_file" >/dev/null 2>&1; then
    echo "rocqformat bulk: formatted file does not compile: $corpus/$rel"
    BULK_FAILED=$((BULK_FAILED + 1))
    return 1
  fi

  # shellcheck disable=SC2086
  if ! $ROCQFORMAT $format_args "$work_file" > "$work_fmt2"; then
    echo "rocqformat bulk: second format pass failed: $corpus/$rel"
    BULK_FAILED=$((BULK_FAILED + 1))
    return 1
  fi
  bulk_diff "$work_fmt" "$work_fmt2"
  # shellcheck disable=SC2086
  $ROCQFORMAT $format_args --check "$work_file"

  if ! cmp -s "$work_orig" "$work_fmt" >/dev/null 2>&1; then
    BULK_CHANGED=$((BULK_CHANGED + 1))
  else
    BULK_UNCHANGED=$((BULK_UNCHANGED + 1))
  fi

  # shellcheck disable=SC2086
  if ! $COQC $compile_args "$work_file" >/dev/null 2>&1; then
    echo "rocqformat bulk: formatted file does not compile after idempotency: $corpus/$rel"
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
