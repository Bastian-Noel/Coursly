# Documentation Coursly

Cette documentation décrit le produit réellement développé, ses invariants techniques et la manière de le faire évoluer sans réintroduire les régressions historiques.

## Ordre d’autorité

En cas de contradiction, appliquer cet ordre :

1. [`DECISIONS.md`](DECISIONS.md) — décisions non négociables ;
2. [`DATA_SOURCES.md`](DATA_SOURCES.md) — contrat CELCAT et provenance des données ;
3. [`V3.md`](V3.md) — critères d’acceptation du produit actif ;
4. [`ARCHITECTURE.md`](ARCHITECTURE.md) — responsabilités des modules ;
5. [`UX.md`](UX.md) et [`TIMELINE_REDESIGN.md`](TIMELINE_REDESIGN.md) — rendu et interactions ;
6. [`LIVE_ACTIVITY.md`](LIVE_ACTIVITY.md) — expérience Lock Screen ;
7. [`QUALITY_ASSURANCE.md`](QUALITY_ASSURANCE.md) — validation automatique et matérielle ;
8. [`DISTRIBUTION.md`](DISTRIBUTION.md) et [`CODEX_WORKFLOW.md`](CODEX_WORKFLOW.md) — livraison et méthode de travail.

[`PRODUCT.md`](PRODUCT.md) expose la vision, tandis que [`PLAN.md`](PLAN.md) décrit l’état actuel et les validations restantes. Ces deux documents ne peuvent pas assouplir une décision.

## Parcours conseillé

| Besoin | Documents |
| --- | --- |
| Comprendre Coursly | [`PRODUCT.md`](PRODUCT.md), [`V3.md`](V3.md) |
| Modifier CELCAT ou le parsing | [`DECISIONS.md`](DECISIONS.md), [`DATA_SOURCES.md`](DATA_SOURCES.md), [`reference/README.md`](reference/README.md) |
| Modifier Jour/Semaine | [`TIMELINE_REDESIGN.md`](TIMELINE_REDESIGN.md), [`UX.md`](UX.md), [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Modifier les cartes ou couleurs | [`UX.md`](UX.md), [`TIMELINE_REDESIGN.md`](TIMELINE_REDESIGN.md) |
| Modifier la Live Activity | [`LIVE_ACTIVITY.md`](LIVE_ACTIVITY.md), [`DECISIONS.md`](DECISIONS.md) |
| Préparer une PR | [`CODEX_WORKFLOW.md`](CODEX_WORKFLOW.md), [`QUALITY_ASSURANCE.md`](QUALITY_ASSURANCE.md) |
| Comprendre l’IPA et le site | [`DISTRIBUTION.md`](DISTRIBUTION.md) |

## Vocabulaire

- **groupe de requête** : nom public envoyé au POST, par exemple `MMI2-B2` ;
- **groupe réel du cours** : libellé renvoyé dans la description CELCAT, par exemple `MMI2-B` ;
- **temps système** : date/heure réelle de l’iPhone ;
- **temps logique** : temps système augmenté du décalage de simulation ;
- **position verticale** : minute placée en haut de la timeline, contrôlée par l’utilisateur après l’initialisation ;
- **fallback** : remplacement complet du résultat POST d’un groupe lorsque ce POST échoue, jamais une source complémentaire.

## Référence validée

La refonte timeline a été fusionnée par la PR `#11`, validée par les runs Xcode 26 `#87` et `#88`. Le run `#88` a publié `0.3.12`, mis à jour `site` et produit l’artifact CI.

Cette référence prouve la compilation et les tests automatisés. Elle ne remplace pas la validation visuelle sur un iPhone iOS 26 réel.
