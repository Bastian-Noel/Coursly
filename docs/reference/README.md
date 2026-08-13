# Références JavaScript / MJS pour le portage Swift

Ce dossier conserve la logique du prototype CELCAT utilisé avant l'implémentation native iOS.

Ces fichiers ne doivent pas être exécutés dans Coursly. Ils servent à Codex comme référence de comportement lors du portage vers Foundation/Swift.

## Fichiers

- `direct-celcat-reference.mjs` : mapping des groupes, requête POST, parsing de la description CELCAT, parsing module, catégories et normalisation de la source principale.
- `ical-core-reference.mjs` : noyau du parsing VEVENT/UID/SUMMARY/LOCATION/DESCRIPTION/DTSTART/DTEND et normalisation iCal de secours.
- `fallback-strategy.mjs` : règle POST-first stricte et fallback iCal uniquement sur erreur.

## Sources historiques étudiées

Le prototype est issu de l'étude de :

- `Bastian-Noel/edtvelizyics` : parsing enrichi des événements CELCAT et reconstruction ICS propre.
- `mmi-place/celcat-back` : POST direct avec fallback sur un flux iCal.

## Règle de portage

Ne pas faire une traduction ligne à ligne. Conserver les comportements métier et remplacer les mécanismes JavaScript par les API Swift adaptées.

Correspondances recommandées :

- `fetch` → `URLSession`
- `URLSearchParams` → corps `application/x-www-form-urlencoded`
- objets JS → `struct Codable`
- `Date` JS → `Foundation.Date`
- mapping `GROUPS` → `enum StudentGroup`
- `eventCategoryToTag` → `CourseType` / normalizer
- `parseCelcatDescription` → `DirectEventParser`
- `parseModuleFromBlock` → fonction testable pure
- parser VEVENT → `ICalParser`
- stratégie `try POST / catch iCal` → `CalendarService`

## Tests Swift à écrire avant de considérer le portage terminé

- description avec un enseignant ;
- plusieurs enseignants ;
- `(N more...)` ;
- plusieurs salles ;
- module avec code entre crochets ;
- CM, TD, TP, projet, DS, examen ;
- POST vide sans fallback ;
- POST en erreur avec fallback ;
- iCal avec lignes repliées ;
- dates UTC et Europe/Paris ;
- accents et caractères HTML/iCal échappés.

## Point à vérifier sur la nouvelle instance CELCAT

Le prototype utilise `start=date` et `end=date` car c'est le comportement repris des projets existants. Si une instance CELCAT traite `end` comme une borne exclusive, tester `end = lendemain` avant de modifier le reste du parser.

## Limite iCal connue

Le prototype maison ne développe pas `RRULE`/`RECURRENCE-ID`. Si le flux réel en contient, l'implémentation Swift doit ajouter la gestion des récurrences ou utiliser une stratégie adaptée.

## Important

Le fichier iCal de référence est volontairement plus minimal que le parser final attendu. Pour le port Swift, Foundation doit gérer correctement les timezones, notamment `Europe/Paris`, et les tests doivent couvrir les changements d'heure.