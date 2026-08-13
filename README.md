# QField Table

**QField Table** est un plugin QML pour QField offrant une vue tabulaire avancée des données d’un projet QGIS/QField. Il vise surtout le contrôle de qualité, la recherche d’incohérences et les corrections en lot sur le terrain.

> Version documentée : **v0.9.2** — projet en développement actif (série 0.x).

## Fonctionnalités

- Affichage des couches et tables du projet dans une table attributaire adaptée à QField.
- Alias de champs, choix et réorganisation des colonnes, redimensionnement manuel et défilement horizontal.
- Recherche globale et chargement progressif des couches volumineuses.
- Filtres directement dans les en-têtes; plusieurs filtres peuvent être combinés avec un **ET logique**.
- Partage/importation d’une vue JSON (couche, colonnes visibles/ordre et filtres).
- Sélection d’enregistrements et **modification en lot** limitée aux champs affichés.
- Gestion des champs multiples et des widgets QGIS **ValueRelation** avec `AllowMulti`.
- Lecture des titres relationnels, de la configuration ValueRelation et du `FilterExpression` du projet QGIS/QGZ.
- Journal avant/après des modifications en lot.

## Modification en lot et ValueRelation

Pour les champs multiples, QField Table peut ajouter ou retirer une valeur sans écraser inutilement les valeurs existantes. Lorsque le projet fournit une ValueRelation, le plugin cherche à afficher le **titre lisible** plutôt que la clé stockée et applique le filtre configuré dans QGIS.

La création d’une nouvelle entrée dans une table de référence n’est volontairement pas proposée pour les champs multiples : les données de référence doivent être créées par un mécanisme explicitement prévu par le projet.

## Journal des modifications

Chaque modification en lot peut conserver : date/heure, couche, identifiant d’entité, champ et alias, opération, valeurs lisibles avant/après, valeurs brutes avant/après, statut et note.

### Table GeoPackage recommandée

Depuis la v0.9.2, le plugin recherche automatiquement une table attributaire nommée :

```text
qfield_table_journal
```

Si elle est présente dans le projet et éditable, les nouvelles entrées y sont écrites. Elle peut ainsi suivre le workflow de synchronisation du GeoPackage/QFieldCloud selon la configuration QFieldSync du projet.

Si la table est absente ou inutilisable, QField Table conserve un **journal JSON local de secours**. Ce secours n’est pas destiné à remplacer la table GeoPackage pour un historique partagé.

## Initialiser le journal GeoPackage

Le dépôt fournit :

```text
tools/create_journal_table.py
```

Le script est idempotent : il ne supprime pas les entrées existantes. Il crée la table et l’enregistre dans `gpkg_contents` avec le type `attributes`.

Avant son exécution, fermez QGIS/QField et sauvegardez le GeoPackage. Puis :

```bash
python tools/create_journal_table.py "chemin/vers/projet.gpkg"
```

Exemple Windows :

```powershell
python tools\create_journal_table.py "C:\Projets\Patrimoine\data.gpkg"
```

Après l’exécution :

1. Rouvrez QGIS.
2. Ajoutez `qfield_table_journal` au projet comme table sans géométrie.
3. Vérifiez sa configuration dans QFieldSync afin qu’elle soit disponible/éditable selon votre workflow.
4. Sauvegardez puis republiez/synchronisez le projet.
5. Dans QField Table, vérifiez que l’historique indique **« Stockage : table qfield_table_journal du projet »** et non « Stockage de secours ».

### Schéma du journal

| Champ | Contenu |
|---|---|
| `fid` | clé primaire |
| `date_heure` | date et heure |
| `couche` | couche modifiée |
| `id_entite` | identifiant de l’enregistrement |
| `champ` | nom technique du champ |
| `champ_titre` | alias/titre affiché |
| `operation` | opération en lot |
| `avant` / `apres` | valeurs lisibles |
| `brut_avant` / `brut_apres` | valeurs stockées |
| `statut` | résultat |
| `note` | information complémentaire |

## Préparation d’un projet QGIS

Pour profiter de toutes les fonctions, configurez les alias et widgets dans QGIS, incluez les couches de référence utilisées par les ValueRelation, définissez leurs `FilterExpression` lorsque nécessaire et testez l’empaquetage QFieldSync avant le déploiement. QField Table cherche à réutiliser la configuration du projet plutôt qu’à coder en dur les noms de tables, clés ou titres.

## Sécurité

Une modification en lot peut affecter plusieurs enregistrements. Testez d’abord sur une copie, conservez des sauvegardes, vérifiez la sélection avant confirmation et testez la synchronisation réelle QField/QFieldCloud. Le journal facilite l’audit des changements mais **ne remplace pas une sauvegarde de la base**.

## Historique abrégé

### v0.9.2
- journal persistant dans `qfield_table_journal`;
- détection/lecture automatique de la table du projet;
- JSON conservé comme secours;
- table technique masquée du sélecteur normal de couches.

### v0.9.x
- historique persistant et export/copie du journal;
- améliorations de la gestion des couches et tables.

### v0.8.x
- modification en lot avancée;
- tableaux multiples et ValueRelation;
- lecture du projet QGZ, résolution des couches relationnelles et `FilterExpression`;
- titres relationnels et journal avant/après.

### v0.7.x
- sélection d’enregistrements;
- filtres multiples par en-tête;
- colonnes redimensionnables et configurables;
- partage/importation de vues;
- premières modifications en lot.

## Signaler un problème

Indiquez idéalement les versions de QField, QField Table et QGIS, le type de source de données, les étapes de reproduction, une capture d’écran et tout diagnostic affiché par le plugin. Ne publiez pas de GeoPackage ou journal contenant des données confidentielles dans une issue publique.

## Licence

La licence du dépôt reste à choisir. Ajoutez un fichier `LICENSE` avant une diffusion publique (par exemple GPL-2.0-or-later, GPL-3.0-or-later ou autre licence compatible avec vos objectifs).
