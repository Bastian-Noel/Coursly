# Plan de réalisation — V3

La V3 est la direction active de Coursly. Voir `docs/V3.md`.

## Implémentation

1. Modèles V3 : changements, états d'affichage, politique week-end.
2. CalendarService enrichi avec provenance par groupe et snapshots POST directs.
3. CalendarStore unique : calendrier, simulation, groupes, cache local, recherche, changements, notifications et Live Activity.
4. Timeline 24 h, ligne rouge, centrage sur maintenant et navigation horizontale entre jours.
5. Layout adaptatif des cours et gestion des chevauchements.
6. Mode semaine comme état de la même CalendarScene.
7. Contrôles Liquid Glass flottants et panneaux contextuels.
8. Recherche à facettes dynamique.
9. Nouveau détail de cours.
10. Événements personnels locaux.
11. ChangeDetectionService : ajouté / supprimé / déplacé / modifié.
12. Notifications locales configurables, horizon 7 jours par défaut.
13. Live Activity V3, toggle global, réaffichage et fin manuelle.
14. Haptics et accessibilité.
15. Tests métier et validation sur iPhone réel.

## Règle CI

`project.yml` porte la série `0.3.0`. La CI produit ensuite `0.3.1`, `0.3.2`, etc. Le compteur repartira à 1 pour `0.4.0`.
