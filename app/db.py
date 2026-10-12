"""
Database connection and helpers.

Uses a connection pool so we don't pay the TCP + auth cost on every request.
Reads credentials from environment variables injected at container startup
(which are fetched from SSM Parameter Store by the EC2 user_data script).
"""

import os
import time
import logging
from psycopg2 import pool
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration from environment variables
# ---------------------------------------------------------------------------
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

# Module-level pool; created lazily on first use
_pool = None


def get_pool():
    """Create the connection pool on first call, reuse it after that."""
    global _pool
    if _pool is None:
        logger.info(f"Creating DB pool → {DB_HOST}:{DB_PORT}/{DB_NAME}")
        _pool = pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=5,
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5,
        )
    return _pool


def init_db():
    """Create the visits table if it doesn't exist. Retry a few times."""
    for attempt in range(5):
        try:
            conn = get_pool().getconn()
            try:
                with conn.cursor() as cur:
                    cur.execute("""
                        CREATE TABLE IF NOT EXISTS visits (
                            id SERIAL PRIMARY KEY,
                            count BIGINT NOT NULL DEFAULT 0,
                            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                        );
                    """)
                    # Ensure a single row exists to store our counter
                    cur.execute("""
                        INSERT INTO visits (id, count)
                        VALUES (1, 0)
                        ON CONFLICT (id) DO NOTHING;
                    """)
                conn.commit()
            finally:
                get_pool().putconn(conn)
            logger.info("Database initialized")
            return
        except Exception as e:
            logger.warning(f"init_db attempt {attempt + 1} failed: {e}")
            time.sleep(2)
    logger.error("init_db exhausted retries")


def increment_and_get_visits():
    """Atomically increment the visit counter and return the new value."""
    conn = get_pool().getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                UPDATE visits
                SET count = count + 1, updated_at = NOW()
                WHERE id = 1
                RETURNING count;
            """)
            row = cur.fetchone()
        conn.commit()
        return row["count"] if row else None
    finally:
        get_pool().putconn(conn)


def get_visit_count():
    """Read the current visit count without incrementing."""
    conn = get_pool().getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT count FROM visits WHERE id = 1;")
            row = cur.fetchone()
        return row["count"] if row else 0
    finally:
        get_pool().putconn(conn)


def healthcheck():
    """Test DB connectivity — used by /db-test endpoint."""
    start = time.time()
    conn = get_pool().getconn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()
        latency_ms = round((time.time() - start) * 1000, 2)
        return {"connected": True, "latency_ms": latency_ms}
    finally:
        get_pool().putconn(conn)