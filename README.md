# Ora

![iOS 26](https://img.shields.io/badge/iOS-26-000000?logo=apple)
[![Build](https://github.com/Bastian-Noel/Coursly/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/Bastian-Noel/Coursly/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/Bastian-Noel/Coursly?include_prereleases)](https://github.com/Bastian-Noel/Coursly/releases)

Ora est une application SwiftUI native qui affiche l’emploi du temps CELCAT de l’IUT de Vélizy.

## Fonctions

- vues Jour et Semaine avec positionnement horaire réel ;
- groupes CELCAT hiérarchiques ;
- recherche et événements personnels ;
- couleurs dynamiques et regroupements par expressions régulières ;
- notifications de changements ;
- Live Activity sur l’écran verrouillé ;
- simulation de date et d’heure.

## Installation

Télécharge la dernière [IPA non signée](https://github.com/Bastian-Noel/Coursly/releases), puis signe-la directement sur l’iPhone avec Feather ou un outil équivalent.

## Développement

Prérequis : Xcode 26 et XcodeGen.

```bash
xcodegen generate
open Ora.xcodeproj
```

La branche `main` contient Ora. La branche `site` contient les fichiers de distribution. GitHub Actions teste, compile et publie automatiquement chaque version fusionnée dans `main`.

## Documentation

La documentation technique et produit tient dans [docs/README.md](docs/README.md).

## Licence

[GNU GPL v3](LICENSE)
