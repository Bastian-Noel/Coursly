# UX Coursly

Navigation principale : Aujourd'hui, Semaine, Recherche, Réglages.

## Aujourd'hui

Doit répondre immédiatement à : qu'est-ce que j'ai maintenant, ensuite, où et quand ?

Carte de cours : matière en premier, puis salle et type, horaires, groupe(s), enseignant en secondaire.

## Semaine

Afficher une grille lisible avec les blocs de cours, conflits et groupes actifs. Un tap ouvre le détail.

## Multi-groupes

Toujours afficher les noms lisibles `MMI...`. Les IDs `G1-...` sont interdits dans l'interface.

Fusion visuelle autorisée uniquement après normalisation si matière, début, fin, salle, enseignant et type sont compatibles. Sinon, les cours restent distincts.

## Détail

Afficher matière, type, date, début, fin, durée, salle(s), enseignant(s), groupe(s) et module/code si disponibles.

La provenance réseau n'est pas une information principale ; elle peut être visible en debug.

## Recherche

Rechercher dans titre, module, enseignant, salle, groupe, type et code. Prévoir filtres par période et groupe.

## États vides et erreurs

Une réponse POST valide sans cours doit afficher un état normal comme `Journée libre`, jamais une erreur réseau.

Si iCal a pris le relais, l'app reste utilisable sans alerte intrusive. Si les deux sources échouent, utiliser le cache précédent si disponible et indiquer qu'il peut être ancien.

## Style

Interface très iOS, typographie hiérarchisée, couleurs modérées, cartes non surchargées. Toujours écrire CM/TD/TP : la couleur ne doit jamais être la seule information.