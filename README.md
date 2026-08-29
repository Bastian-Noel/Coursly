# Ora

![iOS 26](https://img.shields.io/badge/iOS-26-000000?logo=apple)

Ora est une application SwiftUI native pour consulter l’emploi du temps CELCAT de l’IUT de Vélizy.

## Fonctionnalités

- vues Jour et Semaine ;
- groupes CELCAT hiérarchiques ;
- recherche et événements personnels ;
- couleurs et regroupements regex dynamiques ;
- notifications et Live Activity ;
- simulation de date et d’heure.

## Installation

Télécharge la dernière [IPA non signée](../../releases), puis signe-la directement sur l’iPhone avec Feather ou un outil équivalent.

## Développement

Prérequis : Xcode 26 et XcodeGen.

```bash
xcodegen generate
open Ora.xcodeproj
```

Les changements sont intégrés dans `main`. La distribution est publiée automatiquement après les tests et le build iPhone.

La documentation technique se trouve dans [docs/README.md](docs/README.md).

## Licence

[GNU GPL v3](LICENSE)
