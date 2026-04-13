# PISA European Explorer : Pipeline ETL & Dashboard

🔗 **[Lien vers la démo interactive](https://paul-laporte.shinyapps.io/Scolaire-data)** 

## 📝 À propos du projet
Ce projet analyse et modélise l'évolution du niveau scolaire moyen des élèves européens de 15 ans (en lecture et en sciences) sur les années 2015, 2018 et 2022. 

L'objectif principal n'était pas seulement la visualisation, mais la **gestion de données massives en mémoire**. Les données brutes fournies par l'OCDE (fichiers SAS) contiennent plus de 2500 variables et pèsent environ 8 Go par année, posant un véritable défi d'optimisation pour leur traitement.

## 🛠️ Le défi technique (Data Engineering)
Pour contourner les limites de la RAM lors de la lecture des fichiers SAS, un pipeline ETL a été développé :
* **Lecture par "Chunking" :** Traitement des données par blocs dynamiques (20 000 à 30 000 lignes) pour isoler les étudiants européens.
* **Gestion optimisée de la mémoire :** Nettoyage à la volée via le Garbage Collector (`gc()`) et suppression dynamique des variables temporaires.
* **Robustesse :** Implémentation de mécanismes de `tryCatch` pour éviter les crashs de lecture et reprise automatique en cas d'erreur.

## 💻 Stack Technique
* **Langage :** R
* **ETL & Manipulation :** `dplyr`, `haven`, `data.table`
* **Dashboard & UI :** `Shiny`, `flexdashboard`
* **Visualisation :** `ggplot2`, `highcharter`, `leaflet`

## 📂 Structure du dépôt
* `clean-data-opti-chunk.R` : Le script ETL principal gérant l'extraction par lot et la jointure des fichiers SAS de l'OCDE.
* `app.Rmd` : Le code source du tableau de bord interactif (interface, cartographie, graphiques d'évolution avec marges d'erreur).
* `pisa_avg_*.rds` : Fichiers de données nettoyées et agrégées pour l'application.

## 📈 Fonctionnalités du Dashboard
* **Cartographie interactive :** Visualisation des scores moyens par pays européen.
* **Analyse temporelle :** Comparaison de l'évolution des scores entre deux pays sur les 3 éditions étudiées, incluant la pondération de la marge d'erreur.
* **Classements :** Tables dynamiques des performances en lecture et en sciences.

---
*Ce projet a été réalisé dans le cadre de ma formation d'ingénieur. Un rapport plus détaillé est disponible dans le dashboard.*
