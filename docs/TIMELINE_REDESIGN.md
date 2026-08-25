# Refonte timeline Jour / Semaine

Ce document fixe les invariants de navigation et de rendu issus de la refonte V4.

## États indépendants

Trois états ne doivent jamais être couplés implicitement :

1. `focusedDate` décrit la date affichée horizontalement ;
2. `dayTopMinute` et `weekTopMinute` mémorisent séparément la position verticale choisie par l’utilisateur ;
3. `CalendarStore.load` charge les données sans produire de déplacement visuel.

Un recentrage vertical n’est permis que dans ces cas :

- première ouverture du mode Jour sur aujourd’hui : ligne du temps courant au centre ;
- première ouverture du mode Semaine : premier cours des cinq jours visibles en haut ;
- bouton Aujourd’hui : jour courant et ligne du temps courant au centre ;
- résultat de recherche : cours ciblé au centre.

Un swipe de jour, un scroll horizontal de semaine, un préchargement réseau ou un changement Jour/Semaine ne crée aucune requête de recentrage.

## Ruban Semaine

- La colonne horaire est extérieure au `ScrollView` horizontal.
- L’en-tête et la timeline de chaque date sont une seule `WeekDayColumn`.
- Le ruban utilise un `LazyHStack` et étend sa fenêtre près de ses deux bords.
- Cinq colonnes de jour occupent exactement la largeur restante après la colonne horaire.
- La grille est dessinée avec `Canvas`, avec un trait à chaque heure sur toute la largeur du jour.
- Les en-têtes défilent verticalement avec leur journée ; ils ne possèdent pas un second état de scroll.

## Cours

- Le bord supérieur correspond exactement à l’heure de début.
- Le bord inférieur laisse quatre points avant l’heure de fin.
- Les cours simultanés partagent la largeur en colonnes ; deux cours consécutifs restent dans la même colonne.
- Le groupe affiché est `displayGroupLabels`, issu du groupe réel CELCAT, jamais le groupe de requête sauf absence de donnée réelle.
- Le code module n’est pas affiché dans la carte.
- Le contenu passe entre trois densités (`micro`, `compact`, `regular`) selon la hauteur et la largeur.
- Les fonds passés conservent la teinte du type avec saturation et luminosité réduites.
- Les calques décoratifs et indicateurs ignorent les touch events afin que le bouton du cours reste pressable.

## Performances

- Ne pas réintroduire une liste eager de centaines de `WeekDayColumn`.
- Ne pas recréer une ligne de réglage pendant le drag du sélecteur de teinte.
- Sérialiser les chargements concurrents dans `CalendarStore` et attendre leur fin avant le positionnement initial.
- Conserver les calculs de coordonnées temporelles dans `TimelineAxis` pour Jour et Semaine.
