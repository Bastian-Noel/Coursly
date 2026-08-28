# Live Activity — spécification Lock Screen

## 1. Périmètre

La Live Activity répond à la situation immédiate de l’étudiant sur le Lock Screen. Elle ne charge aucune donnée et ne constitue pas une seconde application.

La Dynamic Island n’est pas une expérience produit active. Le code requis par `ActivityConfiguration` doit rester minimal et ne pas introduire de hiérarchie fonctionnelle distincte.

## 2. Entrée

`LiveActivityManager` reçoit :

- les `CalendarEvent` normalisés du jour logique ;
- le temps logique courant ;
- l’état d’activation ;
- les couleurs personnalisées des types.

Le groupe affiché est `displayGroupsText`, jamais automatiquement `groups`.

## 3. États

| État | Condition | Décompte |
| --- | --- | --- |
| `PREMIER COURS` | avant le premier cours | jusqu’au début |
| `PAUSE` | entre deux cours | jusqu’au prochain |
| `EN COURS` | cours actuel, plus de 20 min restantes si un cours suit | jusqu’à la fin |
| `BIENTÔT TERMINÉ` | 20 dernières minutes et un cours suit | jusqu’à la fin |
| `DERNIER COURS` | cours actuel sans cours suivant | jusqu’à la fin |
| `JOURNÉE TERMINÉE` | aucun cours restant | état final temporaire |

Le prochain cours pendant un cours en cours n’apparaît que dans les 30 dernières minutes.

## 4. Hiérarchie Lock Screen

Ordre visuel :

1. état temporel en haut à gauche ;
2. décompte en haut à droite ;
3. horaires réels compacts et centrés ;
4. matière ;
5. type, salle, enseignants et groupe réel sans surcharge d’icônes ;
6. barre de progression ;
7. bloc « prochain cours » en bas avec matière, heure et salle lorsqu’il est utile.

La surface reprend la DA des cartes Semaine : rectangle teinté, bande verticale et accents utilisant la couleur personnalisée du type. Aucun faux bouton n’est affiché tant qu’une route d’ouverture de cours testable n’existe pas.

## 5. Couleurs

- `accentHex` vient de `CourseTypeColorPreferences`.
- Le type reste textuel.
- Le contraste du badge est calculé depuis la luminance.
- L’état terminé peut utiliser une couleur de succès neutre.
- La couleur doit être cohérente avec la carte correspondante.

## 6. Simulation

Pour un temps logique simulé `logicalNow` :

```text
timerOffset = systemNow - logicalNow
timerDate(courseDate) = courseDate + timerOffset
```

Les champs :

- `start` et `end` restent les horaires réels du cours ;
- `timerStart` et `timerEnd` sont translatés pour les timers ActivityKit.

Le décompte représente ainsi la simulation tandis que `08:00 → 10:00` reste affiché comme horaire réel.

## 7. Cycle de vie

- Si désactivée : terminer les activités.
- Si ActivityKit non autorisé : ne rien demander.
- Si aucun cours dans la journée : terminer immédiatement.
- Si une activité existe : la mettre à jour et terminer les doublons.
- Sinon : demander une activité pour le jour logique.
- `Réafficher l’activité` termine puis recrée.
- `Terminer l’activité actuelle` termine manuellement.

## 8. Réglages

Le sheet doit exposer :

- activation globale ;
- autorisation ActivityKit ;
- état actif/inactif ;
- réaffichage ;
- terminaison manuelle ;
- accès aux couleurs dans la section Apparence générale, pas uniquement sous Live Activity.

## 9. Tests

Extraire ou tester autant que possible la sélection d’état comme logique pure :

- avant premier cours ;
- pause ;
- cours en cours ;
- seuils 30 et 20 minutes ;
- dernier cours ;
- journée terminée ;
- groupe réel ;
- couleurs dynamiques ;
- simulation conservant `start/end`.

La validation finale nécessite un iPhone : rendu Lock Screen, mise à jour des timers, suppression utilisateur et recréation.
