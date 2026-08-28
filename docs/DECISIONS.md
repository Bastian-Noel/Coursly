# Décisions de conception

Ce registre contient les décisions qui ne peuvent être modifiées implicitement. Toute évolution contraire exige une décision explicite, la mise à jour de ce fichier et des tests de migration.

## D-001 — POST CELCAT comme source de vérité

L’endpoint principal est :

```text
POST https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData
```

Une réponse exploitable, y compris `[]`, produit exclusivement des événements `directPOST`.

## D-002 — iCal comme fallback strict

Le fallback iCal n’est autorisé qu’après un échec réel du POST : transport, timeout, statut HTTP inutilisable, payload invalide ou parsing impossible.

Sont interdits :

- la fusion POST + iCal ;
- l’enrichissement du POST avec l’iCal ;
- le fallback déclenché parce qu’une journée ou période est vide ;
- la comparaison en production des deux sources pour choisir la plus riche.

Une copie locale du dernier résultat distant valide peut rester affichée lorsque POST et iCal échouent tous les deux. Elle constitue une continuité hors ligne signalée, pas une troisième source réseau et jamais un enrichissement du POST.

## D-003 — Deux identités de groupe

Un événement conserve séparément :

- le groupe de requête dans `groups` ;
- le groupe réel annoncé par CELCAT dans `rawGroupLabels` / `displayGroupLabels`.

L’interface affiche le groupe réel lorsqu’il existe. Le groupe de requête reste utile pour la provenance, les snapshots et le fallback.

## D-004 — IDs techniques invisibles

Les noms `MMI...` sont publics. Les IDs iCal `G1-...` sont internes au client fallback et interdits dans l’interface, la recherche, les notifications et la Live Activity.

## D-005 — Modèle métier unique

L’application consomme `CalendarEvent`. Les formats POST et iCal ne remontent pas dans les vues. La provenance `directPOST`, `iCalFallback` ou `local` est conservée pour les règles métier et le diagnostic.

## D-006 — Multi-groupes sans mélange de sources

La fusion visuelle rassemble des cours normalisés identiques issus de plusieurs groupes demandés. Elle ne transforme jamais deux sources réseau en un même événement hybride.

## D-007 — Changements basés uniquement sur le POST

`ChangeDetectionService` compare des snapshots POST directs par groupe. Un résultat iCal reste affichable mais n’écrase pas le dernier snapshot POST fiable et ne peut pas générer une suppression ou un déplacement.

## D-008 — Une seule surface de calendrier

Jour et Semaine sont deux états de `CalendarScene`, pas deux onglets indépendants. Recherche, groupes, date et actions utilisent des panneaux ; détail et réglages utilisent des sheets.

## D-009 — États de scroll indépendants

La date horizontale, la position verticale et le chargement réseau sont indépendants. Un changement horizontal normal ne produit aucun recentrage vertical.

## D-010 — Coordonnées temporelles communes

Jour et Semaine utilisent la même conversion heure → position. Un cours commence exactement à son heure et se termine avec un petit espace visuel avant son heure de fin.

## D-011 — Types dynamiques et réglage Hue uniquement

Le libellé du type provient des données CELCAT et reste le texte affiché dans toutes les surfaces. Une classification interne peut regrouper les catégories connues mais ne renomme jamais le libellé et ne limite pas l’interface.

Les règles de regroupement sont ordonnées, activables et configurables par expressions régulières dans les réglages avancés. Elles peuvent partager une classification et une couleur entre plusieurs variantes. Le réglage utilisateur modifie uniquement la hue ; saturation et luminosité sont déterminées par le design.

## D-012 — Temps logique simulé

Le statut en cours, les décomptes, la ligne rouge, le centrage explicite et la Live Activity utilisent le temps logique. Les heures affichées du cours restent les dates CELCAT réelles.

## D-013 — Live Activity centrée sur le Lock Screen

Le Lock Screen est l’unique expérience produit de la Live Activity. Une représentation minimale imposée par les surfaces système peut exister pour compatibilité ActivityKit, mais aucune expérience Dynamic Island développée ne fait partie du périmètre sans nouvelle décision.

## D-014 — SwiftUI natif

Privilégier SwiftUI, Foundation, ActivityKit et UserNotifications. Une dépendance externe doit résoudre un besoin non couvert de façon raisonnable par les API Apple.

## D-015 — Distribution non signée

La CI compile une IPA non signée. La signature est réalisée sur l’iPhone avec Feather, SideStore ou un outil équivalent. Aucun certificat ou profil privé n’est stocké dans le dépôt.

## D-016 — Branches et Bundle ID

- `main` : code, documentation, tests et déclenchement de distribution ;
- `site` : GitHub Pages et métadonnées uniquement ;
- Bundle ID stable : `fr.bastiannoel.coursly`.
