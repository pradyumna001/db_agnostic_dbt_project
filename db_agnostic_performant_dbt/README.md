# db_agnostic_performant_dbt

One dbt codebase that builds the same **medallion → Data Vault 2.0 → star schema** warehouse on
**PostgreSQL, SQL Server, Oracle, Snowflake and Databricks**, with platform-specific performance tuning,
PII classification/masking, Terraform (AWS), GitHub Actions CI/CD and Airflow (MWAA + Cosmos).

```
raw (Faker e-commerce)  ->  bronze (staging views: typing, hash keys, hashdiffs, PII tags)
                        ->  silver.raw_vault (hubs, links, satellites, effectivity sat)   incremental, insert-only
                        ->  silver.business_vault (as-of dates, PIT, bridge)
                        ->  gold (dim_date, dim_customer SCD2, dim_product SCD1, facts, aggregates)
                        ->  gold.secure (masked views for general consumers)
```

## How it stays database-agnostic

| Concern | Mechanism |
|---|---|
| Types | `t_string()`, `t_ts()`, `t_decimal()`, `t_hash()` … (`macros/cross_db/types.sql`) |
| Functions | `date_key`, `add_days`, `concat_strings`, `from_dual`, … dispatched per adapter (`macros/cross_db/functions.sql`) |
| Hash keys | SHA-256 over `UPPER(TRIM())`, `^^` for null, `\|\|` separator → identical 64-char hex on every platform. Enforced by `tests/golden/assert_hash_key_is_portable.sql` |
| Data Vault | Own macros (`macros/datavault/`): `hub`, `link`, `sat`, `eff_sat`, `pit`. Portable SQL only (no `QUALIFY`, no `MERGE` dialects); incremental via watermark + anti-join |
| Upserts | `upsert_strategy()` picks `merge` / `delete+insert` per adapter |
| Schemas | `generate_schema_name`: `<schema>_<layer>` in dev/CI, `<layer>` in prod, single schema on Oracle (schema = user) |
| Unit tests on Oracle | `oracle__get_unit_test_sql` works around `_`-prefixed aliases in dbt-core |

## Performance per platform

Declared once per model as `meta.perf` and applied by `macros/performance/apply_performance.sql`:

```yaml
meta: {perf: {cluster_by: [order_date_key], indexes: [[customer_sk], [product_hk]]}}
```

| Platform | What happens |
|---|---|
| PostgreSQL | B-tree indexes (BRIN for `load_dts`), `ANALYZE` |
| SQL Server | Non-clustered indexes, `UPDATE STATISTICS` |
| Oracle | Indexes, `DBMS_STATS.GATHER_TABLE_STATS` |
| Snowflake | `CLUSTER BY`, transient gold tables, resource monitor + auto-suspend (Terraform) |
| Databricks | Liquid clustering, Delta, optional `OPTIMIZE` (weekly maintenance DAG) |

## PII and security

* PII columns are tagged in YAML: `meta: {pii: true, pii_class: email}`. PII lives in its own satellite (`sat_customer_pii`), so access control and erasure are scoped to one table.
* Native masking driven by the tags (no paid options): Snowflake tag-based masking policy (Terraform), Databricks Unity Catalog column masks, SQL Server Dynamic Data Masking.
* Everywhere (incl. Postgres/Oracle): `gold/secure/dim_customer_secure` view with portable mask expressions and salted tokenization (`DBT_PII_SALT`, from Secrets Manager).
* Credentials only via env vars (`profiles/profiles.yml`); Snowflake key-pair, Databricks OAuth M2M; GitHub → AWS via OIDC (no long-lived keys); gitleaks + detect-private-key in pre-commit.
* Every run is audited to `ops.dbt_run_audit` (invocation, node, status, rows, git SHA).

## Quick start (local Postgres / SQL Server / Oracle)

```bash
cd db_agnostic_performant_dbt
make setup                     # venv, dbt + adapters, pre-commit hooks, .env
make up                        # docker: postgres 16, sql server 2022, oracle free 23
make data                      # 3 synthetic batches (customer / price / status changes between batches)
for t in postgres sqlserver oracle; do
  make load TARGET=$t BATCH=1 && make build TARGET=$t
done
make load TARGET=postgres BATCH=2 && make build TARGET=postgres   # incremental run
make benchmark
```

Requires Python 3.11, `uv`, Docker and the Microsoft ODBC Driver 18 for SQL Server.

## Repository layout

```
models/        bronze/ silver/raw_vault/ silver/business_vault/ gold/{dims,facts,aggs,secure}/
macros/        cross_db/ datavault/ performance/ security/ ops/
tests/         generic/ (unique_combination) golden/ (cross-platform hash test)
data_generator/ generate.py (Faker) load.py (all 5 targets)
infra/docker/  local databases          infra/terraform/  AWS + Snowflake + Databricks
orchestration/airflow/  Cosmos DAGs, MWAA requirements/startup script, local Airflow compose
scripts/       benchmark.py, row_counts.py (idempotency), load_secrets.sh (CI)
docs/          architecture decisions
```

## CI/CD (`.github/workflows/`)

* **dbt-ci** (PR): pre-commit → `dbt parse` on all 5 adapters → integration build on Postgres, SQL Server and Oracle in Docker (3 batches, incremental, idempotency check, sqlfluff, benchmark summary) → Slim CI on Snowflake/Databricks (`state:modified+ --defer`, per-PR schema dropped afterwards) when `ENABLE_CLOUD_CI=true`.
* **dbt-cd** (main): approval-gated `prod` environment, builds changed models, publishes manifest/docs to S3 and syncs DAGs + project to MWAA.
* **terraform**: fmt, validate, tflint, checkov on every change; plan/apply with environment approval.

Repository variables used by the cloud jobs: `ENABLE_CLOUD_CI`, `ENABLE_CLOUD_DEPLOY`, `ENABLE_TERRAFORM_PLAN`, `AWS_REGION`, `AWS_CI_ROLE_ARN`, `AWS_DEPLOY_ROLE_ARN`, `AWS_TERRAFORM_ROLE_ARN`, `SECRET_PREFIX`, `ARTIFACTS_BUCKET`, `AIRFLOW_BUCKET`, `TF_STATE_BUCKET`, `TF_LOCK_TABLE`.

## Out of scope (by decision)

MariaDB (the only dbt adapter is pinned to dbt-core 1.7), Oracle Data Redaction and SQL Server Always Encrypted (paid features).
