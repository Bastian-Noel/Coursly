# Contrat des données CELCAT

## 1. Source principale

```text
POST https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData
```

Corps `application/x-www-form-urlencoded` :

| Champ | Valeur |
| --- | --- |
| `start` | début de l’intervalle au format `yyyy-MM-dd` |
| `end` | fin de l’intervalle au format `yyyy-MM-dd` |
| `resType` | `103` |
| `calView` | `agendaWeek` |
| `federationIds[]` | nom public du groupe, par exemple `MMI2-B2` |
| `colourScheme` | `3` |

Headers importants : `Accept: application/json, text/javascript, */*; q=0.01`, `X-Requested-With: XMLHttpRequest`, ainsi que l’origine et le référent CELCAT.

Une réponse décodable en tableau constitue un succès, même si ce tableau est vide.

## 2. Stratégie par groupe

```text
CelcatDirectClient.fetch
   ↓
DirectEventParser
   ├─ succès → directPOST uniquement
   └─ erreur → CelcatICalClient.fetch → ICalParser → iCalFallback uniquement
```

Le choix est effectué indépendamment pour chaque groupe demandé. Une requête multi-groupes peut donc afficher :

- du POST pour les groupes ayant réussi ;
- de l’iCal pour un groupe dont le POST a échoué ;
- une erreur signalée pour un groupe dont les deux sources ont échoué.

Cette coexistence entre groupes n’est pas une fusion des sources d’un même groupe.

## 3. Groupes publics et IDs iCal internes

| Groupe public POST | ID iCal interne |
| --- | --- |
| `MMI1-A1` | `G1-QJ2DMFYC5987` |
| `MMI1-A2` | `G1-PW2GUKMM5988` |
| `MMI1-B1` | `G1-HN2CHYNX5990` |
| `MMI1-B2` | `G1-QW2SJTJH5991` |
| `MMI2-A1` | `G1-QS2QEJVB5994` |
| `MMI2-A2` | `G1-EG2LDXAM5995` |
| `MMI2-B1` | `G1-AE2BGJHX5997` |
| `MMI2-B2` | `G1-TM2VJCBU5998` |
| `MMI3-FA-DW-A1` | `G1-TS2PGRAD6003` |
| `MMI3-FA-DW-A2` | `G1-KL2GMWYW6004` |
| `MMI3-FI-CN-A1` | `G1-EB2URAPF6006` |
| `MMI3-FI-CN-A2` | `G1-JP2NSAYC6007` |
| `MMI3-FA-CN-A1` | `G1-CC2LTGMX6000` |
| `MMI3-FA-CN-A2` | `G1-HW2LKCBM6001` |

Les IDs de la seconde colonne ne sortent jamais du client iCal.

## 4. Groupe de requête et groupe réel

Exemple : une requête `MMI2-B2` peut renvoyer dans `description` un cours pour `MMI2-B` ou `MMI2`.

Le modèle conserve :

```text
groups            = [MMI2-B2]    provenance de requête
rawGroupLabels    = [MMI2-B]     groupe annoncé par CELCAT
displayGroupLabels= [MMI2-B]     valeur destinée à l’interface
```

Si aucun groupe réel exploitable n’est présent, `displayGroupLabels` retombe sur `groups`.

## 5. Parsing POST

Champs exploités :

- `id`, `start`, `end`, `allDay` ;
- `description`, `eventCategory` ;
- `modules`, `sites` ;
- les métadonnées supplémentaires peuvent être préservées lors d’une évolution du modèle.

La description CELCAT contient généralement :

```text
enseignant 1
enseignant 2
<br />
groupe réel
<br />
salle 1
<br />
bloc module
```

Le parser doit :

- préserver les vrais retours ligne avant de découper `<br />` ;
- garder plusieurs enseignants séparés ;
- calculer la position du groupe à partir du bloc final module et du nombre de salles ;
- nettoyer le suffixe de site des salles ;
- retirer le code et le préfixe module du titre visible ;
- conserver `eventCategory` comme type dynamique ;
- normaliser les catégories connues sans supprimer les inconnues ;
- ignorer `allDay == true`.

## 6. Dates et fuseau

- Fuseau métier : `Europe/Paris`.
- Accepter ISO 8601 avec offset, secondes fractionnaires ou date locale CELCAT.
- La position timeline est calculée dans le fuseau métier.
- Les tests doivent inclure heure d’été, heure d’hiver et valeurs UTC.

## 7. Fallback iCal

Le client essaie plusieurs routes du même flux iCal, dans cet ordre :

```text
GET https://celcat.iut-velizy.uvsq.fr/cal/ical/<ID>/schedule.ics
GET https://celcat.rambouillet.iut-velizy.uvsq.fr/cal/ical/<ID>/schedule.ics
GET https://edt.iut-velizy.uvsq.fr/Calendar/iCalendar
```

La dernière route est historique et reçoit `resType=103` et `federationIds[]=<ID interne>`. Toutes restent un fallback iCal : elles ne sont essayées qu’après l’échec du POST et ne sont jamais fusionnées avec lui.

Le parser gère au minimum : VEVENT, UID, SUMMARY, LOCATION, DTSTART, DTEND, lignes repliées, texte échappé, dates UTC et locales. Les champs absents restent vides ou nuls ; ils ne sont pas inventés depuis le POST.

Limite connue : le développement de `RRULE` / `RECURRENCE-ID` doit être ajouté et testé si le flux réel en contient.

## 8. Fusion visuelle multi-groupes

Après normalisation, `CalendarService.mergeVisualDuplicates` peut fusionner des cours identiques selon matière, dates, salles, enseignants, type et module.

La fusion :

- réunit les groupes de requête ;
- réunit les groupes réels ;
- conserve une provenance cohérente ;
- ne fusionne pas les événements personnels ;
- ne mélange pas POST et iCal pour enrichir un même cours.

## 9. Snapshots et diagnostics

- `directEventsByGroup` alimente les snapshots POST.
- `fallbackGroups` explique quels groupes utilisent la roue de secours.
- `failedGroups` expose les échecs complets.
- Un chargement incrémental destiné à la navigation ne doit pas produire de faux changements.
- Un refresh explicite peut mettre à jour les snapshots et notifier.

## 10. Continuité hors ligne

Après un chargement distant complet, l’app persiste les événements normalisés pour la sélection exacte de groupes. Si POST et iCal deviennent tous deux indisponibles, ce dernier calendrier valide reste affiché avec le diagnostic `Dernière copie locale`.

Le cache local :

- n’est jamais interrogé pour compléter une réponse POST réussie ;
- ne remplace pas le fallback iCal dans la stratégie réseau ;
- ne produit aucun snapshot de changements ;
- est invalidé visuellement lors d’un changement vers une sélection de groupes différente sans cache correspondant ;
- est remplacé après un nouveau chargement distant complet.

Les références JavaScript historiques sont décrites dans [`reference/README.md`](reference/README.md). Le code Swift actuel reste la référence d’implémentation.
