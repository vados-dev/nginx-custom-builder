# Nginx-rpmbuild for CentOS 10
## Обновлённый [ nginx-rpmbuild ](https://github.com/archsh/nginx-rpmbuild)

### Описание
Инструмент для сборки `rpm` пакета [Nginx](http://nginx.org/), с возможностью подключения и сборки кастомных модулей. 
### За основу взяты:
1) [ nginx-rpmbuild ](https://github.com/archsh/nginx-rpmbuild).
2) [ pkg-oss ](http://hg.nginx.org/pkg-oss).

<sub>Т.е. по сути, сборщик не только для Centos 10, а может быть использован для других платформ тоже. НО! Мной не тестировано т.к. идея была в другом...
<br />
А именно:<br />
Т.к. использую некоторые не стандартные модули, хочется иметь возможность обновлять Nginx по фен-шую, вместе с другими системными пакетами.
<br />
Конфиги тоже никто не отменял, их интегрирую в сборщик и на выходе получаю знакомо настроенный веб-морд.</sub>
<br />

## В чём волшебство:
Писали мы это чудо с codex 5.1-5.3.
Поэтому как минимум было весело. Правда Codex тот ещё любитель изобретать "велосипед", чем знатно меня побешивал временами. 
Но тем не менее получилось два билдера, один работает прямо здесь, второй можно запускать локально.
В рабочий комплект, включены прямо из репок (доставляются при помощи `git clone`) и настроены:
1. [ ngx_markdown_filter_module ](https://github.com/ukarim/ngx_markdown_filter_module).
2. [ ngx_http_include_server_module ](https://github.com/RekGRpth/ngx_http_include_server_module).
3. [ ngx_http_error_page_inherit_module ](https://github.com/RekGRpth/ngx_http_error_page_inherit_module).<br />
Также использовоны красивые шаблоны отсюда: [![REUSE status](https://api.reuse.software/badge/github.com/joppuyo/nice-nginx-error-page)](https://api.reuse.software/info/github.com/joppuyo/nice-nginx-error-page) и настроены простые кастомные страницы с ошибками, для всего сервера.
В этом мне помогла [статья с хабра](https://habr.com/ru/articles/652479/).
<br /><br /><br /><br /><br /><br /><br />
<br /><br /><br /><br /><br /><br /><br />




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

## GitHub Actions: авто-проверка и Telegram

В репозитории настроены два workflow:
- `.github/workflows/check-version.yml` - проверяет новую версию nginx по расписанию (каждые 6 часов), отправляет уведомление в Telegram и запускает сборку при изменении версии.
- `.github/workflows/build.yml` - ручная и автоматическая сборка RPM (используется также как reusable workflow).

Нужные secrets в `Settings -> Secrets and variables -> Actions`:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `RPM_GPG_PRIVATE_KEY` (опционально, для подписи RPM)
- `amsternl` (опционально, PAT; если не задан, workflow использует встроенный `GITHUB_TOKEN`)

Состояние последней собранной версии хранится в `.github/version-state/nginx-<channel>.txt`.

## DNF repo from GitHub Pages

`build.yml` теперь публикует готовый DNF-репозиторий (с `repodata`) в ветку `gh-pages`:
- `repo/mainline/x86_64`
- `repo/stable/x86_64`

Перед использованием включи GitHub Pages:
- `Settings -> Pages -> Build and deployment -> Deploy from a branch`
- Branch: `gh-pages` (root)

Пример `.repo` для mainline:

```ini
[nginx-custom-mainline]
name=Custom nginx mainline
baseurl=https://<github-user>.github.io/<repo>/repo/mainline/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://<github-user>.github.io/<repo>/RPM-GPG-KEY-nginx
```

Проверка и обновление:

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf upgrade "nginx*"
```
