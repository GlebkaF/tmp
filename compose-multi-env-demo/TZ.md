# ТЗ: демо-репозиторий для multi-env dev sandbox на одной машине

## Контекст

Нужно сделать максимально простой демонстрационный проект, который показывает, как на одной машине поднимать много независимых dev-окружений без Kubernetes и без виртуальных машин.

Каждое окружение должно подниматься как отдельный Docker Compose project и иметь:
- свой FastAPI backend
- свой Next.js frontend
- свой Postgres
- свои данные
- свои URL через общий Traefik

Это именно dev-демо. Прод не нужен. В проде используется Kubernetes.

---

## Цель

Сделать репозиторий, который можно использовать как reference implementation для идеи:

**одна машина -> один Traefik -> много compose-окружений -> у каждого окружения свой web/api/postgres**

Итог должен быть таким, чтобы можно было выполнить:

```bash
./scripts/create-env.sh env-101
./scripts/create-env.sh env-102
```

И получить два независимых окружения с разными доменами.

---

## Основные требования

### 1. Общая архитектура

Нужно реализовать структуру:

- один постоянный Traefik на хосте
- одна внешняя Docker network `traefik-public`
- один шаблон sandbox-окружения через Docker Compose
- одна среда = один `docker compose -p <env_id>`

### 2. Состав одного sandbox-окружения

Каждое окружение должно содержать:

- `postgres`
- `api` на FastAPI
- `web` на Next.js

### 3. Изоляция окружений

Каждое окружение должно быть изолировано через `docker compose -p <env_id>`.

Это означает, что у разных окружений должны быть независимые:
- контейнеры
- тома
- internal network
- данные в Postgres

### 4. Красивые URL

Нельзя использовать сырые наружные порты вида `localhost:31017`.

Нужно использовать общий Traefik и hostname-based routing.

Формат URL:
- `http://<env_id>.dev.localtest.me` -> frontend
- `http://api.<env_id>.dev.localtest.me` -> backend

Примеры:
- `http://env-101.dev.localtest.me`
- `http://api.env-101.dev.localtest.me`
- `http://env-102.dev.localtest.me`
- `http://api.env-102.dev.localtest.me`

### 5. Связь frontend -> api

Frontend обязательно должен делать реальный HTTP-запрос в backend.

Нужно, чтобы Next.js на клиенте или сервере запрашивал API по адресу:

```text
http://api.<env_id>.<base_domain>
```

Базовый URL API должен пробрасываться во frontend через env-переменную:
- `NEXT_PUBLIC_API_BASE_URL`

---

## Требования к данным

### 6. Подключение API к Postgres

FastAPI должен реально подключаться к Postgres.

Не просто иметь переменную `DATABASE_URL`, а действительно:
- открыть соединение
- создать таблицу, если её нет
- положить demo-данные
- уметь прочитать их обратно

### 7. Таблица в базе

Нужно создать таблицу, например:

```sql
CREATE TABLE IF NOT EXISTS demo_messages (
  id SERIAL PRIMARY KEY,
  env_name TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
)
```

### 8. Инициализация данных

При старте API должно происходить следующее:

1. API ждёт доступности Postgres
2. Создаёт таблицу `demo_messages`, если она отсутствует
3. Проверяет, есть ли запись для текущего окружения
4. Если записи нет — вставляет одну строку

Вставляемая строка должна содержать:
- имя окружения (`env_name`) равное текущему `ENV_ID`
- случайный текст в `body`

Пример значения:
- `env_name = env-101`
- `body = random-row-a1b2c3d4`

### 9. Отдельность данных между окружениями

Если подняты `env-101` и `env-102`, то у каждого окружения должны быть свои данные.

На фронте `env-101` нельзя показывать запись `env-102`.

---

## Требования к API

### 10. Health endpoint

Нужен endpoint:

```http
GET /health
```

Ответ должен быть примерно таким:

```json
{
  "status": "ok",
  "env": "env-101"
}
```

### 11. Endpoint для demo-данных

Нужен endpoint:

```http
GET /message
```

Он должен вернуть запись из Postgres для текущего окружения.

Формат ответа:

```json
{
  "env": "env-101",
  "message": "random-row-a1b2c3d4"
}
```

### 12. CORS

Для dev-демо можно разрешить CORS максимально просто.

Например:
- `allow_origins=["*"]`
- `allow_methods=["*"]`
- `allow_headers=["*"]`

Без сложной security-настройки.

---

## Требования к frontend

### 13. Главная страница

На главной странице Next.js нужно показать:
- имя окружения
- данные, пришедшие из API
- текст из Postgres

Идея интерфейса:

```text
Sandbox env: env-101
API message: random-row-a1b2c3d4
```

### 14. Поведение frontend

Frontend должен при открытии страницы:
- выполнить запрос в API endpoint `/message`
- распарсить JSON
- отобразить `env` и `message`

### 15. Явная демонстрация связи

Нужно, чтобы было очевидно:
- frontend ходит в backend
- backend ходит в Postgres
- на экране показаны данные именно из БД

То есть цепочка должна быть реальной:

**Next.js -> FastAPI -> Postgres -> FastAPI -> Next.js**

---

## Требования к docker compose

### 16. Compose-файл sandbox

Нужен `sandbox/docker-compose.yml`, где описаны:
- `postgres`
- `api`
- `web`

### 17. Переменные окружения

В compose нужно использовать:
- `ENV_ID`
- `BASE_DOMAIN`
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `NEXT_PUBLIC_API_BASE_URL`

### 18. Traefik labels

У сервиса `api` должны быть labels для маршрута:
- `api.<env_id>.<base_domain>`

У сервиса `web` должны быть labels для маршрута:
- `<env_id>.<base_domain>`

### 19. Сети

Должны быть:
- внутренняя сеть sandbox, например `internal`
- внешняя сеть `traefik-public`

`api` и `web` должны быть подключены к `traefik-public`, чтобы Traefik мог слать в них трафик.

`postgres` должен жить только во внутренней сети.

---

## Требования к Traefik

### 20. Отдельный compose для Traefik

Нужен файл `traefik/docker-compose.yml`.

Traefik должен:
- слушать порт `80`
- использовать Docker provider
- читать labels из контейнеров
- публиковать сервисы автоматически

### 21. Dashboard

Для отладки можно оставить dashboard на `8080`.

---

## Требования к скриптам

### 22. Скрипт создания среды

Нужен `scripts/create-env.sh`.

Он должен:
- принимать `ENV_ID` первым аргументом
- выставлять дефолтный `BASE_DOMAIN=dev.localtest.me`
- выставлять дефолтный `POSTGRES_PASSWORD=postgres`
- экспортировать переменные
- запускать `docker compose -p <env_id> -f sandbox/docker-compose.yml up -d --build`
- печатать итоговые URL

Пример:

```bash
./scripts/create-env.sh env-101
```

После запуска должен печататься вывод вида:

```text
web: http://env-101.dev.localtest.me
api: http://api.env-101.dev.localtest.me/health
```

### 23. Скрипт удаления среды

Нужен `scripts/destroy-env.sh`.

Он должен:
- принимать `ENV_ID`
- выполнять:

```bash
docker compose -p <env_id> -f sandbox/docker-compose.yml down -v
```

---

## Требования к файлам проекта

Нужно добавить следующие файлы:

### Traefik
- `traefik/docker-compose.yml`

### Sandbox compose
- `sandbox/docker-compose.yml`

### FastAPI
- `sandbox/api/Dockerfile`
- `sandbox/api/requirements.txt`
- `sandbox/api/main.py`

### Next.js
- `sandbox/web/Dockerfile`
- `sandbox/web/package.json`
- `sandbox/web/pages/index.js`

### Scripts
- `scripts/create-env.sh`
- `scripts/destroy-env.sh`

---

## Требования к FastAPI реализации

### 24. Библиотеки

Минимально допустимо использовать:
- `fastapi`
- `uvicorn`
- `psycopg2-binary`

### 25. Поведение startup

При старте FastAPI приложение должно:
- сделать retry подключения к Postgres
- создать таблицу
- вставить запись для текущего `ENV_ID`, если её нет

### 26. Формирование random-строки

Для random-строки можно использовать:
- `uuid.uuid4().hex[:8]`

Например:

```python
f"random-row-{uuid.uuid4().hex[:8]}"
```

### 27. Привязка к env name
n
API должно брать имя окружения из env-переменной:
- `ENV_ID`

И использовать её:
- в ответе `/health`
- при вставке в БД
- при чтении из БД

---

## Требования к Next.js реализации

### 28. Минимальный UI

Страница может быть очень простой, без стилей или с минимальными inline styles.

Но она должна явно показывать:
- `env`
- `message`

### 29. Fetch в API

Фронт должен делать fetch в:

```javascript
process.env.NEXT_PUBLIC_API_BASE_URL + "/message"
```

### 30. Обработка ошибок

Если API не отвечает, можно показать error в JSON-виде. Сложный UI не нужен.

---

## Acceptance criteria

Считается выполненным, если:

1. Запущен Traefik
2. Команда `./scripts/create-env.sh env-101` поднимает окружение
3. Команда `./scripts/create-env.sh env-102` поднимает второе окружение
4. Открытие `http://env-101.dev.localtest.me` показывает данные из API
5. API для `env-101` возвращает `env=env-101`
6. В Postgres для `env-101` лежит строка с `env_name=env-101`
7. Открытие `http://env-102.dev.localtest.me` показывает другой env
8. Данные не конфликтуют между окружениями
9. Frontend реально ходит в backend
10. Backend реально ходит в Postgres

---

## Что не требуется

Специально не нужно делать:
- production deployment
- Kubernetes manifests
- Redis
- ClickHouse
- auth
- SSL/TLS
- migration framework
- secrets manager
- background jobs
- TTL cleanup

Это должно остаться маленьким и понятным демо.

---

## Дополнительно

Если будет время, можно потом отдельно докрутить:
- live reload через bind mounts
- Alembic migrations
- healthcheck/wait-for-db
- генерацию уникального пароля на каждый env
- Makefile

Но это уже не обязательная часть текущего ТЗ.
