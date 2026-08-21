# Architecture iOS — V3

## Cible

- iOS 26
- Swift 6
- SwiftUI
- Foundation
- ActivityKit
- UserNotifications

## Flux de données

```text
CalendarStore
   ↓
CalendarService
   ↓
POST CELCAT
   ├─ succès, même [] → DirectEventParser → événements directs
   └─ échec réel      → iCal → ICalParser → événements fallback
   ↓
normalisation / fusion multi-groupes
   ↓
CalendarScene
```

## Synchronisation et changements

```text
CalendarStore.load
   ↓
CalendarService.load
   ↓
GroupCalendarResult
   ├─ directPOST → DirectSnapshotStore → ChangeDetectionService
   └─ iCal       → affichage uniquement, aucun snapshot de diff
   ↓
ChangeHistoryStore
   ↓
NotificationService
```

## Organisation V3

```text
Coursly/
├── App/
├── Models/
├── Networking/
├── Parsing/
├── Services/
│   ├── CalendarService.swift
│   ├── ChangeDetectionService.swift
│   ├── PersistenceServices.swift
│   ├── SearchEngine.swift
│   ├── NotificationService.swift
│   └── HapticService.swift
├── Features/
│   ├── RootView.swift
│   └── Calendar/
│       ├── TimelineViews.swift
│       ├── FloatingPanels.swift
│       ├── CourseDetailSheet.swift
│       ├── SettingsSheet.swift
│       └── LocalEventSheet.swift
└── LiveActivity/
```

## Invariants

- les Views n'appellent jamais les clients CELCAT ;
- un POST `[]` est un succès ;
- aucune fusion POST+iCal ;
- les IDs `G1-...` restent internes ;
- les événements locaux ne participent pas au diff CELCAT ;
- les snapshots de changement ne contiennent que du POST direct.
