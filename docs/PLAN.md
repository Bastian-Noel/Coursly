# Plan de réalisation — V3

La V3 est la direction active de Coursly. Voir `docs/V3.md`.

## État d’implémentation

Les blocs fonctionnels V3 sont désormais implémentés dans `main` :

- [x] modèles V3 : changements, mode Jour/Semaine, politique week-end ;
- [x] CalendarService enrichi avec provenance par groupe et snapshots POST directs ;
- [x] CalendarStore unique : calendrier, simulation, groupes, recherche, changements, notifications et activité en direct ;
- [x] timeline 24 h, ligne rouge, centrage sur maintenant et navigation horizontale entre jours ;
- [x] layout adaptatif des cours et gestion des chevauchements ;
- [x] mode Semaine comme état de la même `CalendarScene` ;
- [x] contrôles Liquid Glass flottants et panneaux contextuels ;
- [x] recherche à facettes dynamique : matières, profs, salles, groupes, types, modules ;
- [x] nouveau détail de cours ;
- [x] événements personnels locaux ;
- [x] `ChangeDetectionService` : ajouté / supprimé / déplacé / modifié ;
- [x] notifications locales avec horizon configurable et sélection des types de changement ;
- [x] activité en direct V3 : Premier cours / Pause / En cours / Dernier cours / Journée terminée ;
- [x] activation globale et bouton de réaffichage de l’activité en direct ;
- [x] haptics centraux ;
- [x] tests parser, fallback, matching de changement et recherche ;
- [x] CI : tests avant compilation et publication uniquement depuis `main`.

## Validation restante

La validation finale est matérielle : installer l’IPA `0.3.x` sur un iPhone iOS 26 et vérifier le rendu réel du Liquid Glass, les gestes, les haptics, les notifications et l’activité en direct sur le Lock Screen.

Les corrections issues de ce test réel restent dans la série `0.3.x`.

## Règle CI

`project.yml` porte la série `0.3.0`. La CI produit ensuite `0.3.1`, `0.3.2`, etc. Le compteur repartira à 1 pour `0.4.0`.
