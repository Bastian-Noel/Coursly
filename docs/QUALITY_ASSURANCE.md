# Assurance qualité

La qualité de Coursly repose sur trois niveaux complémentaires : tests Swift, pipeline Xcode 26 et validation sur un iPhone réel. Un build vert ne suffit pas à valider une interaction tactile ou une timeline visuellement correcte.

## Matrice de validation

| Domaine | Tests automatisés | Validation sur appareil |
| --- | --- | --- |
| Sources CELCAT | succès POST, réponse vide, erreurs et fallback strict | emploi du temps réel de plusieurs groupes |
| Parsing | groupes réels, types dynamiques, salles, enseignants, dates | comparaison avec CELCAT web |
| Multi-groupes | déduplication et fusion des résultats normalisés | cours communs et cours propres à chaque groupe |
| Jour | coordonnées, cours consécutifs, intention de scroll | swipes, ligne rouge, boutons flottants, rotation |
| Semaine | fenêtre de cinq jours, disposition et chevauchements | heures fixes, en-têtes, passé/futur, fluidité |
| Cartes | choix du niveau de densité | lisibilité, pression, haptique et ouverture du détail |
| Couleurs | conservation de la teinte, état passé | contraste clair/sombre et slider continu |
| Temps simulé | calcul de l’état temporel | cohérence calendrier/Live Activity |
| Live Activity | construction des états et progression | rendu Lock Screen et mises à jour réelles |
| Distribution | génération des métadonnées et packaging | téléchargement, signature et lancement de l’IPA |

## Tests Swift obligatoires

Toute modification fonctionnelle doit conserver des tests de non-régression pour les invariants touchés. Les cas minimaux sont :

- une réponse POST valide, y compris `[]`, ne déclenche jamais l’iCal ;
- une erreur réseau, HTTP ou de décodage peut déclencher le fallback du groupe concerné ;
- le groupe de requête et le groupe réel du cours restent distincts ;
- une sélection multi-groupes ne mélange pas POST et iCal pour compléter un succès ;
- les types inconnus sont conservés et colorables ;
- une règle regex regroupe les variantes sans modifier leur libellé CELCAT ;
- une regex invalide ou désactivée ne classe aucun cours ;
- deux cours consécutifs gardent leurs coordonnées temporelles et un espace visuel ;
- la navigation horizontale ne produit pas spontanément une intention de scroll vertical ;
- le temps simulé modifie l’état logique, pas les horaires affichés ;
- la recherche ouvre le bon événement à la bonne date.

Commande locale de référence :

```bash
xcodegen generate
xcodebuild test \
  -project Coursly.xcodeproj \
  -scheme Coursly \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

Le nom exact du simulateur peut varier. La CI choisit automatiquement le premier simulateur iPhone disponible.

## Contrôle visuel Jour

À tester en mode clair et sombre, avec une journée vide, une journée chargée et des cours d’une heure ou moins :

- première ouverture aujourd’hui centrée sur la ligne rouge après le chargement ;
- changement de jour sans retour à `00:00` ;
- bouton Aujourd’hui recentrant explicitement la ligne rouge ;
- cours démarrant exactement à la bonne minute et terminant quelques points avant la fin ;
- fond de toute journée passée assombri, sauf aujourd’hui ;
- cours passé conservant la teinte de son type dans une variante plus sombre ;
- contenu compact mais lisible, avec plusieurs lignes et icônes lorsqu’il y a de la place ;
- contrôles du bas réellement superposés et réserve de scroll suffisante ;
- touch-down visible, haptique unique puis ouverture fiable du détail.

## Contrôle visuel Semaine

Ce contrôle est bloquant avant une release qui modifie la timeline :

- exactement cinq jours dans la largeur utile ;
- colonne horaire toujours visible pendant le défilement horizontal ;
- en-tête et contenu d’un jour déplacés dans le même ruban ;
- numéros de jours visibles, sans fond jaune ou orange ;
- traits horaires sur toute la largeur et sur les 24 heures ;
- mêmes coordonnées temporelles qu’en Jour ;
- premier chargement aligné sur le cours le plus tôt des cinq jours, après réception des données ;
- navigation ultérieure conservant la position verticale choisie ;
- extension fluide et magnétique vers le passé comme vers le futur ;
- journées passées assombries avec aujourd’hui intact ;
- absence de disparition, saut d’en-tête ou changement inattendu des cours.

## Contrôle Live Activity et simulation

Tester successivement un cours futur, imminent, en cours et terminé :

- matière, état, horaires réels, type, groupe, salle et enseignants visibles ;
- décompte en haut à droite et progression en bas ;
- couleur issue de la teinte personnalisée du type ;
- simulation changeant uniquement le temps logique ;
- retour au temps réel restaurant immédiatement le bon état ;
- absence de rognage en haut et en bas, avec ou sans prochain cours ;
- absence de promesse produit spécifique à la Dynamic Island.

## Performance

La validation se fait avec une fenêtre contenant plusieurs semaines et plusieurs groupes :

- pas de requête réseau provoquée par chaque pixel de scroll ;
- pas de reconstruction intégrale de la frise à chaque tick de l’horloge ;
- chargement anticipé borné autour de la fenêtre visible ;
- déduplication avant le layout ;
- calculs de géométrie purs et réutilisables ;
- absence de synchronisation permanente entre deux `ScrollView` horizontales.

Utiliser Instruments lorsque le défilement n’est pas stable à 60 Hz sur l’appareil cible. Conserver une trace avant/après pour toute optimisation importante.

## Critères de sortie

Une modification est livrable lorsque :

1. les critères d’acceptation concernés sont explicitement identifiés ;
2. les tests de régression correspondants existent et passent ;
3. le build Release iPhone non signé passe ;
4. la validation visuelle et tactile a été effectuée pour une modification d’interface ;
5. aucune contradiction n’a été introduite dans la documentation ;
6. la PR est fusionnée sur `main` avant que le pipeline de distribution ne publie l’IPA.

## Compte rendu conseillé

```text
Périmètre :
Tests ajoutés/modifiés :
Run CI :
Appareil et version iOS :
Jour vérifié : oui/non
Semaine vérifiée : oui/non
Live Activity vérifiée : oui/non/non concernée
Points restant à contrôler :
```
