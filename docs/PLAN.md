# État et feuille de route

Ce document suit ce qui est validé, ce qui doit encore être vérifié sur appareil et les prochains travaux. Il ne remplace pas le contrat produit de [`V3.md`](V3.md).

## Référence actuelle

- refonte fonctionnelle : PR `#11` ;
- documentation d’accueil : PR `#12` ;
- dernière validation complète : GitHub Actions run `#88` (`32844625963`) ;
- dernière version publiée par cette validation : `0.3.12` ;
- toolchain : Xcode 26, Swift 6, cible iOS 26 ;
- distribution : IPA non signée, Release GitHub et branche `site`.

Le run `#88` confirme les tests, le build iPhone, le packaging, la Release, les métadonnées du site et l’artifact. Il ne constitue pas une validation visuelle sur appareil.

## Fonctionnalités considérées comme implémentées

### Données

- POST CELCAT prioritaire et fallback iCal strict ;
- séparation du groupe de requête et du groupe réel du cours ;
- sélection et fusion visuelle multi-groupes ;
- types de cours dynamiques ;
- normalisation commune aux vues, à la recherche et à la Live Activity ;
- snapshots et détection de changements basés sur le POST.

### Calendrier

- surface Jour/Semaine fondée sur les mêmes coordonnées temporelles ;
- navigation horizontale indépendante du scroll vertical ;
- initialisation Jour sur la ligne rouge et Semaine sur le premier cours visible ;
- ruban Semaine unique réunissant en-tête et contenu ;
- extension vers le passé et le futur ;
- cartes adaptatives, état pressé et espacement des cours consécutifs ;
- traitement visuel des journées et cours passés.

### Personnalisation et contexte

- réglage continu de la teinte des types ;
- groupes hiérarchiques dynamiques ;
- temps simulé partagé par la logique temporelle ;
- Live Activity Lock Screen alimentée par le modèle normalisé.

## Validation matérielle prioritaire

Avant de considérer la refonte visuelle comme définitivement stabilisée, exécuter toute la matrice de [`QUALITY_ASSURANCE.md`](QUALITY_ASSURANCE.md) sur un iPhone iOS 26 :

1. précision des positions Jour et Semaine sur plusieurs journées réelles ;
2. conservation du scroll après des swipes rapides et après extension de la fenêtre ;
3. lisibilité des cours courts sur les cinq colonnes ;
4. interaction continue du slider de teinte ;
5. pression, haptique et ouverture du détail ;
6. contraste des états passés en clair et sombre ;
7. Live Activity avec changement de simulation ;
8. fluidité avec plusieurs groupes et plusieurs semaines chargées.

## Prochaines priorités

### P0 — Fermer la validation UX

- consigner le modèle d’iPhone, la version iOS et les captures de référence ;
- corriger uniquement les causes structurelles observées, pas les symptômes isolés ;
- ajouter un test de régression pour chaque défaut reproductible.

### P1 — Consolider la Live Activity

- tester tous les états temporels et les transitions sur appareil ;
- vérifier la lisibilité avec des intitulés, groupes et enseignants longs ;
- maintenir le Lock Screen comme seule expérience produit revendiquée ;
- conserver uniquement la compatibilité système minimale exigée par ActivityKit hors Lock Screen.

### P1 — Étendre la robustesse CELCAT

- enrichir les fixtures avec plusieurs salles, plusieurs enseignants et groupes larges ;
- ajouter des cas de changement d’heure et de fuseau `Europe/Paris` ;
- documenter puis tester tout nouveau format observé avant d’élargir le parseur ;
- évaluer les récurrences iCal seulement si un cas réel le justifie.

### P2 — Mesurer les performances

- instrumenter le coût du layout Semaine et des cartes ;
- mesurer le nombre de chargements réseau pendant une longue navigation ;
- borner explicitement caches et fenêtres préchargées ;
- établir un budget de rendu sur l’appareil iOS 26 le plus lent supporté.

### P2 — Stabiliser le design system

- centraliser espacements, rayons, typographies, opacités et couleurs sémantiques ;
- documenter les variantes compactes des cartes ;
- tester Dynamic Type, contraste accru et réduction des animations ;
- harmoniser les réglages, feuilles de détail et contrôles flottants.

## Définition de terminé

Une priorité quitte ce plan uniquement quand son comportement est implémenté, testé, vérifié sur le matériel pertinent, documenté et fusionné sur `main`. Une capture convaincante ou un run vert pris isolément ne suffit pas.
