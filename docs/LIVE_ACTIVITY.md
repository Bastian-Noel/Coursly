# Live Activity — V1

La V1 de Coursly utilise uniquement la Live Activity du Lock Screen. Ne pas implémenter la Dynamic Island.

Priorités : matière, salle, horaires, état temporel, type de cours, prochain cours seulement si utile.

États :

- `PREMIER COURS` avant le premier cours ;
- `PROCHAIN COURS` entre deux cours ;
- `EN COURS` pendant un cours ;
- afficher `Ensuite` en fin de cours si un prochain cours existe ;
- `DERNIER COURS` pour le dernier cours ;
- `Journée terminée` à la fin avant fermeture de l'activité.

La Live Activity reçoit uniquement des événements normalisés. Elle ne doit jamais appeler CELCAT directement et ne doit connaître ni le POST, ni l'iCal, ni les IDs `G1-...`.

Le temps restant et la progression doivent être dérivés des dates autant que possible, pas stockés comme valeurs statiques.

Interaction V1 : tap sur l'activité pour ouvrir Coursly, idéalement sur le détail du cours.

Règle de design : `MAINTENANT + TEMPS + OÙ + APRÈS seulement quand utile`.