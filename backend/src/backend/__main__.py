"""Run the local API or explicitly export saved measurements to CSV."""

import argparse
from pathlib import Path

import uvicorn

from backend.config import load_settings
from backend.storage.csv_exporter import export_recent_csv
from backend.storage.sqlite_repository import SqliteRepository


def main() -> None:
    parser = argparse.ArgumentParser(description="Local QR and seven-segment capture backend")
    parser.add_argument("command", nargs="?", choices=("serve", "export-csv"), default="serve")
    parser.add_argument("destination", nargs="?", type=Path)
    arguments = parser.parse_args()
    settings = load_settings()
    if arguments.command == "export-csv":
        if not settings.storage_enable or not settings.database_path.is_file():
            parser.error("Enable SQLite storage and save records before exporting CSV")
        if arguments.destination is None:
            parser.error("export-csv requires a destination path")
        repository = SqliteRepository(settings.database_path)
        repository.open()
        try:
            export_recent_csv(repository, arguments.destination)
        finally:
            repository.close()
        return
    uvicorn.run("backend.main:app", host=settings.host, port=settings.port, workers=1, access_log=False)


if __name__ == "__main__":
    main()
