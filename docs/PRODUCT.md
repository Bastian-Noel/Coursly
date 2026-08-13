# Vision produit — Coursly

## Objectif

Créer une app iPhone native d'emploi du temps étudiant pour l'IUT de Vélizy / UVSQ, rapide à consulter au quotidien mais assez puissante pour comparer plusieurs groupes, rechercher des cours et suivre une semaine complète.

Questions prioritaires :

1. Qu'est-ce que j'ai maintenant ?
2. Qu'est-ce que j'ai ensuite ?
3. Dans quelle salle ?
4. À quoi ressemble ma journée / ma semaine ?

## Navigation principale

- Aujourd'hui
- Semaine
- Recherche
- Réglages

## Fonctionnalités cibles

### Aujourd'hui

- cours actuel ;
- prochain cours ;
- timeline ;
- marqueur d'heure actuelle ;
- périodes libres ;
- conflits ;
- événements locaux.

### Semaine

- grille lisible ;
- navigation semaine précédente/suivante ;
- blocs de cours ;
- conflits ;
- groupes actifs.

### Détail d'un cours

Priorité : matière, type, horaires, salle, groupes. Puis enseignant, module/code et autres métadonnées utiles.

### Recherche

Recherche par matière, enseignant, groupe, salle, type et code. Filtres temporels : aujourd'hui, semaine, mois, plage personnalisée.

### Multi-groupes

L'utilisateur peut afficher plusieurs groupes simultanément. Les cours réellement identiques peuvent être fusionnés visuellement après normalisation, en agrégeant les groupes concernés.

### Conflits

Deux événements incompatibles sur le même créneau restent distincts et doivent être signalés clairement.

### Événements locaux

L'utilisateur pourra créer devoirs, rappels, rendez-vous, réunions ou blocs personnels. Ces événements restent séparés des données CELCAT.

### Live Activity

Lock Screen uniquement pour la V1. Elle ne remplace pas l'app complète.

## Périmètre MVP

- sélection d'un groupe ;
- récupération CELCAT fiable ;
- vue Aujourd'hui ;
- vue Semaine ;
- détail d'un cours ;
- recherche simple ;
- fallback iCal strict ;
- normalisation des données ;
- Live Activity Lock Screen ;
- build automatique d'une IPA non signée via GitHub Actions.

## Hors périmètre initial

- Dynamic Island ;
- itinéraires vers les salles ;
- comptes utilisateurs ;
- synchronisation cloud des événements locaux ;
- push serveur ActivityKit ;
- backend complexe si l'accès direct iOS suffit.

## Critère de réussite

En ouvrant Coursly, un étudiant doit comprendre son prochain déplacement en quelques secondes.