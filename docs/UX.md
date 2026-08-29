# Spécification UX et design

## 1. Direction visuelle

Coursly privilégie une grille temporelle claire, des surfaces interactives légères et des informations denses mais hiérarchisées.

- Fond principal blanc ou système en mode clair, sombre système en mode sombre.
- Gris neutres pour les jours passés et séparateurs.
- Aucune teinte jaune ou orange décorative imposée aux en-têtes Semaine.
- Couleur de type réservée au trait gauche, aux accents et aux fonds teintés des cartes.
- Liquid Glass réservé aux contrôles et panneaux flottants.

## 2. Hiérarchie de l’écran

```text
CalendarHeader
CalendarScene
   ├── DayTimelineView
   └── WeekTimelineView
Panneau contextuel éventuel
FloatingControlDock
```

L’ordre de superposition doit garantir :

1. timeline scrollable ;
2. panneaux au-dessus de la timeline ;
3. dock toujours accessible ;
4. réserve de contenu suffisante sous 24:00.

## 3. En-tête principal

- Date focalisée à gauche.
- Heure logique et groupes à droite.
- Actualisation explicite avec état de chargement.
- Toucher la date ouvre le panneau de choix de date.
- La simulation ne crée aucun bandeau dans le calendrier ; sa date et son heure sont visibles et modifiables uniquement dans les réglages avancés.

## 4. Timeline Jour

- Colonne horaire de 44 points environ.
- Libellés `00` à `00`, traits principaux chaque heure et traits secondaires discrets.
- Cours à droite de la colonne horaire.
- Ligne rouge exacte sur aujourd’hui uniquement.
- Page précédente et suivante préchargées pour le swipe.
- La réponse verticale à un swipe diagonal reste prioritaire si le mouvement horizontal n’est pas dominant.

Positionnements :

| Situation | Comportement |
| --- | --- |
| Lancement sur aujourd’hui | ligne rouge centrée après chargement |
| Date initiale non courante | premier cours ou 08:00 si vide |
| Swipe jour | position verticale inchangée |
| Choix de date | position verticale inchangée |
| Aujourd’hui | ligne rouge centrée |
| Résultat de recherche | cours centré |

## 5. Timeline Semaine

- Cinq journées dans la largeur disponible.
- Colonne horaire visible à gauche pendant tout déplacement horizontal.
- En-tête blanc/gris clair ; aujourd’hui distingué par une forme grise neutre, pas une couleur chaude.
- En-tête et contenu se déplacent ensemble horizontalement.
- L’en-tête reste attaché à sa colonne horizontale mais compense le scroll vertical afin que le numéro du jour demeure visible.
- Les traits horaires traversent chaque colonne jusqu’à 24:00.
- Les séparateurs verticaux restent subtils.
- La ligne rouge traverse tout le viewport et reste visible pendant le déplacement horizontal.
- Le point rouge reste attaché uniquement à la colonne d’aujourd’hui.
- Le ruban se cale sur les limites de journée.

Les jours passés utilisent un fond légèrement plus sombre et un texte secondaire. Aujourd’hui et les jours futurs utilisent le fond normal.

## 6. Carte de cours

### Forme

- Rectangle sans gros rayon.
- Trait de type de 2,5 à 3,5 points au bord gauche.
- Pas d’ombre lourde.
- Pas de marge au début temporel.
- Environ quatre points de vide avant la fin temporelle.

### Contenu

Priorité :

1. matière ;
2. horaires et type ;
3. salle ;
4. enseignants ;
5. groupe réel.

Le code module n’est jamais rendu sur la carte. Il reste disponible dans le détail et la recherche.

Le contenu reste aligné en haut, quelle que soit la hauteur disponible. En Jour, le début reste en haut à droite et la fin en bas à droite sans réserver une colonne dans le layout. En Semaine, les deux horaires forment une ligne compacte centrée en haut.

En Jour, les métadonnées utilisent :

- `mappin` ou `mappin.and.ellipse` pour la salle ;
- `person.fill` pour les enseignants ;
- `person.2.fill` pour le groupe.

### Adaptation

- Une carte très courte conserve d’abord la matière et la salle.
- En Jour, salle, enseignants et groupe restent empilés verticalement même lorsque plusieurs cours se partagent la largeur.
- Une carte haute sépare salle, enseignants et groupe sur plusieurs lignes.
- En Semaine, aucune icône n’est affichée ; le titre peut occuper jusqu’à cinq lignes.
- `ViewThatFits` ajoute ensuite salle, enseignants puis groupe seulement si la hauteur réelle le permet.
- `minimumScaleFactor` évite les coupures brutales sans rendre le texte illisible.

### Pression

Au touch-down :

- échelle proche de `0.97` ;
- légère baisse de luminosité/opacité ;
- haptique doux unique.

Au relâchement valide : ouverture du détail. Tant que le détail est ouvert, la carte utilise un fond plein dans la teinte du type et un texte blanc ; elle retrouve son rendu normal à la fermeture. Les grilles, indicateurs et ancres sont `allowsHitTesting(false)`.

## 7. Couleurs et passé

- Le fond normal d’un cours utilise une faible opacité de la couleur du type.
- Le trait gauche utilise la couleur pleine.
- Un cours passé réduit saturation et luminosité tout en préservant la hue.
- Le fond de jour passé et le fond de cours passé sont deux traitements différents et cumulables.
- Le texte doit conserver un contraste suffisant dans les deux modes système.

## 8. Sélecteur de Hue

- Une seule barre arc-en-ciel par type développé.
- Surface tactile d’au moins 44 points.
- `DragGesture(minimumDistance: 0)` local.
- Le curseur est centré sous le doigt et reste dans les bornes.
- La preview suit chaque `onChanged`.
- La préférence et la Live Activity sont mises à jour au `onEnded`.
- Aucun changement d’identité de la row pendant le drag.

## 9. Groupes

- Navigation progressive dans une hiérarchie.
- Fil d’Ariane et retour au niveau précédent.
- `Tous` clairement séparé des choix enfants.
- Nombres nommés `Groupe N`.
- Résumé permanent de la sélection actuelle.
- Aucun ID technique exposé.

## 10. Contrôles flottants

Le dock regroupe : Jour/Semaine, Chercher, Groupes et Plus. Aujourd’hui apparaît séparément lorsqu’il est utile.

- Cibles tactiles minimales de 44 points.
- Les bulles Plus et Groupes restent dans la hiérarchie et se transforment en panneau depuis leur surface Liquid Glass.
- Le panneau utilise `GlassEffectContainer`, `glassEffectID` et la transition Liquid Glass appariée. Son bas chevauche le milieu de la bulle source ; l’espace de la bulle reste réservé pendant le morphing.
- La bulle Recherche ne reçoit pas de fond bleu lorsqu’elle est active.
- Un tap hors d’un panneau le ferme et est absorbé sans agir sur la timeline.
- La bulle droite est une capsule continue sans séparateur visible.
- Le dock n’occupe pas une TabBar opaque pleine largeur.
- La timeline ajoute une réserve de scroll supérieure à la hauteur réelle du dock.

## 11. Panneaux et réglages

- Recherche, Groupes, Date, Plus et Changements sont des panneaux flottants.
- Réglages, création et détail sont des sheets.
- Les réglages sont regroupés par intention : Calendrier, Apparence, Changements, Live Activity, Interactions et Avancé.
- L’apparence globale propose Selon l’iPhone, Clair ou Sombre indépendamment de l’apparence courante du téléphone.
- La simulation, le regroupement regex des types et le diagnostic sont rangés dans Avancé ; les teintes restent uniquement dans Couleurs des cours.
- Un regroupement possède un nom privé aux réglages, une activation visible et autant d’expressions que nécessaire.
- Le constructeur propose Contient, Mot exact, Commence, Se termine et Regex libre, avec aperçu et champ de test.
- Le libellé CELCAT reste visible par défaut ; seul un renommage explicitement activé le remplace.
- La création d’un événement personnel expose titre, type facultatif, lieu, enseignants, horaires et notes, avec suggestions issues des cours connus. Elle n’expose ni module ni groupe et son trait gauche est pointillé.
- Une explication courte accompagne toute option métier non évidente.

## 12. Accessibilité

- Tous les libellés visibles sont en français.
- Une carte forme un élément VoiceOver unique avec matière, type, horaires, salle, enseignants et groupe.
- Ne pas dépendre uniquement de la couleur.
- Conserver la lisibilité avec Dynamic Type ; si une carte ne peut pas grandir, prioriser le contenu essentiel.
- Les animations de navigation doivent pouvoir être réduites sans casser l’état final.
