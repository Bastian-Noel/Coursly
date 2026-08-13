# Architecture iOS proposée

## Cible

- iOS 26
- Swift
- SwiftUI
- Foundation
- ActivityKit pour la Live Activity Lock Screen
- architecture simple, testable et compilable avec `xcodebuild`

## Arborescence recommandée

```text
Coursly/
├── App/
├── Models/
├── Networking/
├── Parsing/
├── Services/
├── Persistence/
├── Features/
│   ├── Today/
│   ├── Week/
│   ├── Search/
│   ├── EventDetail/
│   ├── GroupPicker/
│   └── Settings/
└── LiveActivity/

CourslyTests/
├── DirectParserTests.swift
├── ICalParserTests.swift
├── NormalizerTests.swift
├── CalendarServiceTests.swift
├── MergeRulesTests.swift
└── LiveActivityStateTests.swift
```

## Responsabilités

### CelcatDirectClient

Construit le POST vers `GetCalendarData`, utilise `URLSession`, renvoie les données brutes ou une erreur réseau. Aucun rendu UI.

### DirectEventParser

Décode la réponse CELCAT et produit une représentation structurée intermédiaire.

### CelcatICalClient

Transforme un groupe métier en ID iCal interne puis télécharge le flux. Ne doit jamais être appelé directement par une View.

### ICalParser

Parse VEVENT, UID, SUMMARY, LOCATION, DESCRIPTION, DTSTART/DTEND, lignes repliées, échappements et timezone.

### EventNormalizer

Produit le modèle métier unique `CalendarEvent` et centralise les règles de nettoyage.

### CalendarService

Seul composant autorisé à décider POST ou fallback iCal.

Pseudo-code :

```swift
func events(for group: StudentGroup, interval: DateInterval) async throws -> [CalendarEvent] {
    do {
        let data = try await directClient.fetch(group: group, interval: interval)
        let parsed = try directParser.parse(data)
        return normalizer.normalize(parsed, source: .directPOST)
    } catch {
        let ics = try await iCalClient.fetch(group: group)
        let parsed = try iCalParser.parse(ics, interval: interval)
        return normalizer.normalize(parsed, source: .iCalFallback)
    }
}
```

Important : un POST valide avec `[]` doit retourner `[]`, pas lever une erreur.

## Modèle métier indicatif

```swift
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let type: CourseType?
    let start: Date
    let end: Date
    let rooms: [String]
    let teachers: [String]
    let groups: [StudentGroup]
    let moduleCode: String?
    let moduleName: String?
    let source: EventSource
}
```

## Multi-groupes

1. charger chaque groupe via `CalendarService` ;
2. normaliser ;
3. réunir les événements ;
4. appliquer uniquement ensuite les règles de fusion visuelle.

Une clé de fusion peut comparer titre normalisé, début, fin, salles, enseignants et type. Les groupes peuvent différer et être agrégés.

## Temporalité

Centraliser et tester :

- `currentEvent(at:)`
- `nextEvent(after:)`
- `isFirstCourseOfDay`
- `isLastCourseOfDay`
- `timeUntilStart`
- `timeUntilEnd`
- `shouldShowNextCourse`

## Concurrence

Utiliser `async/await`. Les groupes multiples peuvent être téléchargés en parallèle avec une limite raisonnable.

## Tests essentiels

- succès POST ;
- POST vide ;
- timeout POST → iCal ;
- payload direct invalide → iCal ;
- double échec → erreur finale ;
- parsing accents, plusieurs salles, plusieurs enseignants ;
- fusion et non-fusion multi-groupes ;
- états temporels aux bornes exactes début/fin.