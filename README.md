# Coursly

Prototype iOS 26 pour valider d'abord la chaîne de distribution sans Mac personnel.

## Première étape

Cette version est volontairement minimale :

- app SwiftUI « Hello Coursly » ;
- build iPhone sur GitHub Actions ;
- IPA produite sans signature ;
- GitHub Pages avec bouton de téléchargement ;
- `source.json` pour l'import dans un gestionnaire compatible AltStore/Feather ;
- signature effectuée ensuite directement sur l'iPhone.

## Distribution

Après un push sur `main`, GitHub Actions :

1. génère le projet Xcode avec XcodeGen ;
2. compile pour un appareil iOS réel avec la signature désactivée ;
3. crée `Coursly.ipa` à partir de `Coursly.app` ;
4. génère `source.json` avec la version et la taille de la build ;
5. déploie l'IPA, le JSON et une page web sur GitHub Pages.

URL prévue :

```text
https://bastian-noel.github.io/Coursly/
```

Source prévue :

```text
https://bastian-noel.github.io/Coursly/source.json
```

## Bundle ID

```text
fr.bastiannoel.coursly
```

Le Bundle ID doit rester stable pour que les builds suivantes remplacent l'app précédente après signature sur l'appareil.

## Important

L'IPA générée par la CI est volontairement non signée. iOS ne l'installe pas telle quelle : elle est prévue pour être importée puis signée sur l'appareil avec le certificat et le provisioning profile de l'utilisateur.
