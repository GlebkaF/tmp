import os
import time
import uuid
from contextlib import asynccontextmanager

import psycopg2
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

ENV_ID = os.environ.get("ENV_ID", "unknown")
DATABASE_URL = os.environ["DATABASE_URL"]


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def init_db():
    for attempt in range(5):
        try:
            conn = get_conn()
            break
        except psycopg2.OperationalError:
            time.sleep(2)
    else:
        raise RuntimeError("Cannot connect to Postgres after 5 attempts")

    with conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS demo_messages (
                    id SERIAL PRIMARY KEY,
                    env_name TEXT NOT NULL,
                    body TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT NOW()
                )
            """)
            cur.execute(
                "SELECT 1 FROM demo_messages WHERE env_name = %s", (ENV_ID,)
            )
            if cur.fetchone() is None:
                body = f"random-row-{uuid.uuid4().hex[:8]}"
                cur.execute(
                    "INSERT INTO demo_messages (env_name, body) VALUES (%s, %s)",
                    (ENV_ID, body),
                )
    conn.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "env": ENV_ID}


@app.get("/message")
def message():
    conn = get_conn()
    with conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT body FROM demo_messages WHERE env_name = %s", (ENV_ID,)
            )
            row = cur.fetchone()
    conn.close()
    return {"env": ENV_ID, "message": row[0] if row else None}
