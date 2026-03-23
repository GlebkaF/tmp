# Multi-env Docker Compose demo

Минимальный пример для одной жирной машины, где можно поднимать много независимых dev-сред.

Что внутри:
- один общий `caddy` на хосте (caddy-docker-proxy)
- много sandbox-окружений через `docker compose -p <env_id>`
- в каждом sandbox:
  - `api` (FastAPI)
  - `web` (Next.js)
  - `postgres`
- красивые URL вместо сырых портов

## Быстрый старт

```bash
./scripts/create-env.sh env-101
```

Одна команда — и всё готово. Скрипт сам:
1. Поднимет Caddy (если ещё не запущен)
2. Запустит sandbox-окружение
3. Выведет URL-ы

Можно поднять сколько угодно сред:

```bash
./scripts/create-env.sh env-101
./scripts/create-env.sh env-102
```

URL-ы:

- `http://env-101.dev.localtest.me` -> web
- `http://api.env-101.dev.localtest.me` -> api

`localtest.me` резолвится в `127.0.0.1`, так что для локальной отладки это удобно. Для внутренней сети замени `BASE_DOMAIN` на свой домен, например `dev.internal`.

## Удалить sandbox

```bash
./scripts/destroy-env.sh env-101
```

## Структура

```text
caddy/                    # общий reverse proxy на хосте
sandbox/                  # шаблон одной среды
scripts/                  # create/destroy helpers
```

## Как это работает

### Caddy

Caddy живёт отдельно и постоянно. `create-env.sh` поднимает его автоматически при первом запуске. Новые sandbox-окружения не редактируют его конфиг руками. Вместо этого `web` и `api` получают Docker labels, например:

- `env-101.dev.localtest.me`
- `api.env-101.dev.localtest.me`

Caddy видит эти labels через caddy-docker-proxy и автоматически публикует маршруты.

### SSR

Web-контейнер использует `extra_hosts` с `host-gateway`, чтобы домен `api.*.dev.localtest.me` резолвился в хост-машину (а не в `127.0.0.1` внутри контейнера). Это позволяет `getServerSideProps` ходить в API через Caddy.

### Compose per environment

Один и тот же `sandbox/docker-compose.yml` можно поднимать много раз:

```bash
docker compose -p env-101 -f sandbox/docker-compose.yml up -d
docker compose -p env-102 -f sandbox/docker-compose.yml up -d
```

Compose сам изолирует контейнеры, сети и тома по имени проекта.

## Переменные

- `ENV_ID` — идентификатор среды, например `env-101`
- `BASE_DOMAIN` — базовый домен, по умолчанию `dev.localtest.me`
- `POSTGRES_PASSWORD` — пароль Postgres, по умолчанию `postgres`

## Что здесь упрощено

Это dev-демо. Здесь нет:
- миграций
- secrets manager
- ClickHouse / Redis
- auth
- TTL / garbage collection
