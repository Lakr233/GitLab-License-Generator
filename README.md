# GitLab License Generator

This project aims to generate a GitLab License for development purpose. If you encounter any problem, please solve them yourself.

Last tested on GitLab v16.11.0-ee .

## Principles

**src/generator.keys.rb**

The GitLab uses public/private key pair to encrypt the license. The public key is shipped with the GitLab distro and the private key is kept privately. The license it self is just a json dictionary. Since GitLab made their code open source, we can easily generate a license by our own.

**src/generator.license.rb**

The `lib` folder is extracted from GitLab's source. It is used for building and validating the license. Script `src/generator.license.rb` will load it.

**src/scan.features.rb**

The features is extracted from a object full of constant. The most powerful plan for a license is ultimate, but features like geo mirror is not included in any type of the plan. So here by we add them manually.

## Usage

Follow the procedure below to generate and install a license for your development use.

### Get License

**GitHub Action**

Navigate to GitHub Action to download an artifact.

**make.sh**

This script is only tested on macOS. To build on Linux or other platform, you need to setup ruby with gem. 

### Install Test Key

You will need to replace the public key shipped within GitLab distro. It is located at `/opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub` most of the time.

If you are using Docker, there is a easy way to do this.

```yml
image: "gitlab/gitlab-ee:latest"
# ...
volumes:
    - "public.key:/opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub"
```

### Install License

See [GitLab Document](https://archives.docs.gitlab.com/16.3/ee/administration/license_file.html). Follow are part of the document.

- Sign in to GitLab as an administrator.
- On the left sidebar, expand the top-most chevron.
- Select Admin Area.
- Select Settings > General.
- or entering the key.
- Select the Terms of Service checkbox.
- Select Add license.

> In GitLab 14.7.x to 14.9.x, you can add the license file with the UI. In GitLab 14.1.x to 14.7, if you have already activated your subscription with an activation code, you cannot access Add License from the Admin Area. You must access Add License directly from the URL, <YourGitLabURL>/admin/license/new.

### Disable Service Ping

> Service Ping is a GitLab process that collects and sends a weekly payload to GitLab. The payload provides important high-level data that helps our product, support, and sales teams understand how GitLab is used.

See [GitLab Document](https://docs.gitlab.com/ee/development/internal_analytics/service_ping) for details.

## LICENSE

This project is licensed under the WTFPL License.

Copyrigth (c) 2023, Tim Cook, All Rights Not Reserved.
