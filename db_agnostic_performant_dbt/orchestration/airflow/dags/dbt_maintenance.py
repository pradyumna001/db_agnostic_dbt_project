"""Weekly maintenance: platform-specific table upkeep and cleanup of stale CI schemas."""

from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.bash import BashOperator

DBT_PROJECT_DIR = os.getenv("DBT_PROJECT_DIR", "/usr/local/airflow/dags/dbt/db_agnostic_performant_dbt")
DBT_EXECUTABLE = os.getenv("DBT_EXECUTABLE", "/usr/local/airflow/dbt_venv/bin/dbt")

with DAG(
    dag_id="dbt_maintenance",
    start_date=datetime(2024, 1, 1),
    schedule="0 5 * * 0",
    catchup=False,
    max_active_runs=1,
    default_args={"owner": "data-platform", "retries": 1, "retry_delay": timedelta(minutes=10)},
    tags=["dbt", "maintenance"],
) as dag:
    for target in [
        t.strip() for t in Variable.get("dbt_targets", default_var="snowflake,databricks").split(",") if t.strip()
    ]:
        base = f"cd {DBT_PROJECT_DIR} && {DBT_EXECUTABLE} --no-use-colors"
        flags = f"--profiles-dir {DBT_PROJECT_DIR}/profiles --target {target}"
        # Rebuilding only the vault models with performance hooks re-applies OPTIMIZE / stats / clustering.
        BashOperator(
            task_id=f"optimize_{target}",
            bash_command=f"{base} run --select tag:silver,config.materialized:incremental {flags} --vars '{{databricks_optimize: true}}'",
            append_env=True,
        ) >> BashOperator(
            task_id=f"drop_ci_schemas_{target}",
            bash_command=f"{base} run-operation drop_ci_schemas --args '{{prefix: ci_pr_}}' {flags}",
            append_env=True,
        )
