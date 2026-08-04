QField Table — version 0.1.0
================================

OBJECTIF
Cette version est un diagnostic technique en lecture seule. Elle ajoute un bouton de table à la barre d’outils de QField et permet :
- de détecter les couches vectorielles du projet;
- de choisir une couche;
- d’afficher son nombre d’enregistrements;
- de lire les 25 premières entités;
- d’afficher tous les champs et leurs valeurs.

INSTALLATION
1. Dans QField, ouvrir Paramètres > Plugins.
2. Choisir « Installer un plugin depuis un ZIP/une URL » selon la plateforme.
3. Sélectionner QFieldTable_v0.1.zip.
4. Activer « QField Table ».
5. Ouvrir un projet QGIS/QField.
6. Appuyer sur l’icône de table dans la barre d’outils.

IMPORTANT
Le fichier main.qml et metadata.txt sont à la racine du ZIP, comme l’exige QField.
Cette version ne modifie aucune donnée.

À NOTER POUR LE TEST
- Confirmer que toutes les couches vectorielles attendues apparaissent.
- Sélectionner notamment « Bâtiments inventoriés ».
- Vérifier si les noms et valeurs de tous les champs s’affichent.
- En cas d’erreur, copier le texte « Erreur de diagnostic » ou la sortie de la console QField.
