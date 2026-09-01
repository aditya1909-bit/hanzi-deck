#!/usr/bin/env python3
"""Build the read-only app dictionary from an official CC-CEDICT text file."""

from __future__ import annotations

import argparse
import gzip
import re
import sqlite3
from pathlib import Path


ENTRY_PATTERN = re.compile(
    r"^(?P<traditional>\S+)\s+(?P<simplified>\S+)\s+"
    r"\[(?P<pinyin>[^]]+)]\s+/(?P<definitions>.*)/$"
)

METADATA_PREFIXES = (
    "cl:",
    "classifier:",
    "also pr.",
    "also pronounced",
    "taiwan pr.",
    "pr. ",
)


def concise_meanings(definitions: str, limit: int = 3) -> str:
    useful = (
        definition.strip()
        for definition in definitions.split("/")
        if definition.strip()
        and not definition.strip().lower().startswith(METADATA_PREFIXES)
    )
    return "; ".join(list(useful)[:limit])


def parse_line(line: str) -> tuple[str, str, str, str] | None:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None

    match = ENTRY_PATTERN.match(stripped)
    if not match:
        return None

    meanings = concise_meanings(match.group("definitions"))
    if not meanings:
        return None

    return (
        match.group("traditional"),
        match.group("simplified"),
        match.group("pinyin"),
        meanings,
    )


def source_lines(path: Path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8-sig") as source:
        yield from source


def build(source: Path, destination: Path) -> tuple[int, int]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination.unlink()

    connection = sqlite3.connect(destination)
    try:
        connection.executescript(
            """
            PRAGMA journal_mode = OFF;
            PRAGMA synchronous = OFF;
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                traditional TEXT NOT NULL,
                simplified TEXT NOT NULL,
                pinyin TEXT NOT NULL,
                meaning TEXT NOT NULL
            );
            """
        )

        parsed = 0
        skipped = 0
        batch: list[tuple[str, str, str, str]] = []
        for line in source_lines(source):
            entry = parse_line(line)
            if entry is None:
                if line.strip() and not line.lstrip().startswith("#"):
                    skipped += 1
                continue
            batch.append(entry)
            if len(batch) == 2_000:
                connection.executemany(
                    "INSERT INTO entries (traditional, simplified, pinyin, meaning) VALUES (?, ?, ?, ?)",
                    batch,
                )
                parsed += len(batch)
                batch.clear()

        if batch:
            connection.executemany(
                "INSERT INTO entries (traditional, simplified, pinyin, meaning) VALUES (?, ?, ?, ?)",
                batch,
            )
            parsed += len(batch)

        connection.executescript(
            """
            CREATE INDEX idx_entries_traditional ON entries(traditional);
            CREATE INDEX idx_entries_simplified ON entries(simplified);
            PRAGMA optimize;
            """
        )
        connection.commit()
        return parsed, skipped
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    parsed, skipped = build(args.source, args.destination)
    print(f"Built {args.destination} with {parsed} entries ({skipped} non-comment lines skipped).")


if __name__ == "__main__":
    main()
