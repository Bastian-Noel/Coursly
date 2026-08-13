# Coursly

Application iOS 26 d'emploi du temps étudiant pour l'IUT de Vélizy / UVSQ.

Le projet valide d'abord une chaîne de développement sans Mac personnel : code dans `main`, build iPhone sur GitHub Actions macOS, IPA non signée dans GitHub Releases, puis signature et installation directement sur l'iPhone.

## Documentation pour Codex / IA

Avant de modifier le projet, lire :

- [`AGENTS.md`](AGENTS.md) — règles générales de travail ;
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — décisions non négociables ;
- [`docs/PRODUCT.md`](docs/PRODUCT.md) — vision produit ;
- [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) — POST CELCAT et fallback iCal ;
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — architecture Swift ;
- [`docs/UX.md`](docs/UX.md) — règles d'interface ;
- [`docs/LIVE_ACTIVITY.md`](docs/LIVE_ACTIVITY.md) — Live Activity Lock Screen uniquement ;
- [`docs/PLAN.md`](docs/PLAN.md) — ordre de réalisation ;
- [`docs/CODEX_WORKFLOW.md`](docs/CODEX_WORKFLOW.md) — découpage des tâches Codex ;
- [`docs/reference/README.md`](docs/reference/README.md) — code MJS de référence à porter en Swift.

## Décision data principale

```text
POST GetCalendarData = source de vérité
        ↓ échec réel uniquement
iCal = fallback
```

Il n'y a jamais de fusion ou de complément POST + iCal. Une réponse POST valide sans événement est une journée vide valide.

## Références MJS

Le dossier `docs/reference/` conserve la logique du prototype JavaScript qui a servi à étudier CELCAT avant le portage natif :

- parsing et normalisation du POST direct ;
- mapping groupes lisibles ↔ IDs iCal internes ;
- stratégie fallback stricte.

Ces fichiers sont des références fonctionnelles : l'app finale doit porter leur comportement vers Swift/Foundation et ajouter les tests correspondants.

## Distribution

Après un push de code sur `main`, GitHub Actions :

1. génère le projet Xcode avec XcodeGen ;
2. compile pour un appareil iOS réel avec la signature désactivée ;
3. crée `Coursly.ipa` ;
4. publie l'IPA dans une GitHub Release ;
5. met à jour `source.json` et `latest.json` sur la branche `site` ;
6. GitHub Pages sert le portail de distribution.

Site :

```text
https://bastian-noel.github.io/Coursly/
```

Source :

```text
https://bastian-noel.github.io/Coursly/source.json
```

## Branches

- `main` : développement iOS, documentation et CI.
- `site` : GitHub Pages et métadonnées de distribution uniquement.

## Bundle ID

```text
fr.bastiannoel.coursly
```

Le Bundle ID doit rester stable afin que les nouvelles builds puissent remplacer l'application précédente après signature sur l'appareil.

## Signature

L'IPA générée par la CI est volontairement non signée. Elle doit être importée dans un sideloader compatible puis signée sur l'iPhone avec le certificat et le provisioning profile de l'utilisateur.