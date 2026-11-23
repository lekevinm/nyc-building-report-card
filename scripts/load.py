# load.py: load the raw files from data/raw into data/nyc.duckdb, one raw table per source.
# Run after download.py. Safe to rerun: each table is rebuilt from the files (CREATE OR REPLACE).

# 1. Imports
import logging
from pathlib import Path

import duckdb

# 2. Paths: same pattern as download.py
REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = REPO_ROOT / "data" / "raw"
DB_PATH = REPO_ROOT / "data" / "nyc.duckdb"

# 3. Config: table name -> (file in data/raw, DuckDB reader)
# Raw tables keep every CSV column as text (all_varchar). Types get set on purpose
# in the dbt staging models, so a bad value shows up as a failed cast there
# instead of DuckDB guessing a type from a sample of rows here.
# The PLUTO filename carries the release (26v3); update it when the release changes.
TABLES = {
    "raw_pluto": ("pluto_26v3.csv", "read_csv"),
    "raw_streeteasy": ("medianAskingRent_All.csv", "read_csv"),
    "raw_nta": ("nta_2020.geojson", "st_read"),
}

# 4. Logging setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


# 5. load_table(con, table, path, reader): build one raw table from one file
def load_table(con, table, path, reader):
    if not path.exists():
        raise FileNotFoundError(f"{path} not found. Run python scripts/download.py first.")

    if reader == "read_csv":
        sql = f"CREATE OR REPLACE TABLE {table} AS SELECT * FROM read_csv(?, header = true, all_varchar = true)"
    else:
        # ST_Read comes from the spatial extension and turns the GeoJSON's
        # shapes into a GEOMETRY column (needed for the Day 3 point-in-polygon join).
        sql = f"CREATE OR REPLACE TABLE {table} AS SELECT * FROM ST_Read(?)"

    # The ? is a parameter: DuckDB fills it with the path, so no quoting issues.
    con.execute(sql, [str(path)])
    rows = con.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
    cols = len(con.execute(f"DESCRIBE {table}").fetchall())
    logging.info(f"{table}: {rows:,} rows, {cols} columns from {path.name}")


# 6. main(): open the database, load the spatial extension, load each table
def main():
    logging.info(f"Database: {DB_PATH}")
    con = duckdb.connect(str(DB_PATH))  # creates the file if it doesn't exist
    try:
        # INSTALL downloads the extension once; LOAD turns it on for this connection.
        con.execute("INSTALL spatial")
        con.execute("LOAD spatial")
        for table, (filename, reader) in TABLES.items():
            load_table(con, table, RAW_DIR / filename, reader)
    finally:
        con.close()  # always close, even if a load fails, so the file isn't left locked


# 7. Run main() when the file is executed directly
if __name__ == "__main__":
    main()
