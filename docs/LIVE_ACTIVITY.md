# Activité en direct — V3

L'Activité en direct représente la journée et reçoit uniquement des `CalendarEvent` normalisés. Elle n'appelle jamais CELCAT.

## États

- `PREMIER COURS` avant le premier cours ;
- `PROCHAIN COURS` entre deux cours ;
- `EN COURS` pendant un cours ;
- `BIENTÔT TERMINÉ` dans les 20 dernières minutes si un cours suit ;
- `DERNIER COURS` pour le dernier cours ;
- `JOURNÉE TERMINÉE` avant la fermeture.

## Lock Screen

Priorités : état, compte à rebours, matière, type, salle, horaires, progression, puis prochain cours seulement si utile.

## Contrôles

Réglages contient : activation globale, état autorisé/actif, `Réafficher l'activité`, `Terminer l'activité actuelle`.

Si l'utilisateur retire l'activité, Coursly peut en demander une nouvelle lorsqu'il est ouvert et qu'ActivityKit l'autorise.

## Dynamic Island

Le design produit reste centré sur le Lock Screen. Une présentation minimale est fournie pour les surfaces système où iOS décide d'afficher la Live Activity.
