# Documentation Ora

## Produit

Ora est une application iPhone SwiftUI pour consulter l’emploi du temps CELCAT de l’IUT de Vélizy. Elle cible iOS 26 et distribue une IPA non signée.

## Données

1. Le POST CELCAT direct est la source principale.
2. L’iCal remplace le résultat d’un groupe uniquement si son POST échoue.
3. Un résultat POST vide est valide et ne déclenche pas le fallback.
4. Les résultats POST et iCal ne sont jamais fusionnés.
5. Le groupe demandé et le groupe réellement indiqué par CELCAT restent distincts.
6. La dernière récupération valide peut être affichée lorsque CELCAT est indisponible.

## Interface

### Jour

- timeline verticale de 00:00 à 24:00 ;
- swipe horizontal entre les journées sans modifier le scroll vertical ;
- ligne rouge sur aujourd’hui ;
- bouton Aujourd’hui recentré sur l’heure courante ;
- une carte ne s’ouvre jamais lorsque le geste est un swipe.

### Semaine

- cinq jours visibles ;
- colonne horaire fixe ;
- en-tête et contenu dans le même ruban horizontal ;
- navigation vers le passé et le futur ;
- ligne de l’heure courante sur toute la largeur ;
- jours passés assombris et aujourd’hui légèrement bleuté.

### Cartes

- coordonnées identiques en Jour et Semaine ;
- contenu aligné en haut ;
- groupe réel CELCAT ;
- horaires compacts ;
- adaptation automatique à la largeur et à la hauteur ;
- trait gauche pointillé pour les événements personnels ;
- fond plein et texte blanc pendant l’ouverture du détail.

## Types et couleurs

Les types viennent uniquement des données CELCAT et des événements personnels. Le parsing ne contient aucune liste fermée de types.

Une première installation propose quatre regroupements regex modifiables : TP, TD, CM et Projet tutoré. Leur renommage est actif et utilise directement le nom du regroupement. Ces valeurs sont seulement une configuration initiale : elles peuvent être modifiées ou supprimées définitivement, et tous les autres libellés restent dynamiques.

Dans les couleurs :

- les regroupements et types sont triés par fréquence décroissante des cours chargés ;
- un type non regroupé affiche seulement son nom ;
- un regroupement sans correspondance peut indiquer qu’aucun cours chargé ne correspond ;
- chaque entrée possède une teinte modifiable par glissement continu.

## Live Activity

La Live Activity concerne l’écran verrouillé. Elle n’appelle jamais CELCAT et reçoit uniquement des événements déjà normalisés.

- cours actuel : état, horaires, matière, type et métadonnées ;
- pause : progression entre la fin du cours précédent et le début du suivant ;
- avant le premier cours : capsule vide ;
- journée terminée : état compact ;
- cours le lendemain : une seule ligne secondaire avec son heure ;
- accents éclaircis dans la même hue lorsqu’ils manquent de contraste.

Les horaires visibles restent réels. Seules les dates utilisées par les décomptes sont translatées pendant une simulation.

## Architecture

Les dossiers sources conservent leurs noms historiques afin de préserver la continuité Git ; le projet, les cibles et les produits générés portent le nom Ora.


| Dossier | Rôle |
| --- | --- |
| `Ora/App` | état global et cycle de vie |
| `Ora/Networking` | clients CELCAT |
| `Ora/Parsing` | conversion des réponses |
| `Ora/Models` | modèles métier |
| `Ora/Features` | interface SwiftUI |
| `Ora/LiveActivity` | préparation des états ActivityKit |
| `OraLiveActivity` | rendu de l’extension |
| `Shared` | structures partagées |
| `OraTests` | tests de régression |

La date horizontale, la position verticale et le chargement réseau restent indépendants.

## Validation et livraison

Toute modification passe par une branche dédiée et une pull request. La fusion dans `main` est autorisée uniquement après une CI Xcode 26 verte.

Le pipeline `main` :

1. exécute les tests ;
2. compile l’app iPhone sans signature ;
3. crée l’IPA ;
4. publie la Release ;
5. met à jour `site` ;
6. conserve l’artifact CI.

La CI valide le code, pas le rendu tactile. Les timelines, cartes, gestes et Live Activity doivent aussi être vérifiés sur un iPhone réel.
