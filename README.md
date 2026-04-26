# Nginx-custom-builder for CentOS/Debian/Alpine/alpine-slim

## Обновлённый [nginx-rpmbuild](https://github.com/archsh/nginx-rpmbuild)

### Описание

Инструмент для сборки `rpm` пакета [Nginx](http://nginx.org/), с возможностью подключения и сборки кастомных модулей.

### За основу взяты

1) [nginx-rpmbuild](https://github.com/archsh/nginx-rpmbuild).
2) [pkg-oss](https://github.com/nginx/pkg-oss).

<sub>Т.е. по сути, сборщик не только для Centos, а может быть использован для других платформ тоже. НО! Мной не тестировано т.к. идея была в другом...</sub>

<sub>А именно:</sub>

<sub>Т.к. использую некоторые не стандартные модули, хочется иметь возможность обновлять Nginx по фен-шую, вместе с другими системными пакетами.</sub>

<sub>Конфиги тоже никто не отменял, их интегрирую в сборщик и на выходе получаю знакомо настроенный веб-морд.</sub>

## В чём `волшебство`

Писали мы это чудо с codex 5.1-5.4.
Поэтому как минимум было весело. Правда Codex тот ещё любитель изобретать "велосипед", чем знатно меня побешивал временами.
Но тем не менее получилось два билдера, один работает прямо здесь, второй можно запускать локально.
В рабочий комплект, включены прямо из репо (доставляются при помощи `git clone`) и настроены:

1. [ngx_markdown_filter_module](https://github.com/ukarim/ngx_markdown_filter_module).
2. [ngx_http_include_server_module](https://github.com/RekGRpth/ngx_http_include_server_module).
3. [ngx_http_error_page_inherit_module](https://github.com/RekGRpth/ngx_http_error_page_inherit_module).
4. [ngx_http_acme_module](https://github.com/nginx/nginx-acme).
5. [Dynamic module njs](https://github.com/nginx/njs).

Также использовоны красивые шаблоны [отсюда](https://api.reuse.software/info/github.com/joppuyo/nice-nginx-error-page) и настроены простые кастомные страницы с ошибками, для всего сервера.
В этом мне помогла [статья с хабра](https://habr.com/ru/articles/652479/).

## GitHub Actions: авто-проверка и Telegram

### Какие workflow сейчас используются

- `.github/workflows/check-version.yml` — оркестратор:
  1. Проверяет новую версию nginx для `stable/mainline`.
  2. Пишет state в `.github/version-state/nginx-<channel>.txt`.
  3. Отправляет уведомление в Telegram.
  4. Запускает 3 сборки параллельно:
     - RPM: `.github/workflows/build.yml`
     - DEB: `.github/workflows/build-debian.yml`
     - APK (кастомные модули): `.github/workflows/build-custom-alpine.yml`
- `.github/workflows/build-alpine.yml` — отдельный workflow зеркалирования upstream Alpine-пакетов nginx.org (не сборка кастомных модулей).

### Входные параметры `check-version.yml` (актуально)

Базовые:

- `nginx_channel`: `all|mainline|stable`
- `build_args`: `-bb|-ba` (для RPM)
- `disable_debug_packages`: выключение debug/debuginfo пакетов (RPM/DEB/APK)
- `force_build`: собрать даже если версия nginx не изменилась
- `build_os`: `All|APK|debian|ubuntu|centos|almalinux|rhel`
- `publish_repos`: единый тумблер публикации репозиториев в `gh-pages`
- `ci_container_image`: тег CI-образа (без `ghcr.io/...`, например `lts`)

Профили модулей:

- `modules_common`: общий набор для всех платформ
- `modules_rpm_extra`: доп.модули только для RPM
- `modules_deb_extra`: доп.модули только для Debian
- `modules_alpine_extra`: доп.модули только для Alpine

Override модулей (полная замена профиля):

- `modules_rpm_override`
- `modules_deb_override`
- `modules_alpine_override`

Параметры путей/OS:

- `rpm_repo_release`: `10|9` (для structured RPM пути)
- `debian_suite`: например `trixie|bookworm|bullseye`
- `alpine_version`: например `3.20`

Логика модулей:

- если `*_override` пуст, итоговый набор = `modules_common + modules_<platform>_extra`
- если `*_override` задан, используется только override-набор для этой платформы
- по умолчанию Alpine профиль минимальный (под Docker-сценарий), RPM/DEB — шире

### Нужные secrets в `Settings -> Secrets and variables -> Actions`

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `RPM_GPG_PRIVATE_KEY` (опционально, для подписи RPM)

Состояние последней собранной версии хранится в `.github/version-state/nginx-<channel>.txt`.

## Приоритет платформ

- Основной контур: **RPM/CentOS** (боевой сценарий).
- Debian: поддерживается, но сейчас вторичен.
- Alpine: поддерживается в первую очередь для Docker-сценариев.

### DNF repo from GitHub Pages (основной сценарий)

`build.yml` теперь публикует готовый DNF-репозиторий (с `repodata`) в ветку `gh-pages`:

- `repo/mainline/x86_64`
- `repo/stable/x86_64`
- `repo/centos/10/mainline/x86_64`
- `repo/centos/10/stable/x86_64`

`repo/<os>/<release>/<channel>/...` формируется из:

- `build_os` (в check-version, для RPM это `centos|almalinux|rhel`)
- `rpm_repo_release` (`10|9`)

### Перед использованием включить GitHub Pages

- `Settings -> Pages -> Build and deployment -> Deploy from a branch`
- Branch: `gh-pages` (root)

### Подключение репозитория на CentOS/RHEL-подобных

Создай `/etc/yum.repos.d/nginx-custom.repo`:

```ini
[nginx-custom-mainline]
name=Custom nginx mainline
baseurl=https://<github-user>.github.io/<repo>/repo/centos/$releasever/mainline/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://<github-user>.github.io/<repo>/repo/RPM-GPG-KEY-nginx
```

### Пример source repo

```ini
[nginx-custom-mainline-source]
name=Custom nginx mainline source
baseurl=https://<github-user>.github.io/<repo>/repo/centos/$releasever/mainline/SRPMS/
enabled=0
gpgcheck=1
gpgkey=https://<github-user>.github.io/<repo>/repo/RPM-GPG-KEY-nginx
```

Если собираешь `stable`, поменяй в `baseurl` `mainline` -> `stable`.

Legacy fallback (без `$releasever/$basearch`, оставлен для совместимости):
`https://<github-user>.github.io/<repo>/repo/mainline/x86_64/`

### Проверка и обновление

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf upgrade "nginx*"
```

## Debian (APT) repo from GitHub Pages (вторичный контур)

`build-debian.yml` публикует репозиторий в:

- `repo/debian/<suite>/<channel>/binary-<arch>/Packages`
- `repo/debian/<suite>/<channel>/binary-<arch>/Packages.gz`
- `repo/debian/<suite>/<channel>/Release`

Также есть OS-специфичный путь:

- `repo/<debian|ubuntu>/<suite>/<channel>/binary-<arch>/...`

## Alpine (APK) custom repo for Docker (вторичный контур)

`build-custom-alpine.yml` публикует кастомно собранные APK в:

- `repo/alpine/v<alpine-version>/<channel>/<arch>/APKINDEX.tar.gz`
- `repo/alpine/v<alpine-version>/<channel>/<arch>/*.apk`
- `repo/alpine/keys/*.pub` (если ключ сборщика доступен)

### Пример для Alpine `3.20` и `mainline`

```sh
echo "https://vados-dev.github.io/nginx-custom-builder/repo/alpine/v3.20/mainline" >> /etc/apk/repositories
# если опубликован публичный ключ сборки:
# wget -O /etc/apk/keys/<builder-key>.pub https://vados-dev.github.io/nginx-custom-builder/repo/alpine/keys/<builder-key>.pub
apk update
apk add nginx
```

## Alpine-slim Docker image (целевой артефакт)

Если нужен именно готовый образ на базе официального `nginx:*-alpine-slim`, а не APK-repo, используйте workflow `.github/workflows/build-alpine-slim-image.yml`.

Он делает следующее:

- берёт базовый образ вроде `nginx:mainline-alpine-slim`
- может взять APK либо из artifact текущего workflow run, либо из вашего APK repo
- ставит пакеты вроде `nginx-module-markdown-filter nginx-module-error-page-inherit nginx-module-include-server`
- собирает и при необходимости пушит готовый image в registry

Dockerfile для этого контура лежит в `docker/alpine-slim/Dockerfile`.

### Локальная сборка и запуск образа из Dockerfile

Сборка из уже опубликованного APK repo:

```sh
mkdir -p /tmp/nginx-alpine-slim-empty

docker build \
  -f docker/alpine-slim/Dockerfile \
  -t nginx-custom:mainline-alpine-slim \
  --build-arg BASE_IMAGE=nginx:mainline-alpine-slim \
  --build-arg APK_REPO_URL=https://vados-dev.github.io/nginx-custom-builder/repo/alpine/v3.20/mainline \
  --build-arg APK_KEY_URL=https://vados-dev.github.io/nginx-custom-builder/repo/alpine/keys/abuild-key.rsa.pub \
  --build-arg ENABLED_MODULES="nginx-module-markdown-filter nginx-module-error-page-inherit nginx-module-include-server" \
  /tmp/nginx-alpine-slim-empty
```

Сборка из локальной папки с готовыми `.apk` без публикации repo:

```sh
mkdir -p /tmp/nginx-alpine-slim-local/apk-packages
cp /path/to/nginx-module-markdown-filter-*.apk /tmp/nginx-alpine-slim-local/apk-packages/
cp /path/to/nginx-module-error-page-inherit-*.apk /tmp/nginx-alpine-slim-local/apk-packages/
cp /path/to/nginx-module-include-server-*.apk /tmp/nginx-alpine-slim-local/apk-packages/
cp docker/alpine-slim/Dockerfile /tmp/nginx-alpine-slim-local/Dockerfile

docker build \
  -f /tmp/nginx-alpine-slim-local/Dockerfile \
  -t nginx-custom:mainline-alpine-slim-local \
  --build-arg BASE_IMAGE=nginx:mainline-alpine-slim \
  --build-arg ENABLED_MODULES="nginx-module-markdown-filter nginx-module-error-page-inherit nginx-module-include-server" \
  /tmp/nginx-alpine-slim-local
```

Запуск:

```sh
docker run --rm -it -p 8080:80 --name nginx-custom-slim nginx-custom:mainline-alpine-slim
```

Проверка модулей внутри контейнера:

```sh
docker exec -it nginx-custom-slim nginx -T
docker exec -it nginx-custom-slim ls -la /usr/lib/nginx/modules/
docker exec -it nginx-custom-slim cat /etc/nginx/modules/50-custom-dynamic-modules.conf
```

Важно:

- APK-модули должны быть собраны под совместимые `nginx`, Alpine и архитектуру
- для поддержанных пакетов workflow сразу добавляет `load_module`-конфиг в `/etc/nginx/modules/*.conf`
- `check-version.yml` теперь после Alpine APK-сборки может автоматически собрать и `alpine-slim` image из этих же artifact-ов

## Запуск workflow GitHub c локального CentOS

```sh
crontab -e

# mainline: еженедельно
17 3 * * 1 /usr/bin/flock -n /tmp/nginx-check-mainline.lock /bin/bash -lc 'export HOME=/home/git; export PATH=/usr/local/bin:/usr/bin:/bin; cd /home/git/projects/nginx-custom-builder && /usr/bin/gh workflow run "Check nginx version" -f nginx_channel=mainline -f build_os=centos -f rpm_repo_release=10 -f build_args=-bb -f disable_debug_packages=true -f force_build=false -f publish_repos=true -f ci_container_image=lts >> /home/git/projects/nginx-custom-builder/.github/cron-mainline.log 2>&1'

# stable: еженедельно без пересечения с mainline
27 3 * * 1 /usr/bin/flock -n /tmp/nginx-check-stable.lock /bin/bash -lc 'export HOME=/home/git; export PATH=/usr/local/bin:/usr/bin:/bin; cd /home/git/projects/nginx-custom-builder && /usr/bin/gh workflow run "Check nginx version" -f nginx_channel=stable -f build_os=centos -f rpm_repo_release=10 -f build_args=-bb -f disable_debug_packages=true -f force_build=false -f publish_repos=true -f ci_container_image=lts >> /home/git/projects/nginx-custom-builder/.github/cron-stable.log 2>&1'

crontab -l
```

### Проверка `gh` под пользователем `git`:

```sh
sudo -u git -H /usr/bin/gh auth status
```

### Запуск локально через Docker (как у CI)

```sh
docker run --rm -it -v "$PWD":/work -w /work quay.io/centos/centos:stream10 bash -lc 'chmod +x scripts/check-version-local.sh
CHANNEL=mainline FORCE_BUILD=false WRITE_STATE=false scripts/check-version-local.sh'
```

### Если надо сразу записать state-файл

```sh
  docker run --rm -it -v "$PWD":/work -w /work quay.io/centos/centos:stream10 bash -lc 'chmod +x scripts/check-version-local.sh
  CHANNEL=mainline WRITE_STATE=true scripts/check-version-local.sh'
```

  Для stable:

  ... CHANNEL=stable ...

### В scripts/check-version-local.sh теперь

- добавлен summary-блок в конце,
- добавлены коды выхода:
    1. 0 если should_build=false (reason=unchanged)
    2. 10 если should_build=true (reason=new-version или manual-force)

  Пример проверки кода выхода в Docker:

```sh
docker run --rm -i -v "$(pwd):/work" -w /work quay.io/centos/centos:stream10 bash -lc 'CHANNEL=mainline WRITE_STATE=false scripts/check-version-local.sh
rc=$?
echo "exit_code=$rc"'
```

## Перевели на compose-only

  Что добавили:

- docker-compose.ci.yml с build + image + volume + runner.
- Обновил Makefile: все ci-* теперь через docker compose, без swarm.

  Как запускать теперь:

```sh
  make ci-build
  make ci-deploy
  make ci-ps
  make ci-check-all
```

## Сборка RPM

```sh
  make ci-rpm-mainline
```

### или

```sh
  make ci-rpm-stable
```

По умолчанию версия nginx для сборки берётся из `nginx.org` автоматически по `CHANNEL` и `/etc/os-release` внутри контейнера.
При необходимости можно переопределить репозиторий/ОС/релиз:

```sh
make ci-rpm-mainline CI_NGINX_REPO_OS=centos CI_NGINX_REPO_RELEASE=10
```

### Остановить

```sh
  make ci-rm
```

### Такой flow ровно как и хотелось

  compose build --pull + compose up -d, и дальше по запросу запуск чек/сборки.

## Куда складываются RPM после ci-rpm

После `make ci-rpm-mainline` и `make ci-rpm-stable` артефакты автоматически копируются в:

`/.data/nfs/dst/nginx/RPMS`

Если нужен другой путь:

```sh
make ci-rpm-mainline CI_ARTIFACTS_DIR=/your/path
```
  
> <sub>Ниже мои/мне подсказки из самого начала этого пути )))</sub>

### RPM and Key

- [Package RPM Nginx Instructions](https://www.dmosk.ru/miniinstruktions.php?mini=package-rpm-nginx)

### CentOS Packages and Repos

- [nginx Mainline CentOS 10 SRPMS](https://nginx.org/packages/mainline/centos/10/SRPMS/)

### Markdown Modules

1. [Markdown Module 1](https://nginx-extras.getpagespeed.com/modules/markdown/)
2. [Markdown Filter Module](https://github.com/bet0x/ngx_markdown_filter_module)

## Signing

Sign the RPM package:

```bash
rpm --addsign rpmbuild/RPMS/x86_64/nginx-1.29.5-1.el10.ngx.x86_64.rpm
```
