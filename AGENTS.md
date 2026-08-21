# AGENTS.md — Instructions Codex pour Coursly

## Mission

Construire **Coursly**, application iPhone native Swift/SwiftUI iOS 26 pour l'emploi du temps de l'IUT de Vélizy / UVSQ.

La direction active est **Coursly V3**. Avant une modification importante, lire ce fichier puis `docs/V3.md`.

## Ordre de priorité

1. `docs/DECISIONS.md` — décisions non négociables.
2. `docs/DATA_SOURCES.md` — POST source de vérité, iCal fallback.
3. `docs/V3.md` — contrat produit/UX actif.
4. `docs/ARCHITECTURE.md` — architecture Swift V3.
5. `docs/PRODUCT.md` — vision produit.
6. `docs/UX.md` — règles d'interface.
7. `docs/LIVE_ACTIVITY.md` — Activité en direct V3.
8. `docs/PLAN.md` — ordre de réalisation.
9. `docs/DISTRIBUTION.md` et `docs/CODEX_WORKFLOW.md`.
10. `docs/reference/README.md` et les `.mjs` — référence JavaScript du comportement CELCAT à porter en Swift.

En cas de contradiction sur les sources de données, `docs/DECISIONS.md` et `docs/DATA_SOURCES.md` prévalent. Pour l'UX, `docs/V3.md` prévaut sur les anciennes descriptions V1/V2.

## Règles absolues sur les données

- **POST CELCAT direct = source de vérité.**
- **iCal = fallback strict**, seulement si le POST échoue réellement.
- Ne jamais fusionner ou compléter POST avec iCal.
- Un POST valide `[]` est un succès et peut signifier zéro cours.
- Les noms `MMI...` sont publics ; les IDs `G1-...` sont internes et interdits dans l'UI.
- La détection de changements compare uniquement des snapshots POST directs.
- Un groupe en fallback iCal peut être affiché mais son snapshot POST précédent ne doit pas être écrasé.

## Référence de portage Swift

`docs/reference/` contient les `.mjs` de référence. Conserver le comportement métier mais utiliser les APIs Swift/Foundation adaptées : `URLSession`, `Codable`, `Date`, `ISO8601DateFormatter`, `async/await`.

Réseau, parsing, normalisation, synchronisation et UI restent séparés.

## Architecture V3

```text
CalendarScene
   ↓
CalendarStore
   ↓
CalendarService
   ├── CelcatDirectClient
   └── CelcatICalClient (fallback uniquement)
   ↓
Parsers / modèles normalisés
   ↓
Cache / snapshots / change engine / notifications / Live Activity
```

Les Views ne parsèrent jamais CELCAT et n'appellent jamais les clients réseau directement.

## UI V3

- une seule CalendarScene plein écran ;
- timeline 00:00 → 00:00 ;
- swipe jour précédent/suivant ;
- week-ends intelligents ;
- Jour/Semaine = états de la même vue ;
- heure actuelle en rouge ;
- cours simultanés côte à côte ;
- carte adaptative avec début en haut à gauche et fin en bas à gauche ;
- recherche à facettes dynamique ;
- contrôles Liquid Glass flottants ;
- interface visible en français ;
- haptics significatifs et accessibilité.

## Activité en direct

Le design principal reste le Lock Screen et représente la journée. Réglages doit permettre activation globale, réaffichage et fin manuelle. Une présentation Dynamic Island minimale peut exister car iOS peut afficher une Live Activity sur ses surfaces système ; ne pas en faire une seconde expérience complexe.

## Build et distribution

- `main` = code et docs ;
- `site` = GitHub Pages et métadonnées ;
- push de code sur `main` → IPA non signée via GitHub Actions ;
- version source `0.<version>.0`, build publié `0.<version>.<build>` ;
- `0.3.0` produit `0.3.1`, `0.3.2`, etc. ;
- ne jamais committer `.p12`, mot de passe ou provisioning profile privé.

## Avant de terminer

Vérifier : compilation CI, absence de régression POST-first, POST `[]`, multi-groupes, fallback strict, aucune exposition `G1-...`, recherche dynamique, changements sans faux diff iCal, versioning et docs à jour.
