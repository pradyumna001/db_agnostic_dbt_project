"""Load generated CSV batches into the raw schema of a target platform.

Connection settings come from the same environment variables as profiles/profiles.yml.
Usage: python data_generator/load.py --target postgres --data data --batch 1   (or --batch all)
"""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path

from generate import TABLES

TYPES = {
    # column -> canonical type
    "date_of_birth": "date",
    "created_at": "ts",
    "updated_at": "ts",
    "loaded_at": "ts",
    "order_ts": "ts",
    "paid_ts": "ts",
    "unit_price": "money",
    "unit_cost": "money",
    "shipping_amount": "money",
    "discount_amount": "money",
    "amount": "money",
    "quantity": "int",
    "line_number": "int",
    "is_active": "int",
    "batch_id": "int",
}
DDL_TYPES = {
    "postgres": {"str": "varchar(255)", "date": "date", "ts": "timestamp", "money": "numeric(18,2)", "int": "integer"},
    "sqlserver": {"str": "nvarchar(255)", "date": "date", "ts": "datetime2(6)", "money": "decimal(18,2)", "int": "int"},
    "oracle": {
        "str": "varchar2(255 char)",
        "date": "date",
        "ts": "timestamp(6)",
        "money": "number(18,2)",
        "int": "number(10)",
    },
    "snowflake": {
        "str": "varchar(255)",
        "date": "date",
        "ts": "timestamp_ntz",
        "money": "number(18,2)",
        "int": "integer",
    },
    "databricks": {"str": "string", "date": "date", "ts": "timestamp", "money": "decimal(18,2)", "int": "int"},
}


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def connect(target: str):
    if target == "postgres":
        import psycopg2

        return psycopg2.connect(
            host=env("PG_HOST", "localhost"),
            port=int(env("PG_PORT", "5432")),
            user=env("PG_USER", "dbt"),
            password=env("PG_PASSWORD"),
            dbname=env("PG_DATABASE", "analytics"),
        )
    if target == "sqlserver":
        import pyodbc

        trust = "yes" if env("MSSQL_TRUST_CERT", "false").lower() == "true" else "no"
        conn = pyodbc.connect(
            f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={env('MSSQL_HOST', 'localhost')},{env('MSSQL_PORT', '1433')};"
            f"DATABASE={env('MSSQL_DATABASE', 'analytics')};UID={env('MSSQL_USER')};PWD={env('MSSQL_PASSWORD')};"
            f"Encrypt=yes;TrustServerCertificate={trust}",
            autocommit=False,
        )
        return conn
    if target == "oracle":
        import oracledb

        return oracledb.connect(
            user=env("ORACLE_USER", "dbt"),
            password=env("ORACLE_PASSWORD"),
            dsn=f"{env('ORACLE_HOST', 'localhost')}:{env('ORACLE_PORT', '1521')}/{env('ORACLE_SERVICE', 'FREEPDB1')}",
        )
    if target == "snowflake":
        import snowflake.connector

        return snowflake.connector.connect(
            account=env("SNOWFLAKE_ACCOUNT"),
            user=env("SNOWFLAKE_USER"),
            private_key_file=env("SNOWFLAKE_PRIVATE_KEY_PATH"),
            role=env("SNOWFLAKE_ROLE"),
            warehouse=env("SNOWFLAKE_WAREHOUSE"),
            database=env("SNOWFLAKE_DATABASE"),
        )
    if target == "databricks":
        from databricks import sql
        from databricks.sdk.core import Config, oauth_service_principal

        cfg = Config(
            host=f"https://{env('DATABRICKS_HOST')}",
            client_id=env("DATABRICKS_CLIENT_ID"),
            client_secret=env("DATABRICKS_CLIENT_SECRET"),
        )
        return sql.connect(
            server_hostname=env("DATABRICKS_HOST"),
            http_path=env("DATABRICKS_HTTP_PATH"),
            credentials_provider=lambda: oauth_service_principal(cfg),
            catalog=env("DATABRICKS_CATALOG", "analytics"),
        )
    raise SystemExit(f"unknown target {target}")


def raw_schema(target: str) -> str:
    if target == "oracle":
        return env("ORACLE_USER", "dbt").upper()
    return env("DBT_RAW_SCHEMA", "raw")


def ensure_schema(cur, target: str, schema: str) -> None:
    if target == "oracle":
        return
    if target == "sqlserver":
        cur.execute(f"if schema_id('{schema}') is null exec('create schema {schema}')")
    else:
        cur.execute(f"create schema if not exists {schema}")


def table_exists(cur, target: str, schema: str, table: str) -> bool:
    if target == "oracle":
        cur.execute(
            "select count(*) from all_tables where owner = :1 and table_name = :2", [schema.upper(), table.upper()]
        )
    elif target == "sqlserver":
        cur.execute(
            "select count(*) from information_schema.tables where table_schema = ? and table_name = ?", [schema, table]
        )
    elif target == "databricks":
        cur.execute(f"show tables in {schema} like '{table}'")
        return len(cur.fetchall()) > 0
    else:
        cur.execute(
            f"select count(*) from information_schema.tables where lower(table_schema) = lower('{schema}') and lower(table_name) = '{table}'"
        )
    return cur.fetchone()[0] > 0


def convert(value: str, ctype: str):
    if value == "":
        return None
    if ctype == "int":
        return int(value)
    if ctype == "money":
        from decimal import Decimal

        return Decimal(value)
    if ctype in ("ts", "date"):
        from datetime import date, datetime

        return date.fromisoformat(value) if ctype == "date" else datetime.fromisoformat(value)
    return value


def literal(value) -> str:
    if value is None:
        return "null"
    if isinstance(value, int) or type(value).__name__ == "Decimal":
        return str(value)
    if type(value).__name__ == "datetime":
        return f"timestamp '{value:%Y-%m-%d %H:%M:%S}'"
    if type(value).__name__ == "date":
        return f"date '{value:%Y-%m-%d}'"
    return "'" + str(value).replace("'", "''") + "'"


def load_table(conn, target: str, schema: str, table: str, csv_path: Path) -> int:
    cols = TABLES[table]
    types = [TYPES.get(c, "str") for c in cols]
    cur = conn.cursor()
    if not table_exists(cur, target, schema, table):
        ddl_cols = ", ".join(f"{c} {DDL_TYPES[target][t]}" for c, t in zip(cols, types, strict=True))
        cur.execute(f"create table {schema}.{table} ({ddl_cols})")
    with open(csv_path, newline="", encoding="utf-8") as fh:
        rows = [tuple(convert(r[c], t) for c, t in zip(cols, types, strict=True)) for r in csv.DictReader(fh)]
    if not rows:
        return 0
    collist = ", ".join(cols)
    if target == "postgres":
        from psycopg2.extras import execute_values

        execute_values(cur, f"insert into {schema}.{table} ({collist}) values %s", rows, page_size=5000)
    elif target == "sqlserver":
        cur.fast_executemany = True
        cur.executemany(f"insert into {schema}.{table} ({collist}) values ({', '.join('?' * len(cols))})", rows)
    elif target == "oracle":
        cur.executemany(
            f"insert into {schema}.{table} ({collist}) values ({', '.join(f':{i + 1}' for i in range(len(cols)))})",
            rows,
        )
    else:
        # Cloud warehouses: batched multi-row VALUES. For large volumes land files in S3 and use
        # COPY INTO (Snowflake external stage / Databricks Auto Loader) instead.
        for i in range(0, len(rows), 500):
            values = ",\n".join("(" + ", ".join(literal(v) for v in row) + ")" for row in rows[i : i + 500])
            cur.execute(f"insert into {schema}.{table} ({collist}) values {values}")
    conn.commit()
    return len(rows)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--target",
        default=env("DBT_TARGET", "postgres"),
        choices=["postgres", "sqlserver", "oracle", "snowflake", "databricks"],
    )
    ap.add_argument("--data", default="data")
    ap.add_argument("--batch", default="all", help="batch number or 'all'")
    args = ap.parse_args()

    batches = sorted(Path(args.data).glob("batch_*"), key=lambda p: int(p.name.split("_")[1]))
    if args.batch != "all":
        batches = [b for b in batches if b.name == f"batch_{args.batch}"]
    if not batches:
        raise SystemExit("no batches found; run data_generator/generate.py first")

    conn = connect(args.target)
    schema = raw_schema(args.target)
    cur = conn.cursor()
    ensure_schema(cur, args.target, schema)
    conn.commit()
    for b in batches:
        for table in TABLES:
            n = load_table(conn, args.target, schema, table, b / f"{table}.csv")
            print(f"{args.target}: {b.name} {schema}.{table}: {n} rows")
    conn.close()


if __name__ == "__main__":
    main()
