#include <R.h>
#include <Rinternals.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "mdbtools.h"
#include "mdbsql.h"
#include "mdbver.h"

static const char *scalar_char(SEXP x, const char *arg_name) {
  if (TYPEOF(x) != STRSXP || XLENGTH(x) != 1 || STRING_ELT(x, 0) == NA_STRING) {
    Rf_error("`%s` must be a single non-NA string.", arg_name);
  }
  return CHAR(STRING_ELT(x, 0));
}

static const char *optional_scalar_char(SEXP x, const char *arg_name) {
  if (x == R_NilValue) {
    return NULL;
  }
  if (TYPEOF(x) != STRSXP || XLENGTH(x) != 1 || STRING_ELT(x, 0) == NA_STRING) {
    Rf_error("`%s` must be NULL or a single non-NA string.", arg_name);
  }
  return CHAR(STRING_ELT(x, 0));
}

static int optional_scalar_int(SEXP x, const char *arg_name, int default_value) {
  if (x == R_NilValue) {
    return default_value;
  }
  if (TYPEOF(x) != INTSXP || XLENGTH(x) != 1 || INTEGER(x)[0] == NA_INTEGER) {
    Rf_error("`%s` must be NULL or a single non-NA integer.", arg_name);
  }
  return INTEGER(x)[0];
}

static void free_bind_buffers(char **values, int *lens, int ncol) {
  int i;
  if (values != NULL) {
    for (i = 0; i < ncol; i++) {
      free(values[i]);
    }
    free(values);
  }
  free(lens);
}

static int find_sql_column_type(MdbTableDef *table, const char *name) {
  unsigned int j;
  if (table == NULL || table->columns == NULL || name == NULL) {
    return NA_INTEGER;
  }

  for (j = 0; j < table->num_cols; j++) {
    MdbColumn *col = (MdbColumn *) g_ptr_array_index(table->columns, j);
    if (col != NULL && g_ascii_strcasecmp(col->name, name) == 0) {
      return col->col_type;
    }
  }

  return NA_INTEGER;
}

static void configure_r_read_formats(MdbHandle *mdb) {
  if (mdb == NULL) {
    return;
  }

  /* Force stable, locale-independent date rendering for R parsing. */
  mdb_set_date_fmt(mdb, "%Y-%m-%d %H:%M:%S");
  mdb_set_shortdate_fmt(mdb, "%Y-%m-%d");
}

static gchar *quote_schema_name_safe(MdbHandle *mdb, const char *dbnamespace, const char *name) {
  gchar *quoted = NULL;
  if (mdb == NULL || mdb->default_backend == NULL || name == NULL) {
    return NULL;
  }

  quoted = mdb->default_backend->quote_schema_name(dbnamespace, name);
  if (quoted == NULL) {
    return NULL;
  }
  return mdb_normalise_and_replace(mdb, &quoted);
}

typedef struct {
  SEXP names;
  SEXP vals;
  int idx;
} HashToVecCtx;

static void hash_to_vec_cb(gpointer key, gpointer value, gpointer data) {
  HashToVecCtx *ctx = (HashToVecCtx *) data;
  SET_STRING_ELT(ctx->names, ctx->idx, Rf_mkChar(key   ? (const char *) key   : ""));
  SET_STRING_ELT(ctx->vals,  ctx->idx, Rf_mkChar(value ? (const char *) value : ""));
  ctx->idx++;
}

static char *mdbr_get_query_id(MdbHandle *mdb, const char *query_name) {
  unsigned int i;
  MdbCatalogEntry *entry = NULL;
  MdbTableDef *table = NULL;
  size_t bind_size;
  char *id = NULL;
  char *name = NULL;

  if (mdb == NULL || query_name == NULL) {
    return NULL;
  }

  bind_size = mdb->bind_size;
  if (bind_size < 1024) {
    bind_size = 1024;
  }

  for (i = 0; i < mdb->num_catalog; i++) {
    entry = (MdbCatalogEntry *) g_ptr_array_index(mdb->catalog, i);
    if (entry != NULL && strcmp(entry->object_name, "MSysObjects") == 0) {
      break;
    }
  }

  if (entry == NULL || strcmp(entry->object_name, "MSysObjects") != 0) {
    return NULL;
  }

  table = mdb_read_table(entry);
  if (table == NULL || mdb_read_columns(table) == NULL) {
    if (table != NULL) {
      mdb_free_tabledef(table);
    }
    return NULL;
  }

  id = (char *) calloc(bind_size, sizeof(char));
  name = (char *) calloc(bind_size, sizeof(char));
  if (id == NULL || name == NULL) {
    free(id);
    free(name);
    mdb_free_tabledef(table);
    return NULL;
  }

  mdb_bind_column_by_name(table, "Id", id, NULL);
  mdb_bind_column_by_name(table, "Name", name, NULL);
  mdb_rewind_table(table);

  while (mdb_fetch_row(table)) {
    if (strcmp(query_name, name) == 0) {
      char *out = strdup(id);
      free(id);
      free(name);
      mdb_free_tabledef(table);
      return out;
    }
  }

  free(id);
  free(name);
  mdb_free_tabledef(table);
  return NULL;
}

static char *mdbr_build_query_sql(MdbHandle *mdb, const char *query_name) {
  unsigned int i;
  MdbCatalogEntry *entry = NULL;
  MdbCatalogEntry *sys_queries = NULL;
  MdbTableDef *table = NULL;
  char *query_id = NULL;
  size_t bind_size;
  char *attribute = NULL;
  char *expression = NULL;
  char *flag = NULL;
  char *name1 = NULL;
  char *objectid = NULL;
  char *order = NULL;
  GString *sql_tables = NULL;
  GString *sql_predicate = NULL;
  GString *sql_columns = NULL;
  GString *sql_where = NULL;
  GString *sql_sorting = NULL;
  char *final_sql = NULL;

  if (mdb == NULL || query_name == NULL) {
    return NULL;
  }

  bind_size = mdb->bind_size;
  if (bind_size < 1024) {
    bind_size = 1024;
  }

  for (i = 0; i < mdb->num_catalog; i++) {
    MdbCatalogEntry *temp = (MdbCatalogEntry *) g_ptr_array_index(mdb->catalog, i);
    if (temp == NULL) {
      continue;
    }
    if (strcmp(temp->object_name, query_name) == 0 && temp->object_type == MDB_QUERY) {
      entry = temp;
    } else if (strcmp(temp->object_name, "MSysQueries") == 0) {
      sys_queries = temp;
    }
  }

  if (entry == NULL || sys_queries == NULL) {
    return NULL;
  }

  query_id = mdbr_get_query_id(mdb, entry->object_name);
  if (query_id == NULL) {
    return NULL;
  }

  table = mdb_read_table(sys_queries);
  if (table == NULL || mdb_read_columns(table) == NULL) {
    free(query_id);
    if (table != NULL) {
      mdb_free_tabledef(table);
    }
    return NULL;
  }

  attribute = (char *) calloc(bind_size, sizeof(char));
  expression = (char *) calloc(bind_size, sizeof(char));
  flag = (char *) calloc(bind_size, sizeof(char));
  name1 = (char *) calloc(bind_size, sizeof(char));
  objectid = (char *) calloc(bind_size, sizeof(char));
  order = (char *) calloc(bind_size, sizeof(char));
  if (attribute == NULL || expression == NULL || flag == NULL || name1 == NULL ||
      objectid == NULL || order == NULL) {
    free(query_id);
    free(attribute);
    free(expression);
    free(flag);
    free(name1);
    free(objectid);
    free(order);
    mdb_free_tabledef(table);
    return NULL;
  }

  sql_tables = g_string_new("");
  sql_predicate = g_string_new("");
  sql_columns = g_string_new("");
  sql_where = g_string_new("");
  sql_sorting = g_string_new("");

  mdb_bind_column_by_name(table, "Attribute", attribute, NULL);
  mdb_bind_column_by_name(table, "Expression", expression, NULL);
  mdb_bind_column_by_name(table, "Flag", flag, NULL);
  mdb_bind_column_by_name(table, "Name1", name1, NULL);
  mdb_bind_column_by_name(table, "ObjectId", objectid, NULL);
  mdb_bind_column_by_name(table, "Order", order, NULL);

  mdb_rewind_table(table);
  while (mdb_fetch_row(table)) {
    if (strcmp(query_id, objectid) == 0) {
      int attr = atoi(attribute);
      int flagint = atoi(flag);
      switch (attr) {
      case 3:
        if (flagint & 0x30) {
          g_string_assign(sql_predicate, " TOP ");
          g_string_append(sql_predicate, name1);
          if (flagint & 0x20) {
            g_string_append(sql_predicate, " PERCENT");
          }
        } else if (flagint & 0x8) {
          g_string_assign(sql_predicate, " DISTINCTROW");
        } else if (flagint & 0x2) {
          g_string_assign(sql_predicate, " DISTINCT");
        }
        break;
      case 5:
        if (sql_tables->len > 0) {
          g_string_append(sql_tables, ",");
        }
        g_string_append(sql_tables, "[");
        g_string_append(sql_tables, name1);
        g_string_append(sql_tables, "]");
        break;
      case 6:
        if (sql_columns->len > 0) {
          g_string_append(sql_columns, ",");
        }
        g_string_append(sql_columns, expression);
        break;
      case 8:
        g_string_assign(sql_where, expression);
        break;
      case 11:
        if (sql_sorting->len == 0) {
          g_string_assign(sql_sorting, " ORDER BY ");
          g_string_append(sql_sorting, expression);
          if (strcmp(name1, "D") == 0) {
            g_string_append(sql_sorting, " DESCENDING");
          }
        }
        break;
      default:
        break;
      }
    }
  }

  if (sql_columns->len == 0 || sql_tables->len == 0) {
    /* Mirror mdb-queries utility behavior for query layouts that parse
       but do not yield table/column fragments in this reconstruction path. */
    final_sql = g_strdup("SELECT  FROM  ");
  } else if (sql_where->len == 0) {
    final_sql = g_strdup_printf(
      "SELECT%s %s FROM %s%s",
      sql_predicate->str,
      sql_columns->str,
      sql_tables->str,
      sql_sorting->str
    );
  } else {
    final_sql = g_strdup_printf(
      "SELECT%s %s FROM %s WHERE %s%s",
      sql_predicate->str,
      sql_columns->str,
      sql_tables->str,
      sql_where->str,
      sql_sorting->str
    );
  }

  g_string_free(sql_tables, TRUE);
  g_string_free(sql_predicate, TRUE);
  g_string_free(sql_columns, TRUE);
  g_string_free(sql_where, TRUE);
  g_string_free(sql_sorting, TRUE);
  free(query_id);
  free(attribute);
  free(expression);
  free(flag);
  free(name1);
  free(objectid);
  free(order);
  mdb_free_tabledef(table);

  return final_sql;
}

SEXP mdbr_list_queries(SEXP path_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  MdbHandle *mdb = NULL;
  GPtrArray *catalog = NULL;
  SEXP out = R_NilValue;
  int i;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  catalog = mdb_read_catalog(mdb, MDB_QUERY);
  if (catalog == NULL) {
    out = PROTECT(Rf_allocVector(STRSXP, 0));
    mdb_close(mdb);
    UNPROTECT(1);
    return out;
  }

  out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) catalog->len));
  for (i = 0; i < (int) catalog->len; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(catalog, i);
    SET_STRING_ELT(out, i, Rf_mkChar(entry->object_name));
  }

  mdb_close(mdb);
  UNPROTECT(1);
  return out;
}

/* mdbr_list_objects: list catalog entry names by type.
 *
 * obj_type_r values (R-side conventions):
 *   -1  all entries (MDB_ANY)
 *   -2  all non-system entries
 *   -3  system tables only  (MDB_TABLE + system flag)
 *    1  user tables only    (MDB_TABLE + !system flag)
 *   other >= 0  match entry->object_type directly (MDB_QUERY=5, MDB_FORM=0, etc.)
 */
SEXP mdbr_list_objects(SEXP path_sexp, SEXP type_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  int obj_type_r = asInteger(type_sexp);
  MdbHandle *mdb = NULL;
  SEXP out = R_NilValue;
  unsigned int i;
  int n, j;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  if (!mdb_read_catalog(mdb, MDB_ANY)) {
    out = PROTECT(Rf_allocVector(STRSXP, 0));
    mdb_close(mdb);
    UNPROTECT(1);
    return out;
  }

#define MATCHES_OBJ(entry) ( \
    (obj_type_r == -1) ? 1 : \
    (obj_type_r == -2) ? !mdb_is_system_table(entry) : \
    (obj_type_r == -3) ? mdb_is_system_table(entry) : \
    (obj_type_r ==  1) ? mdb_is_user_table(entry) : \
    ((int)(entry)->object_type == obj_type_r) )

  n = 0;
  for (i = 0; i < mdb->num_catalog; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(mdb->catalog, i);
    if (entry != NULL && MATCHES_OBJ(entry)) n++;
  }

  out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
  j = 0;
  for (i = 0; i < mdb->num_catalog; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(mdb->catalog, i);
    if (entry != NULL && MATCHES_OBJ(entry)) {
      SET_STRING_ELT(out, j++, Rf_mkChar(entry->object_name));
    }
  }

#undef MATCHES_OBJ

  mdb_close(mdb);
  UNPROTECT(1);
  return out;
}

SEXP mdbr_get_query_sql(SEXP path_sexp, SEXP query_name_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *query_name = scalar_char(query_name_sexp, "query_name");
  MdbHandle *mdb = NULL;
  char *query_sql = NULL;
  SEXP out = R_NilValue;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  mdb_set_bind_size(mdb, 200000);
  if (!mdb_read_catalog(mdb, MDB_ANY)) {
    mdb_close(mdb);
    Rf_error("Failed to read MDB/ACCDB catalog.");
  }

  query_sql = mdbr_build_query_sql(mdb, query_name);
  if (query_sql == NULL) {
    mdb_close(mdb);
    Rf_error("Query not found or unsupported query layout: %s", query_name);
  }

  out = PROTECT(Rf_mkString(query_sql));
  g_free(query_sql);
  mdb_close(mdb);
  UNPROTECT(1);
  return out;
}

SEXP mdbr_print_schema(SEXP path_sexp, SEXP table_sexp, SEXP backend_sexp, SEXP namespace_sexp, SEXP options_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *table_name = optional_scalar_char(table_sexp, "table");
  const char *backend_name = optional_scalar_char(backend_sexp, "backend");
  const char *dbnamespace = optional_scalar_char(namespace_sexp, "namespace");
  int export_options = optional_scalar_int(options_sexp, "export_options", MDB_SHEXP_DEFAULT);
  MdbHandle *mdb = NULL;
  SEXP out = R_NilValue;
  SEXP out_names = R_NilValue;
  unsigned int i;
  unsigned int j = 0;
  unsigned int n_match = 0;
  char charset_prefix[1024];
  charset_prefix[0] = '\0';

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  if (backend_name != NULL && !mdb_set_default_backend(mdb, backend_name)) {
    mdb_close(mdb);
    Rf_error("Unknown backend: %s", backend_name);
  }

  if (!mdb_read_catalog(mdb, MDB_TABLE)) {
    mdb_close(mdb);
    Rf_error("Failed to read catalog for schema export.");
  }

  export_options &= (int) mdb->default_backend->capabilities;

  {
    const char *charset = mdb_target_charset(mdb);
    if (charset != NULL && mdb->default_backend->charset_statement != NULL) {
      char buf[512];
      snprintf(buf, sizeof(buf), mdb->default_backend->charset_statement, charset);
      snprintf(charset_prefix, sizeof(charset_prefix), "%s\n", buf);
    }
  }

  /* First pass: count matching tables. */
  for (i = 0; i < mdb->num_catalog; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(mdb->catalog, i);
    if (entry == NULL || entry->object_type != MDB_TABLE) {
      continue;
    }
    if (table_name != NULL) {
      if (strcmp(entry->object_name, table_name) == 0) {
        n_match++;
      }
    } else if (mdb_is_user_table(entry)) {
      n_match++;
    }
  }

  if (table_name != NULL && n_match == 0) {
    mdb_close(mdb);
    Rf_error("Table not found for schema export: %s", table_name);
  }

  out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n_match));
  out_names = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n_match));

  /* Second pass: build one DDL string per matched table. */
  for (i = 0; i < mdb->num_catalog; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(mdb->catalog, i);
    MdbTableDef *table = NULL;
    gchar *quoted_table = NULL;
    GString *ddl = NULL;
    unsigned int k;

    if (entry == NULL || entry->object_type != MDB_TABLE) {
      continue;
    }

    if (table_name != NULL) {
      if (strcmp(entry->object_name, table_name) != 0) {
        continue;
      }
    } else if (!mdb_is_user_table(entry)) {
      continue;
    }

    quoted_table = quote_schema_name_safe(mdb, dbnamespace, entry->object_name);
    if (quoted_table == NULL) {
      continue;
    }

    ddl = g_string_new(charset_prefix);

    if ((export_options & MDB_SHEXP_DROPTABLE) && mdb->default_backend->drop_statement != NULL) {
      char buf[1024];
      snprintf(buf, sizeof(buf), mdb->default_backend->drop_statement, quoted_table);
      g_string_append(ddl, buf);
    }

    if (mdb->default_backend->create_table_statement != NULL) {
      char buf[1024];
      snprintf(buf, sizeof(buf), mdb->default_backend->create_table_statement, quoted_table);
      g_string_append(ddl, buf);
    } else {
      g_string_append(ddl, "CREATE TABLE ");
      g_string_append(ddl, quoted_table);
      g_string_append(ddl, "\n");
    }
    g_string_append(ddl, " (\n");

    table = mdb_read_table(entry);
    if (table == NULL || mdb_read_columns(table) == NULL) {
      g_free(quoted_table);
      g_string_free(ddl, TRUE);
      if (table != NULL) {
        mdb_free_tabledef(table);
      }
      continue;
    }

    for (k = 0; k < table->num_cols; k++) {
      MdbColumn *col = (MdbColumn *) g_ptr_array_index(table->columns, k);
      gchar *quoted_name = NULL;

      if (col == NULL) {
        continue;
      }

      quoted_name = quote_schema_name_safe(mdb, NULL, col->name);
      if (quoted_name == NULL) {
        continue;
      }

      g_string_append(ddl, "\t");
      g_string_append(ddl, quoted_name);
      g_string_append(ddl, "\t\t\t");
      g_string_append(ddl, mdb_get_colbacktype_string(col));

      if (mdb_colbacktype_takes_length(col)) {
        char len_buf[64];
        if (col->col_size == 0) {
          g_string_append(ddl, " (255)");
        } else if (col->col_scale != 0) {
          snprintf(len_buf, sizeof(len_buf), " (%d, %d)", col->col_scale, col->col_prec);
          g_string_append(ddl, len_buf);
        } else if (!IS_JET3(mdb) && col->col_type == MDB_TEXT) {
          snprintf(len_buf, sizeof(len_buf), " (%d)", col->col_size / 2);
          g_string_append(ddl, len_buf);
        } else {
          snprintf(len_buf, sizeof(len_buf), " (%d)", col->col_size);
          g_string_append(ddl, len_buf);
        }
      }

      if (export_options & MDB_SHEXP_CST_NOTNULL) {
        if (col->col_type == MDB_BOOL) {
          g_string_append(ddl, " NOT NULL");
        } else {
          const char *required = mdb_col_get_prop(col, "Required");
          if (required != NULL && required[0] == 'y') {
            g_string_append(ddl, " NOT NULL");
          }
        }
      }

      if (export_options & MDB_SHEXP_DEFVALUES) {
        const char *defval = mdb_col_get_prop(col, "DefaultValue");
        if (defval != NULL && defval[0] != '\0') {
          g_string_append(ddl, " DEFAULT ");
          g_string_append(ddl, defval);
        } else if (col->col_type == MDB_BOOL) {
          g_string_append(ddl, " DEFAULT FALSE");
        }
      }

      if (k + 1 < table->num_cols) {
        g_string_append(ddl, ",\n");
      } else {
        g_string_append(ddl, "\n");
      }

      g_free(quoted_name);
    }

    g_string_append(ddl, ");\n");

    if (export_options & MDB_SHEXP_INDEXES) {
      if (mdb_read_indices(table) != NULL && table->indices != NULL && table->indices->len > 0) {
        g_string_append(ddl, "\n-- CREATE INDEXES ...\n");
        for (k = 0; k < table->indices->len; k++) {
          MdbIndex *idx = (MdbIndex *) g_ptr_array_index(table->indices, k);
          GString *cols = g_string_new("");
          gchar *quoted_idx = NULL;
          unsigned int m;

          if (idx == NULL || idx->num_keys == 0) {
            g_string_free(cols, TRUE);
            continue;
          }

          for (m = 0; m < idx->num_keys; m++) {
            int col_num = idx->key_col_num[m];
            MdbColumn *col = NULL;
            gchar *quoted_col = NULL;
            if (col_num < 0 || col_num >= (int) table->num_cols) {
              continue;
            }
            col = (MdbColumn *) g_ptr_array_index(table->columns, (unsigned int) col_num);
            if (col == NULL) {
              continue;
            }
            quoted_col = quote_schema_name_safe(mdb, NULL, col->name);
            if (quoted_col == NULL) {
              continue;
            }
            if (cols->len > 0) {
              g_string_append(cols, ", ");
            }
            g_string_append(cols, quoted_col);
            g_free(quoted_col);
          }

          if (cols->len == 0) {
            g_string_free(cols, TRUE);
            continue;
          }

          quoted_idx = quote_schema_name_safe(mdb, NULL, idx->name);
          if (quoted_idx != NULL) {
            g_string_append(ddl, (idx->flags & MDB_IDX_UNIQUE) ? "CREATE UNIQUE INDEX " : "CREATE INDEX ");
            g_string_append(ddl, quoted_idx);
            g_string_append(ddl, " ON ");
            g_string_append(ddl, quoted_table);
            g_string_append(ddl, " (");
            g_string_append(ddl, cols->str);
            g_string_append(ddl, ");\n");
            g_free(quoted_idx);
          }

          g_string_free(cols, TRUE);
        }
      }
    }

    if (export_options & MDB_SHEXP_RELATIONS) {
      g_string_append(ddl, "-- CREATE Relationships ...\n");
      g_string_append(ddl, "-- relationships export is not yet implemented in mdbr library mode\n");
    }

    g_string_append(ddl, "\n");

    SET_STRING_ELT(out, (R_xlen_t) j, Rf_mkChar(ddl->str));
    SET_STRING_ELT(out_names, (R_xlen_t) j, Rf_mkChar(entry->object_name));
    j++;

    g_string_free(ddl, TRUE);
    mdb_free_tabledef(table);
    g_free(quoted_table);
  }

  Rf_setAttrib(out, R_NamesSymbol, out_names);
  UNPROTECT(1); /* out_names */
  mdb_close(mdb);
  UNPROTECT(1); /* out */
  return out;
}

SEXP mdbr_version(void) {
  return Rf_mkString(MDB_FULL_VERSION);
}

SEXP mdbr_file_format(SEXP path_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  MdbHandle *mdb = NULL;
  const char *fmt = "UNKNOWN";

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  switch (mdb->f->jet_version) {
  case MDB_VER_JET3:
    fmt = "JET3";
    break;
  case MDB_VER_JET4:
    fmt = "JET4";
    break;
  case MDB_VER_ACCDB_2007:
    fmt = "ACE12";
    break;
  case MDB_VER_ACCDB_2010:
    fmt = "ACE14";
    break;
  case MDB_VER_ACCDB_2013:
    fmt = "ACE15";
    break;
  case MDB_VER_ACCDB_2016:
    fmt = "ACE16";
    break;
  case MDB_VER_ACCDB_2019:
    fmt = "ACE19";
    break;
  default:
    fmt = "UNKNOWN";
    break;
  }

  mdb_close(mdb);
  return Rf_mkString(fmt);
}

SEXP mdbr_prop_dump(SEXP path_sexp, SEXP name_sexp, SEXP propcol_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *object_name = scalar_char(name_sexp, "name");
  const char *propcol = optional_scalar_char(propcol_sexp, "propcol");
  MdbHandle *mdb = NULL;
  MdbTableDef *table = NULL;
  char *name_buf = NULL;
  char *prop_buf = NULL;
  int col_num;
  int found = 0;
  MdbColumn *col = NULL;
  void *kkd = NULL;
  size_t kkd_size = 0;
  GPtrArray *aprops = NULL;
  guint i;
  SEXP res = R_NilValue;

  if (propcol == NULL || !propcol[0]) {
    propcol = "LvProp";
  }

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  table = mdb_read_table_by_name(mdb, "MSysObjects", MDB_ANY);
  if (table == NULL) {
    mdb_close(mdb);
    Rf_error("Failed to read MSysObjects for property dump.");
  }

  if (mdb_read_columns(table) == NULL) {
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Failed to read MSysObjects columns for property dump.");
  }

  name_buf = (char *) g_malloc0(mdb->bind_size);
  prop_buf = (char *) g_malloc0(mdb->bind_size);
  if (name_buf == NULL || prop_buf == NULL) {
    g_free(name_buf);
    g_free(prop_buf);
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Out of memory while preparing property dump.");
  }

  mdb_bind_column_by_name(table, "Name", name_buf, NULL);
  col_num = mdb_bind_column_by_name(table, (char *) propcol, prop_buf, NULL);
  if (col_num < 1) {
    g_free(name_buf);
    g_free(prop_buf);
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Column %s not found in MSysObjects.", propcol);
  }

  mdb_rewind_table(table);
  while (mdb_fetch_row(table)) {
    if (strcmp(name_buf, object_name) == 0) {
      found = 1;
      break;
    }
  }

  if (!found) {
    g_free(name_buf);
    g_free(prop_buf);
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Object %s not found in database file.", object_name);
  }

  col = (MdbColumn *) g_ptr_array_index(table->columns, (guint) (col_num - 1));
  kkd = mdb_ole_read_full(mdb, col, &kkd_size);
  if (kkd != NULL && kkd_size > 0) {
    aprops = mdb_kkd_to_props(mdb, kkd, kkd_size);
    if (aprops != NULL) {
      SEXP outer_names;
      res = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) aprops->len));
      outer_names = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) aprops->len));
      for (i = 0; i < aprops->len; ++i) {
        MdbProperties *props = (MdbProperties *) g_ptr_array_index(aprops, i);
        const char *entry_name = (props != NULL && props->name != NULL && props->name[0])
                                   ? props->name : "(none)";
        SET_STRING_ELT(outer_names, (R_xlen_t) i, Rf_mkChar(entry_name));
        if (props != NULL && props->hash != NULL) {
          guint sz = props->hash->array->len;
          SEXP inner_vec = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) sz));
          SEXP inner_names = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) sz));
          if (sz > 0) {
            HashToVecCtx hctx = { inner_names, inner_vec, 0 };
            g_hash_table_foreach(props->hash, hash_to_vec_cb, &hctx);
          }
          Rf_setAttrib(inner_vec, R_NamesSymbol, inner_names);
          SET_VECTOR_ELT(res, (R_xlen_t) i, inner_vec);
          UNPROTECT(2);
        } else {
          SET_VECTOR_ELT(res, (R_xlen_t) i, Rf_allocVector(STRSXP, 0));
        }
        if (props != NULL) {
          mdb_free_props(props);
        }
      }
      Rf_setAttrib(res, R_NamesSymbol, outer_names);
      UNPROTECT(1); /* outer_names */
      g_ptr_array_free(aprops, TRUE);
    }
  }

  if (res == R_NilValue) {
    res = PROTECT(Rf_allocVector(VECSXP, 0));
  }

  if (kkd != NULL) {
    free(kkd);
  }
  g_free(name_buf);
  g_free(prop_buf);
  mdb_free_tabledef(table);
  mdb_close(mdb);
  UNPROTECT(1); /* res */
  return res;
}

SEXP mdbr_list_tables(SEXP path_sexp, SEXP include_system_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  int include_system = asLogical(include_system_sexp);
  MdbHandle *mdb = NULL;
  GPtrArray *catalog = NULL;
  SEXP out = R_NilValue;
  int i;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }
  configure_r_read_formats(mdb);

  catalog = mdb_read_catalog(mdb, MDB_TABLE);
  if (catalog == NULL) {
    out = PROTECT(Rf_allocVector(STRSXP, 0));
    mdb_close(mdb);
    UNPROTECT(1);
    return out;
  }

  /* Count matching tables. */
  int n = 0;
  for (i = 0; i < (int) catalog->len; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(catalog, i);
    if (include_system ? mdb_is_system_table(entry) : mdb_is_user_table(entry)) n++;
  }

  out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
  int j = 0;
  for (i = 0; i < (int) catalog->len; i++) {
    MdbCatalogEntry *entry = (MdbCatalogEntry *) g_ptr_array_index(catalog, i);
    if (include_system ? mdb_is_system_table(entry) : mdb_is_user_table(entry)) {
      SET_STRING_ELT(out, j++, Rf_mkChar(entry->object_name));
    }
  }

  mdb_close(mdb);
  UNPROTECT(1);
  return out;
}

SEXP mdbr_list_fields(SEXP path_sexp, SEXP table_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *table_name = scalar_char(table_sexp, "table");
  MdbHandle *mdb = NULL;
  MdbTableDef *table = NULL;
  SEXP out = R_NilValue;
  int i;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }
  configure_r_read_formats(mdb);

  table = mdb_read_table_by_name(mdb, (char *) table_name, MDB_TABLE);
  if (table == NULL) {
    mdb_close(mdb);
    Rf_error("Table not found: %s", table_name);
  }

  if (mdb_read_columns(table) == NULL) {
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Failed to read columns for table: %s", table_name);
  }

  out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) table->num_cols));
  for (i = 0; i < (int) table->num_cols; i++) {
    MdbColumn *col = (MdbColumn *) g_ptr_array_index(table->columns, i);
    SET_STRING_ELT(out, i, Rf_mkChar(col->name));
  }

  mdb_free_tabledef(table);
  mdb_close(mdb);
  UNPROTECT(1);
  return out;
}

SEXP mdbr_table_num_rows(SEXP path_sexp, SEXP table_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *table_name = scalar_char(table_sexp, "table");
  MdbHandle *mdb = NULL;
  MdbTableDef *table = NULL;
  int nrows;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }

  table = mdb_read_table_by_name(mdb, (char *) table_name, MDB_TABLE);
  if (table == NULL) {
    mdb_close(mdb);
    Rf_error("Table not found: %s", table_name);
  }

  nrows = (int) table->num_rows;
  mdb_free_tabledef(table);
  mdb_close(mdb);
  return Rf_ScalarInteger(nrows);
}

SEXP mdbr_read_table(SEXP path_sexp, SEXP table_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *table_name = scalar_char(table_sexp, "table");
  const size_t bind_size = 65536;
  MdbHandle *mdb = NULL;
  MdbTableDef *table = NULL;
  char **bound_values = NULL;
  int *bound_lens = NULL;
  SEXP out = R_NilValue;
  SEXP names = R_NilValue;
  SEXP types = R_NilValue;
  int ncol;
  int i;
  int row;
  int nrow;

  mdb = mdb_open(path, MDB_NOFLAGS);
  if (mdb == NULL) {
    Rf_error("Failed to open MDB/ACCDB file: %s", path);
  }
  configure_r_read_formats(mdb);

  mdb_set_bind_size(mdb, bind_size);
  table = mdb_read_table_by_name(mdb, (char *) table_name, MDB_TABLE);
  if (table == NULL) {
    mdb_close(mdb);
    Rf_error("Table not found: %s", table_name);
  }

  if (mdb_read_columns(table) == NULL) {
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Failed to read columns for table: %s", table_name);
  }

  ncol = (int) table->num_cols;
  bound_values = (char **) calloc((size_t) ncol, sizeof(char *));
  bound_lens = (int *) calloc((size_t) ncol, sizeof(int));
  if (bound_values == NULL || bound_lens == NULL) {
    free_bind_buffers(bound_values, bound_lens, ncol);
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Out of memory while allocating bound column buffers.");
  }

  for (i = 0; i < ncol; i++) {
    int ret;
    bound_values[i] = (char *) calloc(bind_size, sizeof(char));
    if (bound_values[i] == NULL) {
      free_bind_buffers(bound_values, bound_lens, ncol);
      mdb_free_tabledef(table);
      mdb_close(mdb);
      Rf_error("Out of memory while allocating a column buffer.");
    }

    ret = mdb_bind_column(table, i + 1, bound_values[i], &bound_lens[i]);
    if (ret == -1) {
      free_bind_buffers(bound_values, bound_lens, ncol);
      mdb_free_tabledef(table);
      mdb_close(mdb);
      Rf_error("Failed to bind column %d in table '%s'.", i + 1, table_name);
    }
  }

  if (mdb_rewind_table(table) == -1) {
    free_bind_buffers(bound_values, bound_lens, ncol);
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Failed to rewind table '%s'.", table_name);
  }

  nrow = 0;
  while (mdb_fetch_row(table)) {
    nrow++;
  }

  if (mdb_rewind_table(table) == -1) {
    free_bind_buffers(bound_values, bound_lens, ncol);
    mdb_free_tabledef(table);
    mdb_close(mdb);
    Rf_error("Failed to rewind table '%s' for second pass.", table_name);
  }

  out = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) ncol));
  names = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) ncol));
  types = PROTECT(Rf_allocVector(INTSXP, (R_xlen_t) ncol));

  for (i = 0; i < ncol; i++) {
    MdbColumn *col = (MdbColumn *) g_ptr_array_index(table->columns, i);
    SEXP col_vec = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) nrow));
    SET_VECTOR_ELT(out, i, col_vec);
    UNPROTECT(1);
    SET_STRING_ELT(names, i, Rf_mkChar(col->name));
    INTEGER(types)[i] = col->col_type;
  }

  row = 0;
  while (mdb_fetch_row(table)) {
    for (i = 0; i < ncol; i++) {
      SEXP col_vec = VECTOR_ELT(out, i);
      if (bound_lens[i] == 0) {
        SET_STRING_ELT(col_vec, row, NA_STRING);
      } else {
        SET_STRING_ELT(col_vec, row, Rf_mkChar(bound_values[i]));
      }
    }
    row++;
  }

  Rf_setAttrib(out, R_NamesSymbol, names);
  Rf_setAttrib(out, Rf_install("mdb_col_types"), types);

  free_bind_buffers(bound_values, bound_lens, ncol);
  mdb_free_tabledef(table);
  mdb_close(mdb);
  UNPROTECT(3);
  return out;
}

SEXP mdbr_run_query(SEXP path_sexp, SEXP statement_sexp) {
  const char *path = scalar_char(path_sexp, "path");
  const char *statement = scalar_char(statement_sexp, "statement");
  const size_t bind_size = 65536;
  MdbSQL *sql = NULL;
  char *query = NULL;
  size_t query_len;
  SEXP out = R_NilValue;
  SEXP names = R_NilValue;
  SEXP types = R_NilValue;
  int ncol;
  int nrow;
  int i;
  int row;

  sql = mdb_sql_init();
  if (sql == NULL) {
    Rf_error("Failed to initialize SQL engine.");
  }

  query = strdup(statement);
  if (query == NULL) {
    mdb_sql_exit(sql);
    Rf_error("Out of memory while preparing SQL statement.");
  }

  query_len = strlen(query);
  while (query_len > 0 && (query[query_len - 1] == ' ' || query[query_len - 1] == '\t' ||
         query[query_len - 1] == '\r' || query[query_len - 1] == '\n')) {
    query[query_len - 1] = '\0';
    query_len--;
  }
  if (query_len > 0 && query[query_len - 1] == ';') {
    query[query_len - 1] = '\0';
    query_len--;
  }
  while (query_len > 0 && (query[query_len - 1] == ' ' || query[query_len - 1] == '\t' ||
         query[query_len - 1] == '\r' || query[query_len - 1] == '\n')) {
    query[query_len - 1] = '\0';
    query_len--;
  }

  if (query_len == 0) {
    free(query);
    mdb_sql_exit(sql);
    Rf_error("`statement` must not be empty.");
  }

  if (mdb_sql_open(sql, (char *) path) == NULL) {
    const char *err = mdb_sql_last_error(sql);
    char msg[1024];
    snprintf(msg, sizeof(msg), "Failed to open MDB/ACCDB file: %s", path);
    if (err != NULL && err[0] != '\0') {
      snprintf(msg, sizeof(msg), "%s", err);
    }
    mdb_sql_exit(sql);
    Rf_error("%s", msg);
  }

  configure_r_read_formats(sql->mdb);

  mdb_set_bind_size(sql->mdb, bind_size);

  if (mdb_sql_run_query(sql, query) == NULL || mdb_sql_has_error(sql)) {
    const char *err = mdb_sql_last_error(sql);
    if (err == NULL || err[0] == '\0') {
      err = "Failed to execute SQL query.";
    }
    free(query);
    mdb_sql_exit(sql);
    Rf_error("%s", err);
  }

  free(query);

  ncol = (int) sql->num_columns;
  if (ncol == 0) {
    mdb_sql_exit(sql);
    return Rf_allocVector(VECSXP, 0);
  }

  nrow = 0;
  while (mdb_sql_fetch_row(sql, sql->cur_table)) {
    nrow++;
  }

  if (mdb_rewind_table(sql->cur_table) == -1) {
    mdb_sql_exit(sql);
    Rf_error("Failed to rewind SQL result table.");
  }
  sql->row_count = 0;

  out = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) ncol));
  names = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) ncol));
  types = PROTECT(Rf_allocVector(INTSXP, (R_xlen_t) ncol));

  for (i = 0; i < ncol; i++) {
    MdbSQLColumn *sql_col = (MdbSQLColumn *) g_ptr_array_index(sql->columns, i);
    SEXP col_vec = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) nrow));
    SET_VECTOR_ELT(out, i, col_vec);
    UNPROTECT(1);
    SET_STRING_ELT(names, i, Rf_mkChar(sql_col->name));
    INTEGER(types)[i] = find_sql_column_type(sql->cur_table, sql_col->name);
  }

  row = 0;
  while (mdb_sql_fetch_row(sql, sql->cur_table)) {
    for (i = 0; i < ncol; i++) {
      SEXP col_vec = VECTOR_ELT(out, i);
      const char *value = (const char *) g_ptr_array_index(sql->bound_values, i);
      if (value == NULL) {
        SET_STRING_ELT(col_vec, row, NA_STRING);
      } else {
        SET_STRING_ELT(col_vec, row, Rf_mkChar(value));
      }
    }
    row++;
  }

  Rf_setAttrib(out, R_NamesSymbol, names);
  Rf_setAttrib(out, Rf_install("mdb_col_types"), types);
  mdb_sql_exit(sql);
  UNPROTECT(3);
  return out;
}
