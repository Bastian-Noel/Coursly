# Architecture iOS

## 1. Cible technique

- iOS 26 ;
- Swift 6 ;
- SwiftUI et Observation ;
- Foundation / URLSession ;
- ActivityKit ;
- UserNotifications ;
- XcodeGen comme source de configuration projet.

## 2. Vue d’ensemble

```text
CourslyApp
   ↓
RootView
   ↓
CalendarScene
   ↓
CalendarStore @Observable @MainActor
   ├── CalendarService
   ├── SearchEngine
   ├── ChangeDetectionService
   ├── PersistenceServices
   ├── NotificationService
   └── LiveActivityManager
```

`CalendarStore` orchestre l’état de présentation et les services. Il ne parse pas directement les payloads.

## 3. Pipeline réseau

```text
CalendarStore.load
   ↓
CalendarService.load(groups, interval)
   ↓ par groupe
CalendarService.fetch
   ├── CelcatDirectClient → DirectEventParser → directPOST
   └── sur erreur seulement
       CelcatICalClient → ICalParser → iCalFallback
   ↓
mergeVisualDuplicates
   ↓
CalendarLoadResult
```

`CalendarLoadResult` sépare :

- les événements destinés à l’affichage ;
- les événements POST directs indexés par groupe ;
- les groupes en fallback ;
- les groupes en erreur.

## 4. Modèle normalisé

`CalendarEvent` porte :

- identité, titre, type normalisé et libellé dynamique ;
- dates réelles de début et fin ;
- salles et enseignants ;
- groupes de requête ;
- groupes réels CELCAT ;
- module ;
- provenance.

Les propriétés `displayTypeLabel` et `displayGroupLabels` centralisent les règles d’affichage. Les vues ne reconstruisent pas ces valeurs.

`CourseTypeClassifier` applique une liste ordonnée de regex configurables. Son résultat `CourseType` est une clé interne de regroupement et de couleur ; `displayTypeLabel` conserve toujours le libellé CELCAT. Les règles invalides ou désactivées ne classent aucun événement.

## 5. État du calendrier

Les axes suivants sont indépendants :

| État | Responsabilité |
| --- | --- |
| `focusedDate` | date de navigation horizontale |
| `displayMode` | Jour ou Semaine |
| `dayTopMinute` | position verticale mémorisée du Jour |
| `weekTopMinute` | position verticale mémorisée de la Semaine |
| `dateNavigationToken` | demande explicite de navigation de date |
| `timelineScrollRequest` | recentrage vertical explicite seulement |
| `loadedIntervals` | couverture des données réseau |

Un `moveDay` ne crée pas de `timelineScrollRequest`. `CalendarStore.load` ne décide jamais d’une position visuelle.

Les chargements concurrents sont sérialisés avec `activeLoadTask`. Une vue attend `ensureLoaded` avant son positionnement initial.

## 6. Timeline

```text
TimelineGeometry.swift
   ├── TimelineAxis
   ├── TimelineMetrics
   ├── EventLayoutEngine
   ├── TimelineHourGrid
   ├── TimelineTimeColumn
   └── indicateur de temps courant

DayTimelineView.swift
   └── pager horizontal dans un scroll vertical

WeekTimelineView.swift
   └── colonne horaire fixe + LazyHStack de WeekDayColumn

TimelineCourseCard.swift
   └── densités micro / compact / regular
```

`TimelineAxis` est l’unique conversion date/minute/position. Jour et Semaine ne possèdent pas de formule locale divergente.

Le scroll vertical utilise une `ScrollPosition` numérique. `TimelineVerticalScrollState` ignore les mesures transitoires tant que l’offset demandé n’a pas été réellement observé ; une première géométrie à zéro ne peut donc pas écraser la restauration.

La grille utilise `Canvas` afin de réduire le nombre de vues. Les calques décoratifs désactivent le hit testing.

## 7. Navigation Semaine

- La colonne horaire est extérieure au scroll horizontal.
- Une `WeekDayColumn` contient son en-tête et sa timeline.
- Le ruban utilise `LazyHStack`.
- La fenêtre initiale est étendue près des bords.
- `scrollPosition` et `viewAligned` fournissent le magnétisme.
- Le changement de journée déclenche un préchargement, pas un recentrage vertical.

## 8. Cartes et chevauchements

`EventLayoutEngine` regroupe les événements qui se chevauchent et attribue la première colonne libre. Un événement dont le début est égal à la fin du précédent réutilise sa colonne.

La largeur d’une voie dépend du nombre maximal de colonnes du cluster. Le bord inférieur retire `courseBottomGap` pour distinguer deux cours consécutifs.

`CoursePressButtonStyle` gère le feedback de pression sans remplacer l’action du `Button`.

## 9. Recherche

`SearchEngine` construit ses facettes depuis les événements normalisés :

- matières, enseignants, salles ;
- groupes réels affichés ;
- libellés de type dynamiques ;
- modules.

Les filtres ne reposent pas uniquement sur `CourseType`.

## 10. Changements et persistance

```text
refresh explicite
   ↓
directEventsByGroup
   ↓
DirectSnapshotStore
   ↓
ChangeDetectionService
   ↓
ChangeHistoryStore
   ↓
NotificationService
```

Événements iCal et personnels sont exclus des snapshots de comparaison.

## 11. Temps logique

```text
effectiveNow(systemDate)
   = systemDate + simulationOffset si simulation active
```

Toute règle temporelle demande `store.now` ou `effectiveNow`. Les propriétés `CalendarEvent.start/end` ne sont pas mutées.

## 12. Live Activity

`LiveActivityManager` reçoit les événements normalisés du jour logique, choisit un état et construit `CourslyActivityAttributes.ContentState`.

- `start/end` : horaires réels affichés ;
- `timerStart/timerEnd` : dates translatées pour les timers ActivityKit ;
- `groups` : `displayGroupsText` ;
- `accentHex` : préférence dynamique du type.

L’extension ne connaît ni `CalendarStore` ni les clients CELCAT.

## 13. Arborescence

```text
Coursly/
├── App/
├── Models/
│   └── CourseTypeRule.swift
├── Networking/
├── Parsing/
├── Services/
├── Features/
│   ├── RootView.swift
│   └── Calendar/
└── LiveActivity/

Shared/
└── CourslyActivityAttributes.swift

CourslyLiveActivity/
└── CourslyLiveActivityBundle.swift

CourslyTests/
```

## 14. Frontières à préserver

- pas de parsing dans les vues ;
- pas de réseau dans la Live Activity ;
- pas de recentrage dans le service de chargement ;
- pas de groupe de requête utilisé comme libellé UI par défaut si un groupe réel existe ;
- pas de source iCal dans les snapshots ;
- pas d’état horizontal dupliqué entre en-tête et contenu Semaine.
