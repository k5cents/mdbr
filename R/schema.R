# types from mdbtools/src/libmdb/backend.c
#   MDB Tools - A library for reading MS Access database files
#   Copyright (C) 2000-2011 Brian Bruns and others
mdb_col_types <- list(
  "Unknown 0x00" = "c",
  "Boolean" = "l",
  "Byte" = "i",
  "Integer" = "i",
  "Long Integer" = "i",
  "Currency" = "d",
  "Single" = "d",
  "Double" = "d",
  "DateTime" = "T",
  "Binary" = "c",
  "Text" = "c",
  "OLE" = "c",
  "Memo/Hyperlink" = "c",
  "Unknown 0x0d" = "c",
  "Unknown 0x0e" = "c",
  "Replication ID" = "c",
  "Numeric" = "d"
)

list_switch <- function(val, list) {
  do.call("switch", c(val, as.list(list)))
}
