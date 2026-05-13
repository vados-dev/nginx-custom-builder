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

Также использовоны красивые шаблоны [отсюда](https://api.reuse.software/info/github.com/joppuyo/nice-nginx-error-page) и настроены простые кастомные страницы с ошибками, для всего сервера.
В этом мне помогла [статья с хабра](https://habr.com/ru/articles/652479/).

### Нужные secrets в `Settings -> Secrets and variables -> Actions`

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `RPM_GPG_PRIVATE_KEY` (опционально, для подписи RPM)

## GitHub Actions: авто-проверка и Telegram

### Telegram secrets

Нужны:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

## Приоритет платформ

- Основной контур: **RPM/CentOS** (боевой сценарий).
- Debian: поддерживается, но сейчас вторичен.
- Alpine: поддерживается в первую очередь для Docker-сценариев.

# nginx-custom-builder

Минимальный оркестратор сборки через `pkg-oss`.

## Что теперь в репозитории

- `config/targets.json` — цели сборки по ОС/образам (`enabled: true|false`).
- `config/modules.json` — каналы (`stable/mainline`) и параметры вызова `build_module.sh`.
- `scripts/detect-channel-update.sh` — проверка обновления nginx-версии по каналу.
- `scripts/build-pkg-oss.sh` — запуск сборки внутри контейнера: clone `pkg-oss` -> `make` -> `build_module.sh`.
- `.github/workflows/check-version.yml` — единственный scheduled workflow.
- `src/` — файлы, копируемые в рабочий клон `pkg-oss` внутри сборки.

## Логика workflow

1. По расписанию проверяет версии `mainline` и `stable`.
2. Если есть обновление, обновляет `.github/version-state/nginx-<channel>.txt`.
3. Строит матрицу только по `enabled=true` целям из `config/targets.json`.
4. Для каждой цели запускает сборку в её контейнере.
5. Отправляет Telegram-уведомления о найденных обновлениях и о результате сборки.

## Где включать/выключать ОС

Файл `config/targets.json`:

- `enabled: true` — сборка активна.
- `enabled: false` — цель отключена.

Сейчас по умолчанию:
- `centos-10` включен,
- `almalinux-9` выключен.

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
