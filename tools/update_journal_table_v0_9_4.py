#!/usr/bin/env python3
"""Mise à niveau de qfield_table_journal pour QField Table v0.9.4.

Ajoute, si nécessaire :
- journal_uuid : identifiant unique de l'entrée de journal ;
- utilisateur  : utilisateur QFieldCloud ayant créé l'entrée.

Usage :
    python update_journal_table_v0_9_4.py /chemin/vers/projet.gpkg
"""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

TABLE = "qfield_table_journal"


def existing_columns(cur: sqlite3.Cursor) -> set[str]:
    return {row[1] for row in cur.execute(f'PRAGMA table_info("{TABLE}")')}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("geopackage", type=Path, help="GeoPackage contenant qfield_table_journal")
    args = parser.parse_args()

    gpkg = args.geopackage.expanduser().resolve()
    if not gpkg.exists():
        raise SystemExit(f"GeoPackage introuvable : {gpkg}")

    con = sqlite3.connect(gpkg)
    try:
        cur = con.cursor()

        if cur.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (TABLE,)
        ).fetchone() is None:
            raise SystemExit(f"La table {TABLE!r} n'existe pas dans {gpkg}")

        columns = existing_columns(cur)

        if "journal_uuid" not in columns:
            cur.execute(f'ALTER TABLE "{TABLE}" ADD COLUMN journal_uuid TEXT')
            print("Ajout : journal_uuid")
        else:
            print("Déjà présent : journal_uuid")

        if "utilisateur" not in columns:
            cur.execute(f'ALTER TABLE "{TABLE}" ADD COLUMN utilisateur TEXT')
            print("Ajout : utilisateur")
        else:
            print("Déjà présent : utilisateur")

        # Plusieurs NULL restent permis, mais deux UUID renseignés ne pourront
        # pas être identiques.
        cur.execute(
            f'CREATE UNIQUE INDEX IF NOT EXISTS "idx_{TABLE}_uuid" '
            f'ON "{TABLE}" (journal_uuid) WHERE journal_uuid IS NOT NULL'
        )

        con.commit()
        print(f"\nMise à niveau terminée : {gpkg}")

    finally:
        con.close()


if __name__ == "__main__":
    main()
