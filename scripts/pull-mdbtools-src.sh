#!/usr/bin/env sh
set -eu

# Pull a tagged mdbtools source tarball and unpack it into src/mdbtools.
VERSION="${1:-1.0.1}"
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
TARGET_DIR="$SRC_DIR/mdbtools"
PATCH_DIR="$ROOT_DIR/scripts/vendor-patches"
URL_RELEASE="https://github.com/mdbtools/mdbtools/releases/download/v${VERSION}/mdbtools-${VERSION}.tar.gz"
URL_GH_ARCHIVE="https://github.com/mdbtools/mdbtools/archive/refs/tags/v${VERSION}.tar.gz"
TESTDATA_URL="https://github.com/mdbtools/mdbtestdata/archive/refs/heads/master.tar.gz"
TESTDATA_DIR="$ROOT_DIR/tests/testthat/mdbtestdata"

mkdir -p "$SRC_DIR"

fetch() {
  tarball_path="$1"
  url="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fL "$url" -o "$tarball_path"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -O "$tarball_path" "$url"
    return 0
  fi

  echo "ERROR: neither curl nor wget is available" >&2
  return 1
}

prune_non_build_files() {
  # Remove non-build and CI/documentation assets from vendored source.
  rm -rf "$TARGET_DIR/.github"
  rm -rf "$TARGET_DIR/api_docx"

  rm -f "$TARGET_DIR/.gitignore"
  rm -f "$TARGET_DIR/.gitlab-ci.yml"
  rm -f "$TARGET_DIR/appveyor.yml"
  rm -f "$TARGET_DIR/AUTHORS"
  rm -f "$TARGET_DIR/HACKING"
  rm -f "$TARGET_DIR/HACKING.md"
  rm -f "$TARGET_DIR/INSTALL"
  rm -f "$TARGET_DIR/NEWS"
  rm -f "$TARGET_DIR/README.md"
  rm -f "$TARGET_DIR/TODO.md"
  rm -f "$TARGET_DIR/test_script.sh"
  rm -f "$TARGET_DIR/test_sql.sh"
  # Remove autotools root files. Only COPYING and COPYING.LIB are kept.
  rm -f "$TARGET_DIR/aclocal.m4"
  rm -f "$TARGET_DIR/configure"
  rm -f "$TARGET_DIR/configure.ac"
  rm -f "$TARGET_DIR/Makefile.am"
  rm -f "$TARGET_DIR/Makefile.in"
  rm -f "$TARGET_DIR/libmdb.pc.in"
  rm -f "$TARGET_DIR/libmdbsql.pc.in"
  # Remove autotools infrastructure not needed for R's src/Makevars build.
  rm -rf "$TARGET_DIR/m4"
  rm -rf "$TARGET_DIR/build-aux"
  rm -rf "$TARGET_DIR/doc"

  # Remove autotools template/backup files from include/; only the
  # generated .h headers are needed at compile time.
  rm -f "$TARGET_DIR/include/Makefile.am"
  rm -f "$TARGET_DIR/include/Makefile.in"
  rm -f "$TARGET_DIR/include/mdbtools.h.in"
  rm -f "$TARGET_DIR/include/mdbver.h.in"

  # Remove source subtrees that are not compiled by src/Makevars.
  # Only libmdb and sql are built; odbc requires unixODBC, fuzz requires
  # a fuzzing engine, and util contains standalone CLI binaries -- none
  # of these are relevant to the R package.
  rm -rf "$TARGET_DIR/src/odbc"
  rm -rf "$TARGET_DIR/src/fuzz"
  rm -rf "$TARGET_DIR/src/util"
  rm -rf "$TARGET_DIR/src/extras"
}

apply_vendor_diff_patches() {
  if [ ! -d "$PATCH_DIR" ]; then
    return 0
  fi

  patch_cmd=""
  if command -v patch >/dev/null 2>&1; then
    patch_cmd="patch"
  elif command -v git >/dev/null 2>&1; then
    patch_cmd="git-apply"
  else
    echo "ERROR: vendor patches require either 'patch' or 'git'" >&2
    return 1
  fi

  for patch_file in "$PATCH_DIR"/*.patch; do
    if [ ! -e "$patch_file" ]; then
      continue
    fi

    patch_name="$(basename "$patch_file")"
    echo "[mdbr] Applying vendor patch ${patch_name}"

    if [ "$patch_cmd" = "patch" ]; then
      if patch --dry-run -p1 -d "$TARGET_DIR" < "$patch_file" >/dev/null 2>&1; then
        patch -p1 -d "$TARGET_DIR" < "$patch_file"
        continue
      fi

      if patch --dry-run -R -p1 -d "$TARGET_DIR" < "$patch_file" >/dev/null 2>&1; then
        echo "[mdbr] Patch ${patch_name} already present upstream; skipping"
        continue
      fi
    else
      git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || git_root="$ROOT_DIR"
      rel_target_dir="${TARGET_DIR#"${git_root}/"}"
      if git apply --check --directory="$rel_target_dir" "$patch_file" >/dev/null 2>&1; then
        git apply --directory="$rel_target_dir" "$patch_file"
        continue
      fi

      if git apply --reverse --check --directory="$rel_target_dir" "$patch_file" >/dev/null 2>&1; then
        echo "[mdbr] Patch ${patch_name} already present upstream; skipping"
        continue
      fi
    fi

    echo "ERROR: failed to apply vendor patch ${patch_name}" >&2
    return 1
  done
}

apply_local_vendor_patches() {
  header="$TARGET_DIR/include/mdbtools.h"
  if [ ! -f "$header" ]; then
    return 0
  fi

  detect_header() {
    include_name="$1"
    compiler_bin="${CC:-cc}"
    probe_file="${TMPDIR:-/tmp}/mdbr-include-probe-$$.c"

    # Skip probing when no compiler is available; default to disabled in that case.
    if ! command -v "$compiler_bin" >/dev/null 2>&1; then
      return 1
    fi

    cat > "$probe_file" <<EOF
#include <${include_name}>
int main(void) { return 0; }
EOF

    if "$compiler_bin" -c "$probe_file" -o /dev/null >/dev/null 2>&1; then
      rm -f "$probe_file"
      return 0
    fi

    rm -f "$probe_file"
    return 1
  }

  if detect_header "iconv.h"; then
    iconv_value=1
  else
    iconv_value=0
  fi

  if detect_header "xlocale.h"; then
    xlocale_value=1
  else
    xlocale_value=0
  fi

  sed -i "s/^#define MDBTOOLS_H_HAVE_ICONV_H .*/#define MDBTOOLS_H_HAVE_ICONV_H ${iconv_value}/" "$header"
  sed -i "s/^#define MDBTOOLS_H_HAVE_XLOCALE_H .*/#define MDBTOOLS_H_HAVE_XLOCALE_H ${xlocale_value}/" "$header"

  if ! grep -q '^#if MDBTOOLS_H_HAVE_ICONV_H && !defined(HAVE_ICONV)$' "$header"; then
    awk '
      /^#if MDBTOOLS_H_HAVE_ICONV_H$/ {
        print;
        in_iconv_include=1;
        next;
      }
      in_iconv_include && /^#endif$/ {
        print;
        print "";
        print "/*";
        print " * Keep mdbtools feature flags consistent across build paths.";
        print " * The direct R Makevars path does not run autotools config headers,";
        print " * but iconv.c gates behavior on HAVE_ICONV.";
        print " */";
        print "#if MDBTOOLS_H_HAVE_ICONV_H && !defined(HAVE_ICONV)";
        print "#if !defined(_WIN32) && !defined(WIN32) && !defined(_WIN64) && !defined(WIN64) && !defined(WINDOWS)";
        print "#define HAVE_ICONV 1";
        print "#endif";
        print "#endif";
        print "";
        print "#if defined(HAVE_ICONV) && !defined(ICONV_CONST)";
        print "#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64) || defined(WINDOWS)";
        print "#define ICONV_CONST const";
        print "#else";
        print "#define ICONV_CONST";
        print "#endif";
        print "#endif";
        in_iconv_include=0;
        next;
      }
      { print }
    ' "$header" > "$header.tmp"
    mv "$header.tmp" "$header"
  fi

  if ! grep -q '^#ifndef TLS$' "$header"; then
    awk '
      /#define MDB_DEPRECATED\(type, funcname\) type __attribute__\(\(deprecated\)\) funcname/ {
        print;
        print "";
        print "#ifndef TLS";
        print "#define TLS";
        print "#endif";
        next;
      }
      { print }
    ' "$header" > "$header.tmp"
    mv "$header.tmp" "$header"
  fi

  # MinGW exposes _locale_t instead of locale_t.
  if grep -q '^typedef locale_t mdb_locale_t;$' "$header"; then
    awk '
      /^typedef locale_t mdb_locale_t;$/ {
        print "#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64) || defined(WINDOWS)";
        print "typedef _locale_t mdb_locale_t;";
        print "#else";
        print "typedef locale_t mdb_locale_t;";
        print "#endif";
        next;
      }
      { print }
    ' "$header" > "$header.tmp"
    mv "$header.tmp" "$header"
  fi

  if grep -q '^#if MDBTOOLS_H_HAVE_ICONV_H$' "$header"; then
    awk '
      /^\s*GHashTable \*backends;\s*$/ {
        print;
        in_mdbhandle_fields=1;
        next;
      }
      in_mdbhandle_fields && /^#if MDBTOOLS_H_HAVE_ICONV_H$/ {
        print "#if defined(HAVE_ICONV)";
        in_mdbhandle_fields=0;
        next;
      }
      { print }
    ' "$header" > "$header.tmp"
    mv "$header.tmp" "$header"
  fi
}

tmp_tarball="$(mktemp "${TMPDIR:-/tmp}/mdbr-mdbtools-${VERSION}-XXXXXX.tar.gz")"
tmp_testdata_tarball="$(mktemp "${TMPDIR:-/tmp}/mdbr-mdbtestdata-XXXXXX.tar.gz")"
tmp_extract="$(mktemp -d "${TMPDIR:-/tmp}/mdbr-src-XXXXXX")"
trap 'rm -rf "$tmp_extract"; rm -f "$tmp_tarball" "$tmp_testdata_tarball"' EXIT INT TERM

echo "[mdbr] Downloading mdbtools v${VERSION} release tarball"
if ! fetch "$tmp_tarball" "$URL_RELEASE"; then
  echo "[mdbr] Release tarball unavailable, falling back to GitHub archive"
  fetch "$tmp_tarball" "$URL_GH_ARCHIVE"
fi

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

tar -xzf "$tmp_tarball" -C "$tmp_extract"

src_unpacked="$(find "$tmp_extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [ -z "$src_unpacked" ] || [ ! -d "$src_unpacked" ]; then
  echo "ERROR: failed to unpack mdbtools sources" >&2
  exit 1
fi

cp -R "$src_unpacked"/. "$TARGET_DIR"/
prune_non_build_files
apply_vendor_diff_patches
apply_local_vendor_patches

if [ ! -x "$TARGET_DIR/configure" ]; then
  echo "ERROR: vendored source does not include configure; expected release tarball layout" >&2
  exit 1
fi

echo "[mdbr] Vendored mdbtools source refreshed in $TARGET_DIR"

echo "[mdbr] Downloading mdbtestdata fixtures"
fetch "$tmp_testdata_tarball" "$TESTDATA_URL"

test_extract="$tmp_extract/mdbtestdata"
mkdir -p "$test_extract"
tar -xzf "$tmp_testdata_tarball" -C "$test_extract"

testdata_unpacked="$(find "$test_extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [ -z "$testdata_unpacked" ] || [ ! -d "$testdata_unpacked/data" ]; then
  echo "ERROR: failed to unpack mdbtestdata" >&2
  exit 1
fi

rm -rf "$TESTDATA_DIR"
mkdir -p "$TESTDATA_DIR"
cp -R "$testdata_unpacked/data" "$TESTDATA_DIR"/
cp -R "$testdata_unpacked/sql" "$TESTDATA_DIR"/

echo "[mdbr] Test fixtures refreshed in $TESTDATA_DIR"
