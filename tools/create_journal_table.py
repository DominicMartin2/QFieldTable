#!/usr/bin/env python3
import argparse, sqlite3, sys
from datetime import datetime, timezone
from pathlib import Path
TABLE_NAME='qfield_table_journal'
def utc_timestamp(): return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')
def exists(c,n):
 c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",(n,)); return c.fetchone() is not None
def initialize(gpkg):
 if not gpkg.is_file(): raise FileNotFoundError(f'GeoPackage introuvable : {gpkg}')
 con=sqlite3.connect(str(gpkg),timeout=30)
 try:
  c=con.cursor()
  if not exists(c,'gpkg_contents'): raise RuntimeError("Ce fichier ne semble pas être un GeoPackage valide (gpkg_contents absent).")
  c.execute(f'''CREATE TABLE IF NOT EXISTS "{TABLE_NAME}" (fid INTEGER PRIMARY KEY AUTOINCREMENT,date_heure TEXT NOT NULL,couche TEXT,id_entite TEXT,champ TEXT,champ_titre TEXT,operation TEXT,avant TEXT,apres TEXT,brut_avant TEXT,brut_apres TEXT,statut TEXT,note TEXT)''')
  c.execute('SELECT 1 FROM gpkg_contents WHERE table_name=?',(TABLE_NAME,))
  if c.fetchone() is None:
   c.execute('''INSERT INTO gpkg_contents (table_name,data_type,identifier,description,last_change,min_x,min_y,max_x,max_y,srs_id) VALUES (?,'attributes',?,?,?,NULL,NULL,NULL,NULL,NULL)''',(TABLE_NAME,TABLE_NAME,'Journal des modifications en lot de QField Table',utc_timestamp()))
  for suffix,col in [('date','date_heure'),('couche','couche'),('entite','id_entite')]: c.execute(f'CREATE INDEX IF NOT EXISTS "idx_{TABLE_NAME}_{suffix}" ON "{TABLE_NAME}" ("{col}")')
  con.commit(); c.execute(f'SELECT COUNT(*) FROM "{TABLE_NAME}"'); count=c.fetchone()[0]
  print('QField Table — initialisation terminée'); print('GeoPackage :',gpkg.resolve()); print('Table      :',TABLE_NAME); print('Entrées    :',count); print('Type GPKG  : attributes'); print('\nAjoutez ensuite qfield_table_journal au projet QGIS et configurez QFieldSync.')
 except Exception: con.rollback(); raise
 finally: con.close()
def main():
 p=argparse.ArgumentParser(description='Crée la table qfield_table_journal dans un GeoPackage.'); p.add_argument('geopackage',type=Path); a=p.parse_args()
 try: initialize(a.geopackage); return 0
 except Exception as e: print('ERREUR :',e,file=sys.stderr); return 1
if __name__=='__main__': raise SystemExit(main())
