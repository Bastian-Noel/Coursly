# Sources de données CELCAT

## Principe fondamental

Le POST CELCAT direct est la source de vérité. Le flux iCal est un fallback strict uniquement lorsque le POST échoue réellement.

```text
POST https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData
```

Paramètres connus : `start`, `end`, `resType=103`, `calView=agendaWeek`, `federationIds[]=<groupe lisible>`.

## Groupes publics et IDs iCal internes

- MMI1-A1 → G1-QJ2DMFYC5987
- MMI1-A2 → G1-PW2GUKMM5988
- MMI1-B1 → G1-HN2CHYNX5990
- MMI1-B2 → G1-QW2SJTJH5991
- MMI2-A1 → G1-QS2QEJVB5994
- MMI2-A2 → G1-EG2LDXAM5995
- MMI2-B1 → G1-AE2BGJHX5997
- MMI2-B2 → G1-TM2VJCBU5998
- MMI3-FA-DW-A1 → G1-TS2PGRAD6003
- MMI3-FA-DW-A2 → G1-KL2GMWYW6004
- MMI3-FI-CN-A1 → G1-EB2URAPF6006
- MMI3-FI-CN-A2 → G1-JP2NSAYC6007
- MMI3-FA-CN-A1 → G1-CC2LTGMX6000
- MMI3-FA-CN-A2 → G1-HW2LKCBM6001

Les IDs `G1-...` ne doivent jamais apparaître dans l'UI.

## Stratégie

```text
CalendarService
  ↓
POST direct
  ├─ succès exploitable → parser direct → normalizer → POST uniquement
  └─ échec réel         → iCal → parser iCal → normalizer → fallback uniquement
```

Une réponse POST valide avec zéro événement est un succès et ne déclenche pas iCal.

Le fallback peut être utilisé pour timeout, panne réseau, statut HTTP inutilisable, payload invalide ou parsing impossible.

## Données à préserver

Le POST peut fournir enseignant(s), groupe, salle(s), catégorie, modules, département, faculté, sites, horaires et ID. Le modèle Swift doit préserver cette richesse. Le fallback iCal peut produire moins de champs ; les champs manquants restent vides/nuls.

## Parsing de référence

Le prototype `docs/reference/calendar.mjs` contient la logique fonctionnelle à porter en Swift :

- mapping catégories vers CM/TD/TP/PROJET/INT/REUNION/DS/EXAM ;
- découpage de la description CELCAT sur `<br />` ;
- extraction enseignant/groupe/salles/module ;
- parsing d'un bloc tel que `R218 - Economie et Droit du numerique [MM2R18]` ;
- nettoyage de salle ;
- parsing iCal VEVENT, UID, SUMMARY, LOCATION, DESCRIPTION, DTSTART, DTEND, TZID et UTC ;
- filtrage des événements en `Europe/Paris`.

Limite connue : le prototype iCal ne développe pas `RRULE`. Si nécessaire, le port Swift devra traiter les récurrences explicitement.

Voir `docs/reference/README.md` pour les règles de portage.