"""Daily medallion pipeline (bronze -> silver vault -> gold star) for every configured warehouse.

One DAG is generated per dbt target listed in the Airflow variable ``dbt_targets``
(default: snowflake,databricks). Cosmos renders each dbt model as an Airflow task with its
tests attached, so a failing test blocks only its downstream models.

Credentials are never stored in the DAG: the warehouse env vars referenced by
profiles/profiles.yml are resolved at runtime from Airflow Variables, which on MWAA are
backed by AWS Secrets Manager (prefix ``airflow/variables/``).
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.models import Variable
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import LoadMode, TestBehavior

DBT_PROJECT_DIR = Path(os.getenv("DBT_PROJECT_DIR", "/usr/local/airflow/dags/dbt/db_agnostic_performant_dbt"))
DBT_EXECUTABLE = os.getenv("DBT_EXECUTABLE", "/usr/local/airflow/dbt_venv/bin/dbt")
MANIFEST = DBT_PROJECT_DIR / "target" / "manifest.json"

# Env vars each target needs (names match profiles/profiles.yml); values come from Airflow Variables.
TARGET_ENV = {
    "postgres": ["PG_HOST", "PG_PORT", "PG_USER", "PG_PASSWORD", "PG_DATABASE"],
    "sqlserver": ["MSSQL_HOST", "MSSQL_PORT", "MSSQL_USER", "MSSQL_PASSWORD", "MSSQL_DATABASE"],
    "oracle": ["ORACLE_HOST", "ORACLE_PORT", "ORACLE_SERVICE", "ORACLE_USER", "ORACLE_PASSWORD"],
    "snowflake": [
        "SNOWFLAKE_ACCOUNT",
        "SNOWFLAKE_USER",
        "SNOWFLAKE_PRIVATE_KEY",
        "SNOWFLAKE_ROLE",
        "SNOWFLAKE_WAREHOUSE",
        "SNOWFLAKE_DATABASE",
    ],
    "databricks": [
        "DATABRICKS_HOST",
        "DATABRICKS_HTTP_PATH",
        "DATABRICKS_CLIENT_ID",
        "DATABRICKS_CLIENT_SECRET",
        "DATABRICKS_CATALOG",
    ],
}
COMMON_ENV = ["DBT_PII_SALT"]

DEFAULT_ARGS = {
    "owner": "data-platform",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
}


def _env_for(target: str) -> dict[str, str]:
    """Templated env: rendered by Airflow at task runtime, not at DAG parse time."""
    env = {name: "{{ var.value.get('%s', '') }}" % name.lower() for name in TARGET_ENV[target] + COMMON_ENV}
    env.update(
        {
            "DBT_TARGET": target,
            "DBT_ENV": "{{ var.value.get('dbt_env', 'prod') }}",
            "DBT_SCHEMA": "{{ var.value.get('dbt_schema', 'analytics') }}",
            "GIT_SHA": "{{ var.value.get('dbt_git_sha', 'unknown') }}",
        }
    )
    return env


def _render_config(select: list[str]) -> RenderConfig:
    # A manifest produced by CI makes DAG parsing fast and deterministic; fall back to dbt ls.
    load_method = LoadMode.DBT_MANIFEST if MANIFEST.exists() else LoadMode.DBT_LS
    return RenderConfig(load_method=load_method, select=select, test_behavior=TestBehavior.AFTER_EACH)


def build_dag(target: str) -> DAG:
    env = _env_for(target)
    profile = ProfileConfig(
        profile_name="db_agnostic_performant_dbt",
        target_name=target,
        profiles_yml_filepath=DBT_PROJECT_DIR / "profiles" / "profiles.yml",
    )
    project = ProjectConfig(
        dbt_project_path=DBT_PROJECT_DIR,
        manifest_path=MANIFEST if MANIFEST.exists() else None,
    )
    execution = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)
    operator_args = {"install_deps": False, "env": env, "append_env": True}
    dbt_cmd = f"cd {DBT_PROJECT_DIR} && {DBT_EXECUTABLE}"
    profiles = f"--profiles-dir {DBT_PROJECT_DIR / 'profiles'} --target {target}"

    with DAG(
        dag_id=f"dbt_medallion_{target}",
        description=f"Bronze -> Data Vault -> Star schema on {target}",
        start_date=datetime(2024, 1, 1),
        schedule=Variable.get(f"dbt_schedule_{target}", default_var="0 3 * * *"),
        catchup=False,
        max_active_runs=1,
        default_args=DEFAULT_ARGS,
        tags=["dbt", "medallion", target],
    ) as dag:
        start = EmptyOperator(task_id="start")

        freshness = BashOperator(
            task_id="source_freshness",
            bash_command=f"{dbt_cmd} source freshness {profiles}",
            env=env,
            append_env=True,
        )

        groups = []
        for layer in ["bronze", "silver", "gold"]:
            groups.append(
                DbtTaskGroup(
                    group_id=layer,
                    project_config=project,
                    profile_config=profile,
                    execution_config=execution,
                    render_config=_render_config([f"tag:{layer}"]),
                    operator_args=operator_args,
                )
            )

        singular_tests = BashOperator(
            task_id="cross_layer_tests",
            bash_command=f"{dbt_cmd} test --select test_type:singular {profiles}",
            env=env,
            append_env=True,
        )

        start >> freshness >> groups[0] >> groups[1] >> groups[2] >> singular_tests
    return dag


for _target in [
    t.strip() for t in Variable.get("dbt_targets", default_var="snowflake,databricks").split(",") if t.strip()
]:
    if _target in TARGET_ENV:
        globals()[f"dbt_medallion_{_target}"] = build_dag(_target)
