# 1. Imports
import logging
import argparse
import zipfile
import requests
from pathlib import Path  

# 2. Paths: repo root, data/raw
REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = REPO_ROOT / 'data' / 'raw'

# 3. Config: PLUTO name, URL, output filename
SOURCES = [
    {"name": "PLUTO", "url": "https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/pluto/nyc_pluto_26v3_csv.zip", "filename": "nyc_pluto_26v3_csv.zip"},
]

# 4. Logging setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logging.info(f"Raw data folder: {RAW_DIR}")
logging.info(f"{SOURCES[0]['name']}: {SOURCES[0]['url']}")

# 5. download(url, dest): skip if exists unless force; stream to .part; rename when done

# 6. unzip(zip_path, out_dir): extract, return the CSV path

# 7. count_rows(csv_path): data rows, not counting the header

# 8. main(): parse --force, run steps 5 to 7 for PLUTO, log results

# 9. Run main() when the file is executed directly
