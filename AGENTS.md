# AGENTS.md — Instructions Codex pour Coursly

## Mission

Construire **Coursly**, une application iPhone native Swift/SwiftUI pour iOS 26 dédiée à l'emploi du temps étudiant de l'IUT de Vélizy / UVSQ.

Avant toute modification importante, lire ce fichier puis les documents pertinents dans `docs/`.

## Ordre de priorité

1. `docs/DECISIONS.md` — décisions non négociables.
2. `docs/DATA_SOURCES.md` — règles CELCAT, POST principal et fallback iCal.
3. `docs/ARCHITECTURE.md` — architecture Swift attendue.
4. `docs/PRODUCT.md` — vision produit et fonctionnalités.
5. `docs/UX.md` — règles d'interface.
6. `docs/LIVE_ACTIVITY.md` — Live Activity Lock Screen uniquement.
7. `docs/PLAN.md` — ordre de réalisation.
8. `docs/DISTRIBUTION.md` — build, Releases et branche `site`.
9. `docs/CODEX_WORKFLOW.md` — façon de découper les tâches.
10. `docs/reference/README.md` et les fichiers `.mjs` — référence JavaScript du prototype à porter en Swift.

En cas de contradiction, `docs/DECISIONS.md` prévaut.

## Règles absolues sur les données

- Le **POST CELCAT direct** est la source de vérité.
- Le flux **iCal est uniquement un fallback** en cas d'échec réel du POST.
- Ne jamais fusionner, compléter ou corriger les données POST avec iCal.
- Une réponse POST valide contenant `[]` est une journée vide valide et ne déclenche pas le fallback.
- Les noms lisibles comme `MMI1-A1` sont les identifiants publics de l'app.
- Les identifiants `G1-...` sont internes au fallback iCal et ne doivent jamais apparaître dans l'UI.

## Référence de portage Swift

Le dossier `docs/reference/` contient le prototype Node/JavaScript de référence pour le portage iOS.

Lors du portage :

- conserver le comportement métier ;
- ne pas traduire mécaniquement ligne par ligne si Foundation offre une meilleure API ;
- écrire des tests Swift autour des parsers ;
- conserver les cas limites documentés ;
- utiliser `URLSession`, `Codable`, `Date`, `ISO8601DateFormatter` et les API Foundation appropriées ;
- garder réseau, parsing et normalisation séparés.

## Architecture

Les Views SwiftUI ne doivent jamais parser CELCAT ni iCal directement.

```text
View
  ↓
ViewModel / Store
  ↓
CalendarService
  ├── CelcatDirectClient
  └── CelcatICalClient (fallback uniquement)
        ↓
Parsers
        ↓
EventNormalizer
        ↓
CalendarEvent
```

## Live Activity

Pour la V1 : **Lock Screen uniquement**. Ne pas implémenter Dynamic Island compact, minimal ou expanded.

## UI

Priorité : matière, salle, horaires, type CM/TD/TP/Examen, groupe, puis enseignant en information secondaire.

## Build et distribution

- `main` = code de développement et documentation.
- `site` = GitHub Pages et métadonnées de distribution uniquement.
- Un changement de code sur `main` doit produire une IPA iPhone non signée via GitHub Actions.
- L'IPA est publiée dans GitHub Releases.
- `site/source.json` et `site/latest.json` sont mis à jour automatiquement.
- La signature finale est faite sur l'iPhone par le sideloader.

Ne jamais committer de certificat `.p12`, mot de passe ou `.mobileprovision` privé.

## Avant de terminer une tâche

Vérifier autant que possible : compilation, tests, absence de régression POST-first, aucune exposition de `G1-...` dans l'UI, aucune Dynamic Island ajoutée, documentation mise à jour si une décision change.

Si Xcode ou un iPhone réel n'est pas disponible, l'indiquer clairement dans le compte-rendu.