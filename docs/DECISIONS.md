# Décisions de conception — Coursly

Ce document contient les décisions structurantes. Codex ne doit pas les changer implicitement.

## D-001 — POST CELCAT = source de vérité

Endpoint principal :

```text
POST https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData
```

Le POST est plus riche et plus complet que l'iCal. Tant qu'il répond avec un payload exploitable, **seules ses données sont utilisées**.

Une réponse valide contenant zéro événement est un succès.

## D-002 — iCal = fallback strict

Le flux iCal est une roue de secours si le POST échoue réellement : réseau, timeout, statut inutilisable, payload invalide ou parsing impossible.

Interdit :

- fusion POST + iCal ;
- enrichissement du POST par iCal ;
- fallback parce qu'une journée contient 0 cours ;
- comparaison systématique en production pour choisir « le meilleur » événement.

## D-003 — Groupes publics lisibles

L'app manipule publiquement : `MMI1-A1`, `MMI1-A2`, etc.

Les IDs `G1-...` sont strictement internes au client iCal.

## D-004 — Modèle métier unique

Le reste de l'app consomme un modèle normalisé `CalendarEvent` et ne doit pas dépendre du format réseau d'origine.

La provenance (`directPOST`, `iCalFallback`, `local`) peut être conservée pour le debug.

## D-005 — Multi-groupes != fusion de sources

La fusion de cours identiques concerne uniquement plusieurs groupes après normalisation. Elle ne mélange jamais deux sources réseau.

## D-006 — Live Activity Lock Screen uniquement

V1 : présentation Lock Screen uniquement.

Hors scope : Dynamic Island compact, minimal et expanded.

## D-007 — Live Activity = maintenant + après si utile

Elle répond à : quel cours, où, quand, combien de temps avant début/fin, quel type, puis le prochain seulement quand pertinent.

## D-008 — SwiftUI natif

Privilégier SwiftUI, Foundation, ActivityKit et les API Apple. Éviter les dépendances si une API native suffit.

## D-009 — Distribution sans signature CI

`main` compile une IPA non signée sur runner macOS. La signature est effectuée sur l'iPhone par Feather/SideStore/etc.

## D-010 — Branches

- `main` = développement et CI.
- `site` = GitHub Pages + JSON de distribution uniquement.

## D-011 — Bundle ID stable

Une fois choisi, le Bundle ID reste stable pour permettre les mises à jour. `CFBundleVersion` augmente à chaque build distribuée.