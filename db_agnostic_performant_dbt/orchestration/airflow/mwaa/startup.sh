#!/usr/bin/env bash
# MWAA startup script: dbt lives in its own venv so its dependencies never clash with Airflow's.
set -euo pipefail
python3 -m venv /usr/local/airflow/dbt_venv
/usr/local/airflow/dbt_venv/bin/pip install --no-cache-dir -q \
  "dbt-core~=1.10" "dbt-snowflake~=1.10" "dbt-databricks~=1.10" \
  "dbt-postgres~=1.9" "dbt-sqlserver~=1.9" "dbt-oracle~=1.9"
export DBT_EXECUTABLE=/usr/local/airflow/dbt_venv/bin/dbt
