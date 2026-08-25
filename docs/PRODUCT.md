# Vision produit

Coursly transforme l’emploi du temps CELCAT de l’IUT de Vélizy en une expérience iPhone immédiate, lisible et fiable.

## Promesse

En ouvrant Coursly, un étudiant doit comprendre sans calcul :

1. quel cours a lieu maintenant ;
2. quand il commence ou se termine ;
3. où aller et avec qui ;
4. quel groupe est réellement concerné ;
5. ce qui vient ensuite ;
6. ce qui a changé depuis la dernière synchronisation.

## Principes

- **Temporel avant tout** : les cours occupent leurs vraies coordonnées de 00:00 à 24:00.
- **Continuité** : Jour et Semaine sont deux échelles d’un même calendrier.
- **Contrôle utilisateur** : après le positionnement initial, le scroll vertical appartient à l’utilisateur.
- **Fidélité CELCAT** : l’app affiche les données du POST sans les compléter silencieusement.
- **Information avant décoration** : matière, état, horaires, type, groupe, salle et enseignants sont prioritaires.
- **Design adaptatif** : une carte ne coupe pas simplement son contenu ; elle change de densité.
- **Temps simulé sans falsification** : la logique peut voyager dans le temps, pas les horaires affichés.

## Fonctionnalités actives

- timeline Jour avec swipe et ligne du temps courant ;
- ruban Semaine de cinq jours avec navigation passée et future ;
- multi-groupes, sélection hiérarchique et fusion visuelle ;
- cartes adaptatives, chevauchements côte à côte et détail contextuel ;
- recherche texte et facettes dynamiques ;
- événements personnels locaux ;
- personnalisation de hue par type CELCAT ;
- détection ajouté/supprimé/déplacé/modifié ;
- notifications locales configurables ;
- simulation temporelle ;
- Live Activity Lock Screen ;
- IPA non signée distribuée automatiquement.

## Hors périmètre actuel

- Dynamic Island comme expérience produit distincte ;
- modification de l’emploi du temps CELCAT ;
- authentification UVSQ ;
- synchronisation cloud d’événements personnels ;
- signature de l’IPA par la CI ;
- utilisation de l’iCal comme complément de données.

## Mesure de qualité

La réussite n’est pas seulement une compilation. Elle combine :

- respect des invariants de données ;
- tests de régression ;
- fluidité sur un ruban Semaine réel ;
- lisibilité des cours courts et étroits ;
- interactions tactiles fiables ;
- validation sur iPhone iOS 26 ;
- pipeline de distribution entièrement vert.
