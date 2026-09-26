#include <R.h>
#include <Rinternals.h>
#include <R_ext/Utils.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "mdbtools.h"

typedef struct {
  MdbHandle *mdb;
  MdbTableDef *table;
  int exhausted;
} MdbCursor;

static void cursor_release(MdbCursor *cursor) {
  if (!cursor) return;
  if (cursor->table) mdb_free_tabledef(cursor->table);
  if (cursor->mdb) mdb_close(cursor->mdb);
  free(cursor);
}

static void cursor_finalizer(SEXP ptr) {
  MdbCursor *cursor = R_ExternalPtrAddr(ptr);
  if (cursor) {
    R_ClearExternalPtr(ptr);
    cursor_release(cursor);
  }
}

typedef struct {
  SEXP path;
  SEXP name;
  SEXP ptr;
} OpenArgs;

static SEXP cursor_open_impl(void *data) {
  OpenArgs *args = data;
  SEXP path = args->path, name = args->name;
  MdbCursor *cursor;
  SEXP ptr;
  if (TYPEOF(path) != STRSXP || XLENGTH(path) != 1 || STRING_ELT(path, 0) == NA_STRING ||
      TYPEOF(name) != STRSXP || XLENGTH(name) != 1 || STRING_ELT(name, 0) == NA_STRING)
    Rf_error("`path` and `table` must be single non-missing strings.");
  cursor = calloc(1, sizeof(*cursor));
  if (!cursor) Rf_error("Out of memory opening cursor.");
  /* Register ownership before any operation that might raise an R error. */
  ptr = PROTECT(R_MakeExternalPtr(cursor, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ptr, cursor_finalizer, TRUE);
  args->ptr = ptr;
  cursor->mdb = mdb_open(CHAR(STRING_ELT(path, 0)), MDB_NOFLAGS);
  if (!cursor->mdb) Rf_error("Failed to open MDB/ACCDB file.");
  mdb_set_date_fmt(cursor->mdb, "%Y-%m-%d %H:%M:%S");
  mdb_set_shortdate_fmt(cursor->mdb, "%Y-%m-%d");
  cursor->table = mdb_read_table_by_name(cursor->mdb, (char *) CHAR(STRING_ELT(name, 0)), MDB_TABLE);
  if (!cursor->table) Rf_error("Table not found: %s", CHAR(STRING_ELT(name, 0)));
  if (!mdb_read_columns(cursor->table)) Rf_error("Failed to read table columns.");
  for (unsigned int i = 0; i < cursor->table->num_cols; i++) {
    MdbColumn *col = g_ptr_array_index(cursor->table->columns, i);
    if (col->col_type != MDB_BOOL && col->col_type != MDB_BINARY &&
        col->col_type != MDB_OLE && col->col_type != MDB_TEXT &&
        col->col_type != MDB_MEMO && col->col_type != MDB_BYTE &&
        col->col_type != MDB_INT && col->col_type != MDB_LONGINT &&
        col->col_type != MDB_MONEY && col->col_type != MDB_FLOAT &&
        col->col_type != MDB_DOUBLE && col->col_type != MDB_DATETIME &&
        col->col_type != MDB_NUMERIC && col->col_type != MDB_REPID &&
        col->col_type != MDB_COMPLEX)
      Rf_error("Unsupported Access column type %d (%s).", col->col_type, col->name);
  }
  if (mdb_rewind_table(cursor->table) == -1) Rf_error("Failed to rewind table.");
  UNPROTECT(1);
  return ptr;
}

static void open_cleanup(void *data, Rboolean jump) {
  OpenArgs *args = data;
  if (jump && args->ptr != R_NilValue) cursor_finalizer(args->ptr);
}

SEXP mdbr_cursor_open(SEXP path, SEXP name) {
  OpenArgs args = {path, name, R_NilValue};
  SEXP continuation = PROTECT(R_MakeUnwindCont());
  SEXP result = R_UnwindProtect(cursor_open_impl, &args, open_cleanup, &args, continuation);
  UNPROTECT(1);
  return result;
}

SEXP mdbr_cursor_close(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP) Rf_error("Invalid MDB cursor.");
  cursor_finalizer(ptr);
  return Rf_ScalarLogical(1);
}

SEXP mdbr_cursor_valid(SEXP ptr) {
  return Rf_ScalarLogical(TYPEOF(ptr) == EXTPTRSXP && R_ExternalPtrAddr(ptr) != NULL);
}

static SEXP blob_value(MdbCursor *cursor, MdbColumn *col) {
  unsigned char page[65536];
  unsigned char header[MDB_MEMO_OVERHEAD];
  unsigned char *old_bind = col->bind_ptr;
  size_t expected, pos = 0, length;
  SEXP value;
  unsigned long flags;
  if (col->cur_value_len < MDB_MEMO_OVERHEAD)
    Rf_error("Invalid OLE field header.");
  memcpy(header, cursor->mdb->pg_buf + col->cur_value_start, sizeof(header));
  flags = (unsigned long) mdb_get_int32(header, 0);
  expected = flags & 0x00ffffffUL;
  if (expected == 0) return Rf_allocVector(RAWSXP, 0);
  if ((flags & 0x80000000UL) && expected != (size_t)(col->cur_value_len - MDB_MEMO_OVERHEAD))
    Rf_error("Invalid inline OLE length.");
  if (!(flags & 0x80000000UL) && !(flags & 0x40000000UL) && (flags & 0xff000000UL))
    Rf_error("Unsupported OLE field flags.");
  value = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) expected));
  col->bind_ptr = page;
  length = mdb_ole_read(cursor->mdb, col, header, sizeof(page));
  while (length) {
    if (length > expected - pos) {
      col->bind_ptr = old_bind;
      Rf_error("OLE field exceeds declared size.");
    }
    memcpy(RAW(value) + pos, page, length);
    pos += length;
    if (pos == expected) break;
    length = mdb_ole_read_next(cursor->mdb, col, header);
  }
  col->bind_ptr = old_bind;
  if (pos != expected) Rf_error("Incomplete OLE field.");
  UNPROTECT(1);
  return value;
}

static SEXP cursor_cell(MdbCursor *cursor, MdbColumn *col) {
  char *text;
  size_t capacity;
  SEXP out;
  size_t old_size;
  if (col->cur_is_null && col->col_type != MDB_BOOL) return R_NilValue;
  if (col->col_type == MDB_OLE) {
    if (col->cur_value_len == 0) return Rf_allocVector(RAWSXP, 0);
    return blob_value(cursor, col);
  }
  if (col->col_type == MDB_BOOL)
    return Rf_ScalarString(Rf_mkChar(col->cur_is_null ? "0" : "1"));
  if (col->col_type == MDB_BINARY) {
    if (col->cur_value_len < 0) Rf_error("Invalid binary field length.");
    out = Rf_allocVector(RAWSXP, col->cur_value_len);
    if (col->cur_value_len) memcpy(RAW(out), cursor->mdb->pg_buf + col->cur_value_start, col->cur_value_len);
    return out;
  }
  if (col->cur_value_len == 0 && col->col_type == MDB_TEXT)
    return Rf_ScalarString(Rf_mkChar(""));
  if (col->col_type != MDB_TEXT && col->col_type != MDB_MEMO &&
      col->col_type != MDB_BYTE && col->col_type != MDB_INT &&
      col->col_type != MDB_LONGINT && col->col_type != MDB_MONEY &&
      col->col_type != MDB_FLOAT && col->col_type != MDB_DOUBLE &&
      col->col_type != MDB_DATETIME && col->col_type != MDB_NUMERIC &&
      col->col_type != MDB_REPID && col->col_type != MDB_COMPLEX)
    Rf_error("Unsupported Access column type %d (%s).", col->col_type, col->name);
  /* UTF-8 may require four bytes per stored byte; MEMO size is in its header. */
  if (col->cur_value_len < 0) Rf_error("Invalid field length.");
  capacity = (size_t) col->cur_value_len;
  if (col->col_type == MDB_MEMO) {
    if (capacity < MDB_MEMO_OVERHEAD) Rf_error("Invalid MEMO header.");
    unsigned long header = (unsigned long) mdb_get_int32(cursor->mdb->pg_buf, col->cur_value_start);
    if (!(header & 0x80000000UL) && !(header & 0x40000000UL) &&
        (header & 0xff000000UL)) Rf_error("Unsupported MEMO flags.");
    if (header & 0x80000000UL) capacity -= MDB_MEMO_OVERHEAD;
    else capacity = header & 0x00ffffffUL;
    if (capacity == 0) return Rf_ScalarString(Rf_mkChar(""));
  }
  if (capacity > (size_t)(INT_MAX - 1) / 4) Rf_error("Text field too large to convert.");
  capacity = capacity * 4 + 1;
  if (capacity < 256) capacity = 256;
  old_size = cursor->mdb->bind_size;
  cursor->mdb->bind_size = capacity;
  if (col->col_type == MDB_NUMERIC)
    text = mdb_numeric_to_string(cursor->mdb, col->cur_value_start,
                                 col->col_scale, col->col_prec);
  else
    text = mdb_col_to_string(cursor->mdb, cursor->mdb->pg_buf, col->cur_value_start,
                             col->col_type, col->cur_value_len);
  cursor->mdb->bind_size = old_size;
  if (!text) Rf_error("Failed to convert Access value.");
  if (strlen(text) >= capacity - 1) {
    g_free(text);
    Rf_error("Text field exceeds conversion buffer.");
  }
  out = Rf_ScalarString(Rf_mkCharCE(text, CE_UTF8));
  g_free(text);
  return out;
}

typedef struct {
  SEXP ptr;
  MdbCursor *cursor;
  int n;
} FetchArgs;

static SEXP cursor_fetch_impl(void *data) {
  FetchArgs *args = data;
  MdbCursor *cursor = args->cursor;
  int count = 0, i, ncol = cursor->table->num_cols;
  PROTECT_INDEX rows_index;
  SEXP out = PROTECT(Rf_allocVector(VECSXP, ncol));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, ncol));
  SEXP types = PROTECT(Rf_allocVector(INTSXP, ncol));
  int capacity = args->n < 64 ? args->n : 64;
  SEXP rows;
  PROTECT_WITH_INDEX(rows = Rf_allocVector(VECSXP, capacity), &rows_index);
  for (i = 0; i < ncol; i++) {
    MdbColumn *col = g_ptr_array_index(cursor->table->columns, i);
    SET_STRING_ELT(names, i, Rf_mkChar(col->name));
    INTEGER(types)[i] = col->col_type;
  }
  while (count < args->n && !cursor->exhausted) {
    SEXP row;
    if ((count & 63) == 0) R_CheckUserInterrupt();
    if (!mdb_fetch_row(cursor->table)) {
      cursor->exhausted = 1;
      break;
    }
    row = PROTECT(Rf_allocVector(VECSXP, ncol));
    for (i = 0; i < ncol; i++) {
      MdbColumn *col = g_ptr_array_index(cursor->table->columns, i);
      SEXP cell = PROTECT(cursor_cell(cursor, col));
      SET_VECTOR_ELT(row, i, cell);
      UNPROTECT(1);
    }
    if (count == capacity) {
      int next = capacity > args->n / 2 ? args->n : capacity * 2;
      SEXP grown = PROTECT(Rf_allocVector(VECSXP, next));
      for (i = 0; i < count; i++) SET_VECTOR_ELT(grown, i, VECTOR_ELT(rows, i));
      REPROTECT(rows = grown, rows_index);
      UNPROTECT(1);
      capacity = next;
    }
    SET_VECTOR_ELT(rows, count++, row);
    UNPROTECT(1);
  }
  for (i = 0; i < ncol; i++) {
    SEXP col = PROTECT(Rf_allocVector(VECSXP, count));
    int j;
    for (j = 0; j < count; j++) SET_VECTOR_ELT(col, j, VECTOR_ELT(VECTOR_ELT(rows, j), i));
    SET_VECTOR_ELT(out, i, col);
    UNPROTECT(1);
  }
  Rf_setAttrib(out, R_NamesSymbol, names);
  Rf_setAttrib(out, Rf_install("mdb_col_types"), types);
  Rf_setAttrib(out, Rf_install("mdb_exhausted"), Rf_ScalarLogical(cursor->exhausted));
  UNPROTECT(4);
  return out;
}

static void fetch_cleanup(void *data, Rboolean jump) {
  FetchArgs *args = data;
  if (jump) cursor_finalizer(args->ptr);
}

SEXP mdbr_cursor_fetch(SEXP ptr, SEXP n) {
  FetchArgs args;
  if (TYPEOF(ptr) != EXTPTRSXP || !R_ExternalPtrAddr(ptr)) Rf_error("MDB cursor is closed.");
  if (TYPEOF(n) != INTSXP || XLENGTH(n) != 1 || INTEGER(n)[0] < 0 || INTEGER(n)[0] == NA_INTEGER)
    Rf_error("`n` must be a non-negative integer.");
  args.ptr = ptr;
  args.cursor = R_ExternalPtrAddr(ptr);
  args.n = INTEGER(n)[0];
  SEXP continuation = PROTECT(R_MakeUnwindCont());
  SEXP result = R_UnwindProtect(cursor_fetch_impl, &args, fetch_cleanup, &args, continuation);
  UNPROTECT(1);
  return result;
}
