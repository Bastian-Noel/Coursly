# Références de parsing CELCAT

Ce dossier conserve des implémentations JavaScript historiques utilisées pour comprendre les formats CELCAT. Elles servent de documentation exécutable et de matériau de test ; elles ne sont pas exécutées par l’application iOS.

## Fichiers

| Fichier | Rôle historique |
| --- | --- |
| [`direct-celcat-reference.mjs`](direct-celcat-reference.mjs) | requête directe et lecture de la réponse du calendrier |
| [`ical-core-reference.mjs`](ical-core-reference.mjs) | extraction des événements iCal |
| [`fallback-strategy.mjs`](fallback-strategy.mjs) | illustration de la priorité POST puis du fallback |

Le code Swift dans `Coursly/Networking`, `Coursly/Parsing` et `Coursly/Services` est l’implémentation de production et reste la seule autorité technique de l’app.

## Ce qui doit rester équivalent

- compréhension des champs utiles du POST CELCAT ;
- extraction de matière, type, groupe réel, salle et enseignants ;
- gestion des dates dans le fuseau `Europe/Paris` ;
- recours à l’iCal uniquement lorsque le POST échoue réellement ;
- rejet des objets incomplets plutôt que fabrication silencieuse de données.

## Différences volontaires du code Swift

L’implémentation native ajoute notamment :

- une distinction explicite entre groupe de requête et groupe réel du cours ;
- des erreurs typées pour décider du fallback ;
- un modèle `CalendarEvent` normalisé ;
- des identifiants stables et une déduplication multi-groupes ;
- la découverte dynamique des types ;
- l’intégration au cache, à la recherche, aux changements et à la Live Activity.

Une divergence observée entre ces références et CELCAT ne doit pas être copiée aveuglément dans Swift. Ajouter d’abord une fixture anonymisée issue du format réel, écrire un test qui échoue, puis adapter le parseur de production.

## Données sensibles

Ne pas ajouter de réponse contenant noms complets, identifiants privés, cookies, tokens ou emploi du temps personnel non anonymisé. Une fixture doit conserver la structure nécessaire au test avec des valeurs fictives.
