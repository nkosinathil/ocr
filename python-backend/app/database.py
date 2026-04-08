import logging
from contextlib import contextmanager
from typing import Any, Dict, List, Optional, Tuple, Union

import psycopg2
import psycopg2.extras
from psycopg2.extensions import connection

from app.config import get_settings

logger = logging.getLogger(__name__)


@contextmanager
def get_db_connection() -> connection:
    settings = get_settings()
    conn = None
    try:
        conn = psycopg2.connect(
            host=settings.DATABASE_HOST,
            port=settings.DATABASE_PORT,
            dbname=settings.DATABASE_NAME,
            user=settings.DATABASE_USER,
            password=settings.DATABASE_PASSWORD,
        )
        yield conn
    except psycopg2.Error:
        logger.exception("Database connection error")
        raise
    finally:
        if conn is not None:
            conn.close()


def execute_query(
    query: str,
    params: Optional[Union[Tuple, Dict[str, Any]]] = None,
    commit: bool = True,
) -> None:
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            if commit:
                conn.commit()


def execute_query_fetchone(
    query: str,
    params: Optional[Union[Tuple, Dict[str, Any]]] = None,
) -> Optional[Dict[str, Any]]:
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, params)
            return cur.fetchone()


def execute_query_fetchall(
    query: str,
    params: Optional[Union[Tuple, Dict[str, Any]]] = None,
) -> List[Dict[str, Any]]:
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, params)
            return cur.fetchall()
