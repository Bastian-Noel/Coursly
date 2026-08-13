# Distribution de Coursly

## Branches

- `main` : code iOS, documentation et workflow GitHub Actions.
- `site` : GitHub Pages, `source.json`, `latest.json` et page de téléchargement.

## Pipeline

Un push de code sur `main` doit produire :

1. génération du projet Xcode avec XcodeGen ;
2. build Release pour `iphoneos` avec signature désactivée ;
3. création de `Payload/Coursly.app` puis `Coursly.ipa` ;
4. publication de l'IPA dans une GitHub Release ;
5. mise à jour de `site/source.json` et `site/latest.json` avec l'URL directe de la nouvelle IPA ;
6. GitHub Pages sert automatiquement les nouvelles métadonnées.

## Signature

L'IPA publiée est volontairement non signée. Elle est destinée à être signée sur l'iPhone par un sideloader avec le certificat/provisioning de l'utilisateur.

Ne jamais ajouter `.p12`, mot de passe ou `.mobileprovision` privé dans le repo.

## Source sideloader

URL stable :

```text
https://bastian-noel.github.io/Coursly/source.json
```

La source doit rester compatible avec les parseurs AltSource utilisés par Feather/AltStore/SideStore et autres outils compatibles.

Lors de chaque build, mettre à jour en priorité la première entrée de `versions` avec la nouvelle version, le build, la date, la taille et le `downloadURL` direct de l'asset GitHub Release.

Conserver aussi les champs de compatibilité au niveau de l'app lorsque requis par certains parseurs : `version`, `versionDate`, `size`, `downloadURL`, `iconURL`, `appPermissions`.

## Site

La page doit privilégier Feather, puis proposer les autres méthodes compatibles. Pour un outil sans schéma d'URL documenté, fournir un bouton de copie de l'URL de source plutôt que d'inventer un deep link.

## Bundle ID

`fr.bastiannoel.coursly` doit rester stable pour les mises à jour.