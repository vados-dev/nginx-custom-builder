# Nginx-rpmbuild for CentOS 10

## Обновлённый [nginx-rpmbuild](https://github.com/archsh/nginx-rpmbuild)

### Описание

Инструмент для сборки `rpm` пакета [Nginx](http://nginx.org/), с возможностью подключения и сборки кастомных модулей.

### За основу взяты

1) [nginx-rpmbuild](https://github.com/archsh/nginx-rpmbuild).
2) [pkg-oss](http://hg.nginx.org/pkg-oss).

<sub>Т.е. по сути, сборщик не только для Centos 10, а может быть использован для других платформ тоже. НО! Мной не тестировано т.к. идея была в другом...</sub>

<sub>А именно:</sub>

<sub>Т.к. использую некоторые не стандартные модули, хочется иметь возможность обновлять Nginx по фен-шую, вместе с другими системными пакетами.</sub>

<sub>Конфиги тоже никто не отменял, их интегрирую в сборщик и на выходе получаю знакомо настроенный веб-морд.</sub>

## В чём волшебство

Писали мы это чудо с codex 5.1-5.3.
Поэтому как минимум было весело. Правда Codex тот ещё любитель изобретать "велосипед", чем знатно меня побешивал временами.
Но тем не менее получилось два билдера, один работает прямо здесь, второй можно запускать локально.
В рабочий комплект, включены прямо из репок (доставляются при помощи `git clone`) и настроены:

1. [ngx_markdown_filter_module](https://github.com/ukarim/ngx_markdown_filter_module).
2. [ngx_http_include_server_module](https://github.com/RekGRpth/ngx_http_include_server_module).
3. [ngx_http_error_page_inherit_module](https://github.com/RekGRpth/ngx_http_error_page_inherit_module).<br />
Также использовоны красивые шаблоны отсюда: [![REUSE status](https://api.reuse.software/badge/github.com/joppuyo/nice-nginx-error-page)](https://api.reuse.software/info/github.com/joppuyo/nice-nginx-error-page) и настроены простые кастомные страницы с ошибками, для всего сервера.
В этом мне помогла [статья с хабра](https://habr.com/ru/articles/652479/).

## GitHub Actions: авто-проверка и Telegram

### В репозитории настроены два workflow

- `.github/workflows/check-version.yml` - проверяет новую версию nginx по расписанию (каждые 6 часов), отправляет уведомление в Telegram и запускает сборку при изменении версии.
- `.github/workflows/build.yml` - ручная и автоматическая сборка RPM (используется также как reusable workflow).

### Нужные secrets в `Settings -> Secrets and variables -> Actions`

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `RPM_GPG_PRIVATE_KEY` (опционально, для подписи RPM)
- `amsternl` (опционально, PAT; если не задан, workflow использует встроенный `GITHUB_TOKEN`)

Состояние последней собранной версии хранится в `.github/version-state/nginx-<channel>.txt`.

### DNF repo from GitHub Pages

`build.yml` теперь публикует готовый DNF-репозиторий (с `repodata`) в ветку `gh-pages`:

- `repo/mainline/x86_64`
- `repo/stable/x86_64`
- `repo/centos/10/mainline/x86_64`
- `repo/centos/10/stable/x86_64`

### Перед использованием включить GitHub Pages

- `Settings -> Pages -> Build and deployment -> Deploy from a branch`
- Branch: `gh-pages` (root)

### Пример `.repo` для mainline

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

Legacy fallback (без `$releasever/$basearch`):
`https://<github-user>.github.io/<repo>/repo/mainline/x86_64/`

### Проверка и обновление

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf upgrade "nginx*"
```

## Alpine (APK) repo for Docker

Для Alpine добавлен workflow `.github/workflows/build-alpine.yml`.
Он синхронизирует пакеты `stable/mainline` из `nginx.org` в `gh-pages`:

- `repo/alpine/v<alpine-version>/<channel>/<arch>/APKINDEX.tar.gz`
- `repo/alpine/keys/nginx_signing.rsa.pub`
По умолчанию публикуется только последняя версия каждого пакета, `*-dbg` исключены.

### Пример для Alpine `3.20` и `mainline`

```sh
echo "https://vados-dev.github.io/nginx-rpmbuild/repo/alpine/v3.20/mainline" >> /etc/apk/repositories
wget -O /etc/apk/keys/nginx_signing.rsa.pub https://vados-dev.github.io/nginx-rpmbuild/repo/alpine/keys/nginx_signing.rsa.pub
apk update
apk add nginx
```

## Запуск workflow GitHub c локального CentOS

```sh
crontab -e

# mainline: еженедельно
17 3 * * 1 /usr/bin/flock -n /tmp/nginx-check-mainline.lock /bin/bash -lc 'export HOME=/home/git; export PATH=/usr/local/bin:/usr/bin:/bin; cd /home/git/projects/nginx-rpmbuild && /usr/bin/gh workflow run "Check nginx version" -f nginx_channel=mainline -f force_build=false >> /home/git/projects/nginx-rpmbuild/.github/cron-mainline.log 2>&1'

# stable: еженедельно без пересечения с mainline
27 3 * * 1 /usr/bin/flock -n /tmp/nginx-check-stable.lock /bin/bash -lc 'export HOME=/home/git; export PATH=/usr/local/bin:/usr/bin:/bin; cd /home/git/projects/nginx-rpmbuild && /usr/bin/gh workflow run "Check nginx version" -f nginx_channel=stable -f force_build=false >> /home/git/projects/nginx-rpmbuild/.github/cron-stable.log 2>&1'

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

  Остановить:

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
