# Workflow avec Codex

## Avant toute tâche

Lire `AGENTS.md`, `docs/DECISIONS.md` et les docs pertinentes au sujet.

## Format de tâche recommandé

Chaque tâche doit préciser : objectif, périmètre, non-objectifs, règles métier, critères d'acceptation et tests.

## Exemple data

Objectif : charger les cours d'un groupe via le POST CELCAT.

Règles : POST source de vérité, groupe lisible côté métier, aucun ID `G1-...` dans l'UI, réponse vide valide.

Acceptation : réponse normalisée en `CalendarEvent`, erreurs typées, tests unitaires.

## Exemple fallback

Objectif : ajouter iCal comme fallback strict.

Acceptation : POST succès ou vide n'appelle jamais iCal ; erreur POST appelle iCal ; aucune fusion.

## Exemple Live Activity

Lire la spécification produit et ne créer qu'une vue Lock Screen. Ne pas ajouter Dynamic Island.

## Compte-rendu attendu de Codex

À la fin :

1. résumé des changements ;
2. fichiers modifiés ;
3. tests exécutés ;
4. ce qui n'a pas pu être testé ;
5. hypothèses réseau/CELCAT ;
6. confirmation des décisions respectées.

## Découpage

Préférer plusieurs petites tâches testables : modèles → client POST → parser → normalizer → fallback → Today, plutôt qu'un prompt « crée toute l'app ».

## Environnement

Le code peut être modifié depuis Linux/Windows/Codespaces. Les validations Xcode finales passent par GitHub Actions macOS. Ne jamais prétendre qu'une IPA fonctionne sur iPhone si elle n'a pas été compilée et testée dans l'environnement adapté.