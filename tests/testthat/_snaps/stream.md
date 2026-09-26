# MDB table cursor advances without materializing on open

    Code
      DBI::dbFetch(res, 1L)
    Condition
      Error:
      ! Result has been cleared.

