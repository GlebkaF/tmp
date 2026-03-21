# Multi-env Docker Compose demo

Минимальный пример для одной жирной машины, где можно поднимать много независимых dev-сред.

Что внутри:
- один общий `traefik` на хосте
- много sandbox-окружений через `docker compose -p <env_id>`
- в каждом sandbox:
  - `api` (FastAPI)
  - `web` (Next.js)
  - `postgres`
- красивые URL вместо сырых портов

## Идея

Один sandbox = один compose project.

Примеры:

```bash
./scripts/create-env.sh env-101
./scripts/create-env.sh env-102
```

После этого, если у тебя настроен wildcard DNS на хост, будут доступны URL:

- `http://env-101.dev.localtest.me` -> web
- `http://api.env-101.dev.localtest.me` -> api
- `http://env-102.dev.localtest.me` -> web
- `http://api.env-102.dev.localtest.me` -> api

`localtest.me` резолвится в `127.0.0.1`, так что для локальной отладки это удобно. Для внутренней сети замени `BASE_DOMAIN` на свой домен, например `dev.internal`.

## Структура

```text
traefik/                  # общий reverse proxy на хосте
sandbox/                  # шаблон одной среды
scripts/                  # create/destroy helpers
```

## 1. Поднять Traefik один раз на хосте

```bash
cd traefik
docker compose up -d
```

Traefik слушает `80`, читает Docker labels и маршрутизирует трафик в нужные контейнеры.

## 2. Поднять sandbox

Из корня проекта:

```bash
./scripts/create-env.sh env-101
```

С параметрами:

```bash
BASE_DOMAIN=dev.localtest.me POSTGRES_PASSWORD=postgres ./scripts/create-env.sh env-101
```

## 3. Удалить sandbox

```bash
./scripts/destroy-env.sh env-101
```

## Как это работает

### Traefik

Traefik живёт отдельно и постоянно. Новые sandbox-окружения не редактируют его конфиг руками. Вместо этого `web` и `api` получают Docker labels, например:

- `env-101.dev.localtest.me`
- `api.env-101.dev.localtest.me`

Traefik видит эти labels через Docker provider и автоматически публикует маршруты.

### Compose per environment

Один и тот же `sandbox/docker-compose.yml` можно поднимать много раз:

```bash
docker compose -p env-101 -f sandbox/docker-compose.yml up -d
docker compose -p env-102 -f sandbox/docker-compose.yml up -d
```

Compose сам изолирует контейнеры, сети и тома по имени проекта.

## Переменные

Основные переменные:

- `ENV_ID` — идентификатор среды, например `env-101`
- `BASE_DOMAIN` — базовый домен, по умолчанию `dev.localtest.me`
- `POSTGRES_PASSWORD` — пароль Postgres, по умолчанию `postgres`
- `NEXT_PUBLIC_API_BASE_URL` — URL API, автоматически собирается в `create-env.sh`

## Что здесь упрощено

Это dev-демо. Здесь нет:
- миграций
- secrets manager
- ClickHouse / Redis
- auth
- TTL / garbage collection

Но как базовый шаблон под твою идею это уже рабочая схема.

## Дальше что можно докрутить

1. Добавить Redis/ClickHouse в `sandbox/docker-compose.yml`
2. Добавить init-контейнер для миграций
3. Генерировать уникальный пароль/БД на каждую среду
4. Повесить cleanup по TTL
5. Добавить `Makefile`
