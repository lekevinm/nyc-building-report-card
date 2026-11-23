# 1. Imports
import logging
import argparse
import csv
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

# 5. download(url, dest): skip if exists unless force; stream to .part; rename when done
def download(url, dest, force=False):
    if dest.exists() and not force:
        logging.info(f"File {dest} already exists. Skipping download.")
        return
    temp_dest = dest.with_suffix(dest.suffix + ".part")

    logging.info(f"Downloading {url} to {temp_dest}...")
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(temp_dest, 'wb') as f:
            for chunk in r.iter_content(chunk_size=(1024 * 1024)):
                f.write(chunk)
    temp_dest.replace(dest)
    logging.info(f"Downloaded and saved to {dest}. Size is {dest.stat().st_size} bytes.")

# 6. unzip(zip_path, out_dir): extract, return the CSV path
def unzip(zip_path, out_dir, force=False):
    with zipfile.ZipFile(zip_path) as z:
        # Keep only the .csv entries; the zip may also hold a readme or PDF.
        names = z.namelist()
        csv_names = [n for n in names if n.lower().endswith(".csv")]
        if len(csv_names) != 1:
            raise ValueError(f"Expected 1 CSV in {zip_path}, found {csv_names}")
        name = csv_names[0]
        out_path = Path(out_dir) / name

        # Same idempotency rule as download(): don't redo work unless --force.
        # Return the path (not a bare return) because count_rows() needs it.
        if out_path.exists() and not force:
            logging.info(f"{out_path} already extracted. Skipping unzip.")
            return out_path

        # Everything that touches z stays inside the with block, while the zip is open.
        z.extract(name, out_dir)
        logging.info(f"Extracted {name} to {out_dir}")
        return out_path

# 7. count_rows(csv_path): data rows, not counting the header
def count_rows(csv_path):
    # csv.reader handles quoted fields that contain line breaks, so this counts
    # records, not raw lines. newline="" is what the csv module expects.
    # errors="replace" keeps one odd byte from crashing a count.
    with open(csv_path, newline="", encoding="utf-8", errors="replace") as f:
        rows = sum(1 for _ in csv.reader(f))
    return rows - 1  # minus the header row

# 8. main(): parse --force, run steps 5 to 7 for PLUTO, log results
def main():
    # argparse reads command-line options. --force is a flag: present = True.
    parser = argparse.ArgumentParser(description="Download raw NYC data into data/raw.")
    parser.add_argument("--force", action="store_true", help="re-download and re-extract even if files exist")
    args = parser.parse_args()

    logging.info(f"Raw data folder: {RAW_DIR}")

    for source in SOURCES:
        dest = RAW_DIR / source["filename"]
        logging.info(f"{source['name']}: {source['url']}")
        download(source["url"], dest, force=args.force)

        # Zipped sources get extracted and row-counted. Non-zip sources
        # (the NTA GeoJSON, once it's added) are logged by download() only.
        if dest.suffix == ".zip":
            csv_path = unzip(dest, RAW_DIR, force=args.force)
            rows = count_rows(csv_path)
            logging.info(f"{source['name']}: {rows:,} data rows in {csv_path.name}")

# 9. Run main() when the file is executed directly
# (python scripts/download.py), but not when another script imports it.
if __name__ == "__main__":
    main()
