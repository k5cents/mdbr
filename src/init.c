#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP mdbr_list_tables(SEXP path_sexp, SEXP include_system_sexp);
SEXP mdbr_list_queries(SEXP path_sexp);
SEXP mdbr_list_objects(SEXP path_sexp, SEXP type_sexp);
SEXP mdbr_list_fields(SEXP path_sexp, SEXP table_sexp);
SEXP mdbr_table_num_rows(SEXP path_sexp, SEXP table_sexp);
SEXP mdbr_read_table(SEXP path_sexp, SEXP table_sexp);
SEXP mdbr_run_query(SEXP path_sexp, SEXP statement_sexp);
SEXP mdbr_get_query_sql(SEXP path_sexp, SEXP query_name_sexp);
SEXP mdbr_print_schema(SEXP path_sexp, SEXP table_sexp, SEXP backend_sexp, SEXP namespace_sexp, SEXP options_sexp);
SEXP mdbr_version(void);
SEXP mdbr_file_format(SEXP path_sexp);
SEXP mdbr_prop_dump(SEXP path_sexp, SEXP name_sexp, SEXP propcol_sexp);

static const R_CallMethodDef call_methods[] = {
  {"mdbr_list_tables", (DL_FUNC) &mdbr_list_tables, 2},
  {"mdbr_list_queries", (DL_FUNC) &mdbr_list_queries, 1},
  {"mdbr_list_objects", (DL_FUNC) &mdbr_list_objects, 2},
  {"mdbr_list_fields", (DL_FUNC) &mdbr_list_fields, 2},
  {"mdbr_table_num_rows", (DL_FUNC) &mdbr_table_num_rows, 2},
  {"mdbr_read_table", (DL_FUNC) &mdbr_read_table, 2},
  {"mdbr_run_query", (DL_FUNC) &mdbr_run_query, 2},
  {"mdbr_get_query_sql", (DL_FUNC) &mdbr_get_query_sql, 2},
  {"mdbr_print_schema", (DL_FUNC) &mdbr_print_schema, 5},
  {"mdbr_version", (DL_FUNC) &mdbr_version, 0},
  {"mdbr_file_format", (DL_FUNC) &mdbr_file_format, 1},
  {"mdbr_prop_dump", (DL_FUNC) &mdbr_prop_dump, 3},
  {NULL, NULL, 0}
};

void R_init_mdbr(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, TRUE);
}
