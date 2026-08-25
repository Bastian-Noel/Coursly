# Workflow de contribution

Ce workflow s’applique à toute intervention humaine ou assistée sur Coursly. Son but est de préserver les invariants produit pendant les refontes, notamment dans la timeline.

## 1. Lire avant de modifier

Commencer par [`README.md`](README.md), puis consulter les documents indiqués par le domaine :

| Domaine | Lecture obligatoire |
| --- | --- |
| CELCAT, groupes, fallback | [`DECISIONS.md`](DECISIONS.md), [`DATA_SOURCES.md`](DATA_SOURCES.md) |
| Jour, Semaine, scroll | [`V3.md`](V3.md), [`TIMELINE_REDESIGN.md`](TIMELINE_REDESIGN.md), [`UX.md`](UX.md) |
| Modèle et services | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Live Activity ou simulation | [`LIVE_ACTIVITY.md`](LIVE_ACTIVITY.md), [`DECISIONS.md`](DECISIONS.md) |
| Build et livraison | [`DISTRIBUTION.md`](DISTRIBUTION.md) |

Inspecter ensuite le code et les tests existants. Une documentation décrit l’intention ; le code révèle aussi les contraintes de migration et les éventuels écarts.

## 2. Définir le problème

Écrire avant le code :

- le comportement observé ;
- le comportement attendu ;
- les étapes de reproduction ;
- les invariants concernés ;
- la cause supposée et les preuves disponibles ;
- les critères d’acceptation testables.

Pour un défaut visuel, préciser Jour ou Semaine, date, groupe, heure, mode clair/sombre, taille d’écran et état de simulation.

## 3. Travailler sur une branche

Partir de `main` à jour et utiliser un nom explicite :

```text
fix/week-scroll-anchor
refactor/calendar-navigation
feat/live-activity-layout
docs/documentation-v4
```

Ne pas développer directement sur `site`. Ne pas fusionner une refonte importante avant validation de la pull request.

## 4. Modifier au bon niveau

### Données

- conserver le POST comme source de vérité ;
- traiter `[]` comme un succès ;
- déclencher l’iCal uniquement sur un échec réel du groupe ;
- préserver séparément groupe de requête et groupe réel ;
- normaliser avant le cache et l’interface ;
- ajouter une fixture représentative au moindre nouveau format CELCAT.

### Timeline

- identifier d’abord l’axe fautif : date horizontale, minute verticale ou disponibilité réseau ;
- produire une intention de scroll vertical uniquement pour une action qui l’exige ;
- ne pas ajouter de `scrollTo(0)` défensif ;
- conserver une géométrie temporelle commune à Jour et Semaine ;
- garder en-tête et contenu du jour dans le même ruban horizontal ;
- déplacer une responsabilité hors d’une grosse vue plutôt que d’empiler un correctif dans un fichier central.

### Interface

- utiliser les composants et tokens existants ;
- vérifier la densité avec des contenus réels et longs ;
- préserver le tap lorsque l’effet pressé ou l’haptique est ajouté ;
- utiliser une vraie interaction continue pour le réglage de teinte ;
- contrôler mode clair, mode sombre, Dynamic Type et réduction des animations.

### Temps et Live Activity

- passer par l’horloge logique commune pour toute décision temporelle ;
- conserver les heures CELCAT originales à l’affichage ;
- tester les frontières entre futur, imminent, en cours et terminé ;
- cibler le Lock Screen et ne pas étendre implicitement la portée produit.

## 5. Tester pendant l’implémentation

Ajouter d’abord ou en même temps le test qui reproduit la régression. Exécuter les tests ciblés, puis toute la suite. Pour une modification de timeline, vérifier au minimum :

- jour précédent et suivant sans changement vertical ;
- retour Aujourd’hui avec recentrage ;
- initialisation différée après chargement ;
- semaine vers le passé et le futur ;
- cinq jours, heures fixes et traits complets ;
- cours courts, consécutifs et simultanés ;
- journées et cours passés ;
- pression et ouverture du détail.

La matrice complète est dans [`QUALITY_ASSURANCE.md`](QUALITY_ASSURANCE.md).

## 6. Préparer la pull request

La description doit contenir :

- problème et cause racine ;
- solution conceptuelle ;
- fichiers et responsabilités modifiés ;
- tests ajoutés ;
- risques ou limites ;
- validation visuelle effectuée ;
- captures avant/après lorsqu’elles expliquent mieux le changement.

Garder les commits lisibles et ne pas inclure de changements sans rapport. Les modifications locales de l’utilisateur doivent être préservées.

## 7. CI et fusion

Pour une PR contenant du code, attendre les tests, le build iPhone et le packaging Xcode 26. Une PR uniquement documentaire est volontairement exclue du workflow par `paths-ignore` ; vérifier alors liens, Markdown et cohérence manuellement.

Après fusion d’un changement de code sur `main`, surveiller toute la distribution décrite dans [`DISTRIBUTION.md`](DISTRIBUTION.md). Ne pas déclarer la livraison terminée tant que Release, site et artifact ne sont pas cohérents.

## Interdictions structurelles

- fusionner POST et iCal quand le POST a réussi ;
- afficher un identifiant CELCAT interne ;
- remplacer le groupe réel par le groupe sélectionné ;
- coupler une réponse réseau à un retour vertical à minuit ;
- synchroniser deux rubans horizontaux concurrents pour l’en-tête et le contenu ;
- coder une liste fermée de types comme seule vérité ;
- griser tous les cours passés avec une couleur générique ;
- simuler en modifiant les dates originales des événements ;
- ajouter une grande rustine dans `TimelineViews.swift` sans revoir les responsabilités.

## Compte rendu final

À la fin, indiquer précisément :

- ce qui a changé ;
- les tests et validations exécutés ;
- le lien de la PR et son état ;
- le run CI et la version publiée, si applicables ;
- les vérifications sur appareil restant à faire.
