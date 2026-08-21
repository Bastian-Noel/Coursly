# UX Coursly V3

Voir `docs/V3.md` pour le contrat complet.

## Surface unique

Coursly utilise une seule CalendarScene plein écran. Il n'existe plus de navigation principale Aujourd'hui / Semaine / Recherche / Réglages sous forme d'onglets.

## Timeline

- 00:00 → 00:00 ;
- centrée sur maintenant à l'ouverture ;
- trait rouge pour maintenant ;
- swipe gauche/droite pour changer de jour ;
- week-ends intelligents ;
- Jour et Semaine sont deux états de la même vue.

## Blocs de cours

Début en haut à gauche, fin en bas à gauche. La matière, le type et la salle sont prioritaires. Prof, groupes et module apparaissent quand la largeur/hauteur le permet.

Les chevauchements sont disposés côte à côte. CM/TD/TP restent textuels : la couleur n'est jamais la seule information.

## Contrôles

Liquid Glass est réservé aux contrôles flottants et surfaces interactives. La grille reste structurée et lisible.

## Recherche

Recherche texte + facettes dynamiques : matière, professeur, salle, groupe, type et module. Tap sur un résultat ramène la timeline au bon jour et met en évidence le cours.

## Détail

Sheet contextuelle avec matière, type, date, horaires, durée, salle, prof, groupes et module. La provenance réseau reste en diagnostic uniquement.

## Français et accessibilité

Tous les libellés visibles sont français. VoiceOver doit pouvoir lire type, matière, horaires, salle, professeur et groupes. Respecter Dynamic Type et Réduire les animations.
