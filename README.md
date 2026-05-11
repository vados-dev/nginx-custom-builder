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

## Telegram secrets

Нужны:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`