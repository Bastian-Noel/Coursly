# AGENTS.md — Coursly

## Projet

Coursly est une application iPhone native SwiftUI pour consulter l'emploi du temps étudiant de l'IUT de Vélizy / UVSQ.

## Priorité actuelle

Avant de développer l'emploi du temps, valider complètement la chaîne de distribution :

```text
push main
→ GitHub Actions macOS
→ build iOS non signée
→ Coursly.ipa
→ GitHub Pages
→ signature sur l'iPhone
→ installation
```

## Règles générales

- Cible : iOS 26.
- Langage : Swift.
- Interface : SwiftUI.
- Privilégier les frameworks Apple natifs.
- Le projet doit rester compilable en ligne de commande avec `xcodebuild`.
- La CI ne contient aucun certificat, `.p12` ou provisioning profile.
- L'IPA de CI est volontairement produite sans signature et sera signée sur l'appareil.
- Bundle ID : `fr.bastiannoel.coursly`.
- Conserver ce Bundle ID stable.
- Le numéro de build doit augmenter à chaque build distribuée.

## Données calendrier — décisions déjà prises

- `POST https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData` sera la source de vérité.
- iCal sera uniquement un fallback en cas d'échec réel du POST.
- Ne jamais fusionner POST et iCal pour compléter un cours.
- Une réponse POST valide avec zéro événement ne déclenche pas le fallback.
- Les noms lisibles (`MMI1-A1`, etc.) sont les identifiants publics.
- Les IDs `G1-...` restent internes à la récupération iCal.

## Live Activities

Pour la première version, développer uniquement la présentation Lock Screen.

Ne pas implémenter de vues Dynamic Island compact/minimal/expanded tant que cette décision n'a pas changé explicitement.

## Avant de terminer une tâche

- vérifier les tests pertinents ;
- vérifier la build dans GitHub Actions si la tâche touche le projet Xcode ;
- ne pas prétendre qu'une installation iPhone est validée tant qu'elle n'a pas réellement été testée sur l'appareil ;
- documenter toute hypothèse importante.
