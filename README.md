# Coursly

**Coursly** est une application iPhone native en SwiftUI qui simplifie la consultation de l'emploi du temps des étudiants de l'IUT de Vélizy / UVSQ.

> [!NOTE]
> Le projet est en cours de développement. Le dépôt contient actuellement le socle iOS 26, la configuration XcodeGen et la chaîne de distribution d'une IPA non signée ; les fonctionnalités d'emploi du temps sont décrites dans la [feuille de route](docs/PLAN.md) et seront ajoutées progressivement.

## Objectif

Coursly doit permettre de répondre en quelques secondes à quatre questions :

- quel cours ai-je maintenant ?
- quel est le prochain cours ?
- dans quelle salle dois-je aller ?
- à quoi ressemble ma journée ou ma semaine ?

Le MVP prévoit notamment les vues Aujourd'hui et Semaine, le détail d'un cours, la recherche, la sélection de groupe et une Live Activity limitée à l'écran verrouillé. La vision complète est détaillée dans [`docs/PRODUCT.md`](docs/PRODUCT.md).

## État du projet

| Élément | État |
| --- | --- |
| Application SwiftUI native | Socle initial |
| Cible iPhone / iOS 26 | Configurée |
| Génération du projet avec XcodeGen | Configurée |
| Build et empaquetage d'une IPA non signée | Configurés dans GitHub Actions |
| Modèles, clients CELCAT et parsers Swift | À venir |
| Interfaces Aujourd'hui, Semaine et Recherche | À venir |
| Live Activity sur l'écran verrouillé | À venir |

Consultez [`docs/PLAN.md`](docs/PLAN.md) pour l'ordre de réalisation retenu.

## Source des données : POST d'abord

Le POST CELCAT direct est l'unique source de vérité. Le flux iCal n'est utilisé qu'en cas d'échec réel du POST.

```text
POST CELCAT direct
  ├─ réponse exploitable, y compris [] → données POST uniquement
  └─ erreur réseau, HTTP ou parsing    → fallback iCal uniquement
```

Les deux sources ne sont **jamais fusionnées ni utilisées pour se compléter**. Une réponse POST valide contenant `[]` représente une journée vide et ne déclenche pas le fallback. Les groupes visibles dans l'application utilisent des noms lisibles tels que `MMI1-A1` ; les identifiants techniques iCal restent internes.

Pour les règles exhaustives, consultez [`docs/DECISIONS.md`](docs/DECISIONS.md) et [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md).

## Architecture cible

Les vues SwiftUI consomment un modèle métier normalisé et ne parsèrent jamais directement les réponses CELCAT ou iCal.

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

Le réseau, le parsing et la normalisation restent séparés afin de faciliter les tests et de préserver la stratégie de fallback. Voir [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) pour les responsabilités de chaque composant.

## Développer localement

### Prérequis

- macOS avec une version de Xcode prenant en charge iOS 26 et Swift 6 ;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) ;
- Git.

### Générer et ouvrir le projet

Le fichier `.xcodeproj` est généré à partir de [`project.yml`](project.yml) et ne doit pas devenir la source de configuration du projet.

```bash
git clone https://github.com/bastian-noel/Coursly.git
cd Coursly
xcodegen generate
open Coursly.xcodeproj
```

Pour vérifier le build depuis le terminal :

```bash
xcodebuild \
  -project Coursly.xcodeproj \
  -scheme Coursly \
  -configuration Debug \
  -sdk iphonesimulator \
  build
```

Le déploiement cible iOS 26 et le Bundle ID `fr.bastiannoel.coursly` sont définis dans `project.yml`.

## Build et installation

À chaque push de code sur `main`, GitHub Actions doit :

1. générer le projet Xcode avec XcodeGen ;
2. compiler l'application pour un iPhone réel avec la signature désactivée ;
3. empaqueter `Coursly.ipa` ;
4. publier l'IPA dans une GitHub Release ;
5. mettre à jour les métadonnées de distribution de la branche `site` ;
6. rendre la nouvelle version accessible depuis GitHub Pages.

L'IPA produite est volontairement **non signée**. Elle doit être importée dans un sideloader compatible, puis signée avec le certificat et le profil de provisioning de l'utilisateur directement sur l'iPhone.

- Portail de distribution : <https://bastian-noel.github.io/Coursly/>
- Source compatible AltSource : <https://bastian-noel.github.io/Coursly/source.json>
- Détails de la chaîne : [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md)

> [!WARNING]
> Ne commitez jamais de certificat `.p12`, de mot de passe ou de profil `.mobileprovision` privé.

## Branches

- `main` : code iOS, documentation et intégration continue ;
- `site` : GitHub Pages et métadonnées de distribution uniquement.

## Documentation

Avant toute contribution, lisez [`AGENTS.md`](AGENTS.md), puis les documents pertinents :

| Document | Contenu |
| --- | --- |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Décisions non négociables et prioritaires |
| [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) | Contrats CELCAT, POST principal et fallback iCal |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Architecture Swift attendue |
| [`docs/PRODUCT.md`](docs/PRODUCT.md) | Vision, MVP et fonctionnalités cibles |
| [`docs/UX.md`](docs/UX.md) | Hiérarchie visuelle et règles d'interface |
| [`docs/LIVE_ACTIVITY.md`](docs/LIVE_ACTIVITY.md) | Live Activity limitée à l'écran verrouillé |
| [`docs/PLAN.md`](docs/PLAN.md) | Ordre de réalisation |
| [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) | Build, Releases et branche `site` |
| [`docs/CODEX_WORKFLOW.md`](docs/CODEX_WORKFLOW.md) | Découpage et validation des tâches |
| [`docs/reference/README.md`](docs/reference/README.md) | Prototype JavaScript de référence à porter en Swift |

Les fichiers de `docs/reference/` documentent le comportement métier observé dans le prototype. Le portage doit utiliser les API Foundation adaptées, maintenir la séparation réseau/parsing/normalisation et ajouter des tests Swift autour des parsers.

## Licence

Ce projet est distribué sous les termes du fichier [`LICENSE`](LICENSE).
