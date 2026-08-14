# UX Coursly

Navigation principale : Aujourd’hui, Semaine, Recherche, Réglages.

## Langue

L’interface utilisateur est en français. Les termes techniques internes peuvent rester en anglais dans le code, mais les libellés visibles doivent être français.

## Aujourd’hui

Doit répondre immédiatement à : qu’est-ce que j’ai maintenant, ensuite, où et quand ?

La vue principale est une vraie grille d’emploi du temps, pas une pile de grosses cartes :

- axe vertical avec les heures ;
- événements positionnés selon leur heure réelle de début et de fin ;
- hauteur proportionnelle à la durée ;
- trait rouge horizontal indiquant l’heure actuelle ;
- en mode simulation, le trait rouge suit l’heure simulée ;
- un tap sur un cours ouvre son détail.

Le bandeau supérieur reste compact : date, état actuel/prochain cours et groupes actifs.

## Semaine

Afficher une grille hebdomadaire traditionnelle avec les jours en colonnes et les heures en lignes.

Sur iPhone, la grille peut défiler horizontalement pour conserver une largeur lisible par journée. Les contrôles de semaine doivent rester compacts et utiliser les composants système iOS.

## Cours simultanés et conflits

Deux événements qui se chevauchent ne doivent jamais se masquer.

Ils sont disposés côte à côte dans le même créneau, avec une largeur partagée. Le titre, le type et la salle restent lisibles autant que possible.

Les cours réellement identiques peuvent être fusionnés visuellement après normalisation. Les événements incompatibles restent distincts.

## Multi-groupes

L’utilisateur peut activer plusieurs groupes simultanément dans Réglages.

Toujours afficher les noms lisibles `MMI...`. Les IDs `G1-...` sont interdits dans l’interface.

Fusion visuelle autorisée uniquement après normalisation si matière, début, fin, salle, enseignant et type sont compatibles. Les groupes concernés sont alors agrégés dans l’événement affiché.

## Détail

Afficher matière, type, date, début, fin, durée, salle(s), enseignant(s), groupe(s) et module/code si disponibles.

La provenance réseau n’est pas une information principale ; elle peut être visible en debug.

## Recherche

Rechercher dans titre, module, enseignant, salle, groupe, type et code. Prévoir filtres par période et groupe.

Les résultats de recherche doivent être compacts : éviter de réutiliser les grosses cartes de l’ancienne interface.

## États vides et erreurs

Une réponse POST valide sans cours doit afficher un état normal comme `Journée libre`, jamais une erreur réseau.

Si iCal a pris le relais, l’app reste utilisable sans alerte intrusive. Si les deux sources échouent, utiliser le cache précédent si disponible et indiquer qu’il peut être ancien.

## Style iOS 26

Interface très iOS, plein écran, typographie hiérarchisée et densité adaptée à un emploi du temps.

Le Liquid Glass est surtout utilisé pour les contrôles, barres, capsules et surfaces interactives. La grille elle-même reste lisible et structurée ; elle ne doit pas devenir une succession de grands panneaux décoratifs.

Toujours écrire CM/TD/TP : la couleur ne doit jamais être la seule information. La ligne de temps actuelle est rouge par convention visuelle explicite.
