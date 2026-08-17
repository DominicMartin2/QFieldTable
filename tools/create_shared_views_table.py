#!/usr/bin/env python3
import argparse, sqlite3, sys
from datetime import datetime, timezone
from pathlib import Path

TABLE_NAME = "qfield_table_vues"

def utc_timestamp():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

def table_exists(cur, name):
    cur.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,))
    return cur.fetchone() is not None

def initialize(gpkg: Path):
    if not gpkg.is_file():
        raise FileNotFoundError(f"GeoPackage introuvable : {gpkg}")
    con = sqlite3.connect(str(gpkg), timeout=30)
    try:
        cur = con.cursor()
        if not table_exists(cur, "gpkg_contents"):
            raise RuntimeError("Ce fichier ne semble pas être un GeoPackage valide (gpkg_contents absent).")
        cur.execute(f'''CREATE TABLE IF NOT EXISTS "{TABLE_NAME}" (
            fid INTEGER PRIMARY KEY AUTOINCREMENT,
            vue_uuid TEXT NOT NULL UNIQUE,
            titre TEXT NOT NULL,
            message TEXT,
            couche TEXT NOT NULL,
            vue_json TEXT NOT NULL,
            statut TEXT NOT NULL DEFAULT 'À faire',
            auteur TEXT,
            date_creation TEXT NOT NULL,
            date_modification TEXT NOT NULL
        )''')
        cur.execute("SELECT 1 FROM gpkg_contents WHERE table_name=?", (TABLE_NAME,))
        if cur.fetchone() is None:
            cur.execute('''INSERT INTO gpkg_contents
                (table_name,data_type,identifier,description,last_change,min_x,min_y,max_x,max_y,srs_id)
                VALUES (?,'attributes',?,?,?,NULL,NULL,NULL,NULL,NULL)''',
                (TABLE_NAME, TABLE_NAME, "Vues et consignes partagées de QField Table", utc_timestamp()))
        cur.execute(f'CREATE INDEX IF NOT EXISTS "idx_{TABLE_NAME}_couche" ON "{TABLE_NAME}" ("couche")')
        cur.execute(f'CREATE INDEX IF NOT EXISTS "idx_{TABLE_NAME}_statut" ON "{TABLE_NAME}" ("statut")')
        cur.execute(f'CREATE INDEX IF NOT EXISTS "idx_{TABLE_NAME}_date" ON "{TABLE_NAME}" ("date_modification")')
        con.commit()
        cur.execute(f'SELECT COUNT(*) FROM "{TABLE_NAME}"')
        print("QField Table — table de vues partagées prête")
        print("GeoPackage :", gpkg.resolve())
        print("Table      :", TABLE_NAME)
        print("Entrées    :", cur.fetchone()[0])
        print("\nIMPORTANT : ajoutez qfield_table_vues au projet QGIS puis configurez-la pour la synchronisation QFieldSync/QFieldCloud.")
    except Exception:
        con.rollback(); raise
    finally:
        con.close()

def main():
    p=argparse.ArgumentParser(description="Crée la table qfield_table_vues dans un GeoPackage.")
    p.add_argument("geopackage", type=Path)
    args=p.parse_args()
    try:
        initialize(args.geopackage); return 0
    except Exception as e:
        print("ERREUR :", e, file=sys.stderr); return 1

if __name__ == "__main__":
    raise SystemExit(main())
