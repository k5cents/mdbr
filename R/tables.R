#' List tables in a Microsoft Access database
#'
#' `mdb-tables` is a utility program distributed with MDB Tools.
#' It outputs the names of all user tables (or other object types) in an MDB
#' database file.
#'
#' @param file Path to the Microsoft Access file.
#' @param system Logical; include system (`MSys*`) tables. Equivalent to `-S`.
#' @param type Object type to list: `"table"` (default), `"query"`,
#'   `"systable"`, `"any"`, `"all"`, `"form"`, `"macro"`, `"report"`,
#'   `"linkedtable"`, `"module"`, `"relationship"`, or `"dbprop"`.
#'   Equivalent to `-t`.
#' @param show_type Logical; prefix each entry with its type. Equivalent to `-T`.
#' @return A character vector of object names.
#' @examples
#' db <- mdb_example()
#' mdb_tables(db)
#' mdb_tables(db, type = "query")
#' @export
mdb_tables <- function(
  file,
  system = FALSE,
  type = c(
    "table",
    "query",
    "systable",
    "any",
    "all",
    "form",
    "macro",
    "report",
    "linkedtable",
    "module",
    "relationship",
    "dbprop"
  ),
  show_type = FALSE
) {
  type <- match.arg(type)
  path <- .mdb_normalize_path(file)

  # Map R type names to C integer codes passed to mdbr_list_objects:
  #  1   = user tables (MDB_TABLE + !system flag)
  # -3   = system tables (MDB_TABLE + system flag)
  #  5   = queries    (MDB_QUERY)
  #  0   = forms      (MDB_FORM)
  #  2   = macros     (MDB_MACRO)
  #  4   = reports    (MDB_REPORT)
  #  6   = linked tables (MDB_LINKED_TABLE)
  #  7   = modules    (MDB_MODULE)
  #  8   = relationships (MDB_RELATIONSHIP)
  # 10   = db properties (MDB_DATABASE_PROPERTY)
  # -2   = all non-system
  # -1   = all (MDB_ANY)
  type_codes <- c(
    table = 1L,
    systable = -3L,
    query = 5L,
    form = 0L,
    macro = 2L,
    report = 4L,
    linkedtable = 6L,
    module = 7L,
    relationship = 8L,
    dbprop = 10L,
    any = -2L,
    all = -1L
  )

  # For any/all with show_type, make per-type calls so we can label each entry.
  if (isTRUE(show_type) && type %in% c("any", "all")) {
    single_types <- setdiff(names(type_codes), c("any", "all"))
    if (type == "any") {
      single_types <- setdiff(single_types, "systable")
    }
    parts <- character(0)
    for (t in single_types) {
      entries <- .native_list_objects(path, type_codes[[t]])
      if (length(entries)) parts <- c(parts, paste(t, entries))
    }
    if (isTRUE(system) && type == "any") {
      sys_entries <- .native_list_objects(path, -3L)
      if (length(sys_entries)) parts <- c(parts, paste("systable", sys_entries))
    }
    return(parts)
  }

  # Single call for all other cases.
  out <- .native_list_objects(path, type_codes[[type]])

  # system = TRUE appends system tables on top of type result
  # (except systable/all which already contain them)
  if (isTRUE(system) && !type %in% c("systable", "all")) {
    sys_out <- .native_list_objects(path, -3L)
    if (isTRUE(show_type)) {
      out <- paste(type, out)
      sys_out <- paste("systable", sys_out)
    }
    return(c(out, sys_out))
  }

  if (isTRUE(show_type)) {
    out <- paste(type, out)
  }

  out
}
