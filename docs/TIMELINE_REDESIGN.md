# Architecture de navigation et de scroll

Ce document protège la refonte conceptuelle de Jour/Semaine. Toute correction de timeline doit commencer par identifier l’état responsable au lieu d’ajouter un délai ou un `scrollTo` supplémentaire.

## 1. Les trois axes

```text
Navigation horizontale  → focusedDate / horizontalDayID
Position verticale      → dayTopMinute / weekTopMinute
Données disponibles     → loadedIntervals / activeLoadTask
```

Ces axes communiquent par demandes explicites, jamais par effets de bord.

## 2. Intention de scroll

`TimelineScrollRequest` représente uniquement un recentrage demandé par le produit :

- `.now` ;
- `.minute(Int)`.

Producteurs autorisés :

- bouton Aujourd’hui ;
- activation/réinitialisation de simulation ;
- ouverture d’un résultat de recherche.

Producteurs interdits :

- `moveDay` ;
- changement de `horizontalDayID` ;
- `ensureLoaded` ou `load` ;
- extension du ruban Semaine ;
- simple changement Jour/Semaine.

La vue consomme la requête par son ID après le scroll.

## 3. Initialisation Jour

Ordre obligatoire :

1. rendre le squelette de timeline ;
2. demander les données du jour et des voisins ;
3. attendre les chargements en vol ;
4. laisser SwiftUI produire les ancres ;
5. appliquer une requête explicite en attente, sinon restaurer `dayTopMinute` ;
6. si aucune position n’existe, centrer la ligne rouge sur aujourd’hui ;
7. activer l’enregistrement du scroll utilisateur.

L’événement initial de géométrie à `0` ne doit pas écraser une position sauvegardée avant l’étape 7.

## 4. Navigation Jour

Trois pages utilisent la même `ScrollView` verticale : précédente, focalisée, suivante.

Le geste horizontal :

- exige une dominance horizontale ;
- anime la page ;
- appelle `moveDay` ;
- remet seulement l’offset horizontal à zéro ;
- précharge les nouveaux voisins.

La `ScrollView` verticale n’est pas recréée et ne reçoit pas de `scrollTo`.

## 5. Initialisation Semaine

1. calculer le premier jour visible ;
2. construire une fenêtre de dates autour de ce jour ;
3. positionner le ruban horizontal ;
4. charger le premier et le cinquième jour pour couvrir la fenêtre ;
5. attendre la fin du chargement ;
6. restaurer `weekTopMinute` si elle existe ;
7. sinon trouver le début le plus tôt parmi les cinq jours et l’aligner en haut ;
8. activer l’enregistrement du scroll utilisateur.

Une géométrie initiale à zéro ne doit pas devenir `weekTopMinute` avant l’étape 8.

## 6. Ruban Semaine

```text
Vertical ScrollView
└── HStack
    ├── TimelineTimeColumn
    └── Horizontal ScrollView
        └── LazyHStack
            ├── WeekDayColumn
            ├── WeekDayColumn
            └── ...
```

Chaque `WeekDayColumn` contient :

```text
WeekDayHeader
TimelineDayBackground
TimelineHourGrid
Course buttons
Current time indicator éventuel
```

Il n’existe pas de second ruban d’en-têtes.

## 7. Extension passée/future

Le tableau de dates possède une marge de préchargement. Lorsqu’une journée visible approche d’un bord :

- préfixer des dates passées ou ajouter des dates futures ;
- conserver les IDs stables ;
- garder `horizontalDayID` comme ancre ;
- ne pas reconstruire la totalité des colonnes ;
- ne pas toucher à `weekTopMinute`.

## 8. Coordonnées

`TimelineAxis` fournit :

- minute depuis minuit ;
- position `y` pour une date ;
- conversion offset → minute ;
- IDs d’ancre par quart d’heure.

Formule :

```text
y = minute × hourHeight / 60
```

La Semaine retire `weekHeaderHeight` avant de convertir son offset vertical en minute.

## 9. Layout des événements

`EventLayoutEngine` :

1. trie par début puis fin ;
2. forme un cluster tant qu’un événement commence avant la fin maximale du cluster ;
3. attribue la première colonne dont la fin est `<= event.start` ;
4. utilise le nombre de colonnes du cluster pour calculer la largeur.

Ainsi, deux cours consécutifs partagent une colonne tandis que deux cours réellement simultanés sont côte à côte.

## 10. Performance

- `LazyHStack`, jamais `HStack` eager pour un grand ruban.
- `Canvas` pour les traits horaires.
- Pas d’observation ou de timer par trait.
- Pas de duplication en-tête/contenu.
- Pas d’écriture UserDefaults à chaque pixel du slider.
- Pas de chargements identiques simultanés.
- Pas de calcul de parsing dans le `body` d’une vue.

## 11. Tests de non-régression

- heure Paris → même `y` dans Jour et Semaine ;
- offset Semaine moins header → minute correcte ;
- `moveDay` ne crée aucune requête verticale ;
- changement de mode préserve les deux minutes ;
- Aujourd’hui crée `.now` ;
- cours consécutifs : `columnCount == 1` ;
- chevauchements réels : colonnes distinctes ;
- premier cours Semaine calculé après chargement.
