<div align="center">

# GitLab License Generator

<p align="center">
  <a href="../README.md">English</a>
</p>

</div>

## Description

**GitLab License Generator** Ce projet permet de générer une licence GitLab à des **fins de développement**. Si vous rencontrez des problèmes, merci de les résoudre par vous-même.

Dernier test effectué sur GitLab v17.4.1-ee.

## Principes

### **src/generator.keys.rb**

GitLab utilise une paire de clés publique/privée pour chiffrer sa licence. La clé publique est fournie avec la distribution GitLab, tandis que la clé privée est conservée de manière sécurisée. La licence est simplement un dictionnaire JSON. Comme GitLab a rendu son code open-source, il est facile de générer sa propre licence.

### **src/generator.license.rb**

Le dossier `lib` est extrait du code source de GitLab. Il est utilisé pour générer et valider la licence. Le script `src/generator.license.rb` le charge pour effectuer cette tâche.

### **src/scan.features.rb**

Les fonctionnalités sont extraites d'un objet contenant des constantes. Le plan le plus complet est **Ultimate**, mais des fonctionnalités comme le Geo Mirroring ne sont incluses dans aucun plan standard. Nous les ajoutons donc manuellement.

## Utilisation

### Prérequis

Avant de commencer, assurez-vous que votre environnement est correctement configuré.

#### 1. Installer Ruby et gem
Pour exécuter ce projet, vous devez installer **Ruby** et le gestionnaire de paquets **gem**.

- **Sous Linux (Ubuntu/Debian)** :
  ```bash
  sudo apt update
  sudo apt install ruby-full
  ```

- **Sous macOS** (via Homebrew) :
  ```bash
  brew install ruby
  ```

#### 2. Installer Bundler et les gems nécessaires
Une fois Ruby installé, vous devez installer **Bundler** pour gérer les dépendances Ruby.

```bash
gem install bundler
```

#### 3. Installer le gem `gitlab-license`
Le projet nécessite le gem `gitlab-license`, qui sera automatiquement téléchargé et utilisé par le script.

```bash
gem install gitlab-license
```

### Étapes pour générer la licence GitLab

#### 1. Cloner le dépôt du projet
Clonez ce projet sur votre machine locale.

```bash
git clone https://github.com/Lakr233/GitLab-License-Generator.git
cd GitLab-License-Generator
```

#### 2. Exécuter le script `make.sh`
Une fois que tous les prérequis sont en place, exécutez le script :

```bash
./make.sh
```

Le script effectuera les actions suivantes :
- Téléchargement et extraction du gem `gitlab-license`.
- Copie et modification des fichiers nécessaires.
- Clonage du code source GitLab depuis GitLab.com.
- Génération d’une paire de clés publique/privée.
- Génération d’une licence GitLab.

#### 3. Remplacer la clé publique dans GitLab
Le script génère une clé publique dans le fichier `build/public.key`. Vous devez remplacer la clé publique utilisée par GitLab avec celle générée pour que la licence soit acceptée.

- **Si GitLab est installé sur votre serveur** :
  ```bash
  sudo cp ./build/public.key /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub
  sudo gitlab-ctl reconfigure
  sudo gitlab-ctl restart
  ```

- **Si GitLab est installé via Docker** :
  Modifiez votre fichier `docker-compose.yml` pour monter la nouvelle clé publique dans le conteneur :

  ```yaml
  volumes:
    - "./build/public.key:/opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub"
  ```

  Puis redémarrez le conteneur :
  ```bash
  docker-compose down
  docker-compose up -d
  ```

#### 4. Installer la licence dans GitLab
Une fois la clé publique remplacée, connectez-vous à l'interface d'administration de GitLab pour installer la licence générée.

1. Connectez-vous à GitLab en tant qu’administrateur.
2. Accédez à **Admin Area** via le coin supérieur droit.
3. Allez dans **Settings > General** et téléchargez le fichier de licence généré (`build/result.gitlab-license`).
4. Cochez la case **Terms of Service** et cliquez sur **Add License**.

Si nécessaire, accédez directement à la page de téléchargement de la licence via :
```
<YourGitLabURL>/admin/license/new
```

#### 5. Désactiver Service Ping (optionnel)
Si vous souhaitez désactiver la collecte de données d'utilisation par GitLab (Service Ping), modifiez le fichier de configuration GitLab :

- Ouvrez le fichier de configuration :
  ```bash
  sudo nano /etc/gitlab/gitlab.rb
  ```

- Ajoutez la ligne suivante :
  ```bash
  gitlab_rails['usage_ping_enabled'] = false
  ```

- Reconfigurez et redémarrez GitLab :
  ```bash
  sudo gitlab-ctl reconfigure
  sudo gitlab-ctl restart
  ```

### Résolution des problèmes

- **Erreur HTTP 502** :
  Si vous obtenez cette erreur, patientez simplement, car GitLab peut mettre du temps à démarrer.

## LICENCE

Ce projet est sous licence **WTFPL License**.

Copyright (c) 2023, Tim Cook, All Rights Not Reserved.
