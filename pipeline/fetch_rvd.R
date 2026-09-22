# fetch_rvd.R — Download RVD property market CSVs, clean, and load into MySQL.
#
# Data sources (verified 2026-09-20 against real downloaded files):
#   1.4M.csv — Private Domestic Price Indices (territory-wide), by Class A-E, monthly.
#              Wide format: Month, Class A, Class A - Remarks, Class B, ... , All Classes, All Classes - Remarks
#              NO region breakdown.
#   1.2M.csv — Private Domestic Average Prices, by Class A-E x Region (Hong Kong/Kowloon/New Territories), monthly.
#              Wide format: Month, Class A Hong Kong, Class A Hong Kong - Remarks, Class A Kowloon, ...
#   7.3.csv  — Domestic Primary/Secondary Sales — number of agreements + consideration, monthly.
#              Wide format: Month, Primary Sales Number, Primary Sales Consideration,
#                           Secondary Sales Number, Secondary Sales Consideration
#              NO region breakdown.
#
# Known limitations (do not pretend otherwise):
#   - No per-transaction records, no latitude/longitude in RVD public data.
#   - No region breakdown for price_index_monthly or sales_volume_monthly.
#   - Header row is the 2nd line of each file; line 1 is a title string, not data.
#   - Income data (income_reference / income_reference_by_district) is NOT auto-fetched here;
#     it's manually curated from C&SD annual district reports (seeded in 01_schema.sql), because
#     it's published as an annual PDF/report, not a stable machine-readable CSV endpoint.

suppressMessages({
  library(httr)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(RMariaDB)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

# Resolve project root regardless of where Rscript is invoked from.
get_script_path <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- cmd_args[str_starts(cmd_args, "--file=")]
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[1])))
  }
  # Fallback: assume invoked from project root as pipeline/fetch_rvd.R
  normalizePath(file.path("pipeline", "fetch_rvd.R"))
}
PROJECT_ROOT <- dirname(dirname(get_script_path()))
RAW_DIR <- file.path(PROJECT_ROOT, "data", "raw")
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

SOURCES <- list(
  price_index  = list(file = "1.4M.csv", url = "http://www.rvd.gov.hk/datagovhk/1.4M.csv"),
  avg_price    = list(file = "1.2M.csv", url = "http://www.rvd.gov.hk/datagovhk/1.2M.csv"),
  sales_volume = list(file = "7.3.csv",  url = "http://www.rvd.gov.hk/datagovhk/7.3.csv")
)

download_file <- function(url, dest) {
  resp <- GET(url)
  stop_for_status(resp)
  writeBin(content(resp, "raw"), dest)
  message(sprintf("downloaded %s (%d bytes)", basename(dest), length(content(resp, "raw"))))
  dest
}

parse_month_col <- function(month_str) {
  parts <- str_split_fixed(str_trim(month_str), "-", 2)
  list(month = as.integer(parts[, 1]), year = as.integer(parts[, 2]))
}

# ---- 1.4M.csv: territory-wide price index by class ----
CLASS_INDEX_COLUMNS <- c(
  "Class A" = "A", "Class B" = "B", "Class C" = "C", "Class D" = "D", "Class E" = "E",
  "Classes A, B & C" = "ABC", "Classes D & E" = "DE", "All Classes" = "ALL"
)

load_price_index <- function(path) {
  df <- read_csv(path, skip = 1, show_col_types = FALSE)
  df <- df[!is.na(df$Month) & str_detect(df$Month, "-"), ]
  ym <- parse_month_col(df$Month)

  out <- list()
  for (col_name in names(CLASS_INDEX_COLUMNS)) {
    if (!col_name %in% names(df)) next
    class_code <- CLASS_INDEX_COLUMNS[[col_name]]
    remark_col <- paste0(col_name, " - Remarks")
    remark_vals <- if (remark_col %in% names(df)) as.character(df[[remark_col]]) else NA_character_
    chunk <- tibble(
      year = ym$year,
      month = ym$month,
      class = class_code,
      price_index = suppressWarnings(as.numeric(df[[col_name]])),
      remark = remark_vals
    )
    out[[col_name]] <- chunk
  }
  bind_rows(out) %>% filter(!is.na(price_index))
}

# ---- 1.2M.csv: average price by class x region ----
REGIONS <- c("Hong Kong", "Kowloon", "New Territories")
CLASSES <- c("A", "B", "C", "D", "E")

load_avg_price <- function(path) {
  df <- read_csv(path, skip = 1, show_col_types = FALSE)
  df <- df[!is.na(df$Month) & str_detect(df$Month, "-"), ]
  ym <- parse_month_col(df$Month)

  out <- list()
  for (cls in CLASSES) {
    for (region in REGIONS) {
      col_name <- paste("Class", cls, region)
      if (!col_name %in% names(df)) next
      remark_col <- paste0(col_name, " - Remarks")
      remark_vals <- if (remark_col %in% names(df)) as.character(df[[remark_col]]) else NA_character_
      chunk <- tibble(
        year = ym$year,
        month = ym$month,
        class = cls,
        region = region,
        avg_price_hkd = suppressWarnings(as.numeric(df[[col_name]])),
        remark = remark_vals
      )
      out[[col_name]] <- chunk
    }
  }
  bind_rows(out) %>% filter(!is.na(avg_price_hkd))
}

# ---- 7.3.csv: territory-wide sales volume ----
load_sales_volume <- function(path) {
  df <- read_csv(path, skip = 1, show_col_types = FALSE)
  df <- df[!is.na(df$Month) & str_detect(df$Month, "-"), ]
  ym <- parse_month_col(df$Month)

  tibble(
    year = ym$year,
    month = ym$month,
    primary_sales_count = suppressWarnings(as.integer(df[["Primary Sales Number"]])),
    primary_sales_consideration = suppressWarnings(as.numeric(df[["Primary Sales Consideration"]])),
    secondary_sales_count = suppressWarnings(as.integer(df[["Secondary Sales Number"]])),
    secondary_sales_consideration = suppressWarnings(as.numeric(df[["Secondary Sales Consideration"]]))
  ) %>% filter(!is.na(primary_sales_count))
}

get_connection <- function() {
  env_path <- file.path(PROJECT_ROOT, ".env")
  env_vars <- list(DB_HOST = "localhost", DB_PORT = "3306", DB_USER = "root", DB_PASSWORD = "", DB_NAME = "hk_property")
  if (file.exists(env_path)) {
    lines <- readLines(env_path)
    for (line in lines) {
      line <- str_trim(line)
      if (line == "" || str_starts(line, "#")) next
      kv <- str_split_fixed(line, "=", 2)
      env_vars[[kv[1]]] <- kv[2]
    }
  }
  dbConnect(
    RMariaDB::MariaDB(),
    host = env_vars$DB_HOST,
    port = as.integer(env_vars$DB_PORT),
    user = env_vars$DB_USER,
    password = env_vars$DB_PASSWORD,
    dbname = env_vars$DB_NAME
  )
}

upsert_rows <- function(con, table, df, key_cols, value_cols) {
  if (nrow(df) == 0) return(0L)
  all_cols <- c(key_cols, value_cols)
  placeholders <- paste(rep("?", length(all_cols)), collapse = ", ")
  update_clause <- paste(sprintf("%s = VALUES(%s)", value_cols, value_cols), collapse = ", ")
  sql <- sprintf(
    "INSERT INTO %s (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s",
    table, paste(all_cols, collapse = ", "), placeholders, update_clause
  )
  stmt <- dbSendStatement(con, sql)
  for (i in seq_len(nrow(df))) {
    row_values <- unname(as.list(df[i, all_cols, drop = FALSE]))
    dbBind(stmt, row_values)
  }
  dbClearResult(stmt)
  nrow(df)
}

main <- function() {
  price_index_path <- download_file(SOURCES$price_index$url, file.path(RAW_DIR, SOURCES$price_index$file))
  avg_price_path    <- download_file(SOURCES$avg_price$url,    file.path(RAW_DIR, SOURCES$avg_price$file))
  sales_volume_path <- download_file(SOURCES$sales_volume$url, file.path(RAW_DIR, SOURCES$sales_volume$file))

  price_index_df  <- load_price_index(price_index_path)
  avg_price_df    <- load_avg_price(avg_price_path)
  sales_volume_df <- load_sales_volume(sales_volume_path)

  message(sprintf(
    "parsed rows: price_index=%d avg_price=%d sales_volume=%d",
    nrow(price_index_df), nrow(avg_price_df), nrow(sales_volume_df)
  ))

  con <- get_connection()
  on.exit(dbDisconnect(con), add = TRUE)

  n1 <- upsert_rows(con, "price_index_monthly", price_index_df,
                     c("year", "month", "class"), c("price_index", "remark"))
  n2 <- upsert_rows(con, "avg_price_monthly", avg_price_df,
                     c("year", "month", "class", "region"), c("avg_price_hkd", "remark"))
  n3 <- upsert_rows(con, "sales_volume_monthly", sales_volume_df,
                     c("year", "month"),
                     c("primary_sales_count", "primary_sales_consideration",
                       "secondary_sales_count", "secondary_sales_consideration"))

  message(sprintf("upserted rows: price_index=%d avg_price=%d sales_volume=%d", n1, n2, n3))
}

main()
