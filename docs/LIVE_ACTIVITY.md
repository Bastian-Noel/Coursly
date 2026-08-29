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
| `EN PAUSE` | entre deux cours | jusqu’au prochain, avec remplissage de la fin du cours précédent au début du suivant |
| `EN COURS` | cours actuel, plus de 20 min restantes si un cours suit | jusqu’à la fin |
| `BIENTÔT TERMINÉ` | 20 dernières minutes et un cours suit | jusqu’à la fin |
| `DERNIER COURS` | cours actuel sans cours suivant | jusqu’à la fin |
| `JOURNÉE TERMINÉE` | aucun cours restant | état final temporaire |
| `PROCHAIN COURS DEMAIN À …` | journée finie et cours présent le lendemain | jusqu’au début, sans faux avancement nocturne |

Le prochain cours est transporté avec l’état courant afin de rester immédiatement consultable et de permettre une transition locale fiable à la fin du cours.

## 4. Hiérarchie Lock Screen

Ordre visuel :

1. état temporel avec chronomètre et décompte regroupés en haut ;
2. horaires réels compacts ;
3. matière sur deux lignes au maximum ;
4. badge de type textuel, sans pictogramme ;
5. salle, enseignants et groupe réel sur une ligne secondaire ;
6. décompte au format `1h 05m` intégré à une capsule qui se remplit avec l’avancement ; le texte change de couleur sous la partie pleine ;
7. bloc « prochain cours » sur trois lignes : libellé et horaires début-fin, matière, puis type, salle, enseignants et groupe.

La surface reprend la DA des cartes Semaine avec un fond translucide sombre et des accents utilisant la couleur personnalisée du type, sans bande verticale. Le prochain cours transporte aussi son type, sa teinte, ses horaires et ses métadonnées. `ViewThatFits` choisit entre une variante confortable et une variante compacte dans la hauteur proposée par ActivityKit, sans rognage supérieur ou inférieur. Aucun faux bouton n’est affiché tant qu’une route d’ouverture de cours testable n’existe pas.

## 5. Couleurs

- `accentHex` vient de `CourseTypeColorPreferences`.
- Le type reste textuel.
- Le contraste du badge est calculé depuis la luminance.
- Les accents trop sombres sont éclaircis dans la même hue jusqu’à un seuil minimal de luminance, notamment pour les rouges et violets.
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
- Si aucun cours restant aujourd’hui mais qu’un cours existe demain : conserver l’activité et annoncer son horaire.
- Si aucun cours aujourd’hui ou demain : terminer immédiatement.
- Si une activité existe : la mettre à jour et terminer les doublons.
- Sinon : demander une activité pour le jour logique.
- Les appels concurrents sont ordonnés par révision ; une réponse ancienne ne peut pas écraser l’état le plus récent.
- Le widget recalcule localement `PREMIER COURS`, `PAUSE`, `EN COURS`, `BIENTÔT TERMINÉ`, `DERNIER COURS` et la transition vers le cours suivant à partir des dates ActivityKit.
- Le manager déduplique les cours visuellement identiques et ignore les événements chevauchants pour déterminer le prochain cours séquentiel.
- Avant le premier cours et pendant une pause, le cours à venir est déjà le contenu principal : aucun second bloc « prochain cours » n’est ajouté.
- Avant le premier cours, la capsule reste vide. Entre deux cours du même jour, son remplissage représente exactement la pause.
- `staleDate` couvre le cours suivant transporté, avec une marge, plutôt que de rendre l’activité périmée exactement au changement d’état.
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
