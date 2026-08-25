# Instructions de contribution à Coursly

## Mission

Coursly est une application iPhone native Swift 6 / SwiftUI pour iOS 26. Elle affiche l’emploi du temps CELCAT de l’IUT de Vélizy / UVSQ et distribue une IPA non signée destinée à être signée sur l’appareil.

Avant toute modification, lire [`docs/README.md`](docs/README.md), puis les documents associés au périmètre.

## Règles absolues

### Données

- Le POST CELCAT direct est la source de vérité.
- L’iCal est un fallback strict par groupe, uniquement après un échec réel du POST.
- Un POST valide `[]` est un succès.
- Ne jamais fusionner, enrichir ou comparer POST et iCal pour construire l’affichage.
- Les snapshots de changements proviennent uniquement du POST direct.
- Les IDs iCal `G1-...` restent internes.
- Conserver séparément groupe de requête et groupe réel du cours.

### Timeline

- Jour et Semaine utilisent les mêmes coordonnées temporelles.
- Date horizontale, position verticale et chargement réseau sont indépendants.
- Un swipe ou un préchargement ne recentre jamais la timeline.
- Le premier affichage attend la fin du chargement utile avant de se positionner.
- Ne pas recréer une synchronisation entre deux `ScrollView` horizontales.
- Ne pas réintroduire un ruban Semaine eager contenant des centaines de grilles complètes.

### Interface

- Toute l’interface visible est en français.
- Les contrôles du bas flottent et une réserve de scroll protège les cours.
- Les cartes n’affichent pas le code module.
- Les cartes utilisent le groupe réel CELCAT lorsqu’il existe.
- La couleur ne constitue jamais la seule information du type.
- Un cours passé conserve la hue de son type.
- Le jour actuel n’est jamais assombri.

### Temps simulé

- Toute décision temporelle utilise le temps logique.
- Les horaires CELCAT affichés restent les horaires réels du cours.
- Les timers ActivityKit peuvent être translatés ; les champs `start` et `end` ne le sont pas.

### Live Activity

- L’expérience produit cible le Lock Screen.
- Elle reçoit des `CalendarEvent` normalisés et n’appelle jamais CELCAT.
- Ne pas ajouter une seconde expérience Dynamic Island sans décision produit explicite.

## Architecture attendue

```text
CalendarScene
   ↓
CalendarStore
   ↓
CalendarService
   ├── CelcatDirectClient
   └── CelcatICalClient · fallback strict
   ↓
Parsers → CalendarEvent normalisé
   ↓
UI · cache · changements · notifications · Live Activity
```

Les vues n’appellent pas les clients réseau et ne parsèrent pas les réponses CELCAT.

## Méthode de modification

1. Partir de `main` à jour sur une branche dédiée.
2. Écrire les critères d’acceptation et les risques de régression.
3. Modifier le bon module ; éviter les fichiers monolithiques et les correctifs croisés.
4. Ajouter les tests unitaires des invariants concernés.
5. Ouvrir une PR vers `main`.
6. Attendre la CI Xcode 26 entièrement verte.
7. Fusionner seulement après validation.
8. Vérifier le pipeline `main` lorsqu’une distribution est déclenchée.

## Validation minimale avant livraison

- POST `[]` sans appel iCal ;
- échec POST avec fallback, sans fusion ;
- groupe réel et groupe de requête préservés ;
- multi-groupes sans duplication visuelle ;
- cours consécutifs non placés en parallèle ;
- aucun recentrage vertical lors d’une navigation normale ;
- simulation cohérente ;
- aucune donnée privée dans Git ;
- compilation et tests Xcode 26 ;
- documentation mise à jour.

Ne jamais déclarer un rendu iPhone validé uniquement parce que la CI compile. La validation matérielle est une étape distincte.
