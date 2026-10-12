# Local developer workflow. Usage: make up && make data && make build TARGET=postgres
SHELL := /bin/bash
TARGET ?= postgres
COMPOSE := docker compose -f infra/docker/docker-compose.yml
DBT := set -a; [ -f .env ] && . ./.env; set +a; .venv/bin/dbt
PY := set -a; [ -f .env ] && . ./.env; set +a; .venv/bin/python
export DBT_PROFILES_DIR := profiles

.PHONY: setup up down mssql-db data load build test lint benchmark docs clean

setup:            ## create venv, install dbt + dev tools, install git hooks
	uv venv && uv pip install -r requirements.txt -r requirements-dev.txt
	[ -f .env ] || cp .env.example .env
	cd .. && db_agnostic_performant_dbt/.venv/bin/pre-commit install

up:               ## start local postgres / sqlserver / oracle
	$(COMPOSE) up -d --wait
	$(MAKE) mssql-db

down:
	$(COMPOSE) down -v

mssql-db:         ## SQL Server has no "create database on start" option
	$(COMPOSE) exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$${MSSQL_PASSWORD:-Dbt_local_pw1}" \
	  -Q "if db_id('analytics') is null create database analytics"

data:             ## generate 3 synthetic batches
	$(PY) data_generator/generate.py --out data --customers 300 --products 50 --orders 800 --batches 3

load:             ## load one batch: make load TARGET=oracle BATCH=2
	$(PY) data_generator/load.py --target $(TARGET) --data data --batch $${BATCH:-1}

build:
	$(DBT) build --target $(TARGET) --target-path target/$(TARGET)

test:
	$(DBT) test --target $(TARGET) --target-path target/$(TARGET)

lint:
	.venv/bin/sqlfluff lint models tests/golden
	.venv/bin/ruff check data_generator scripts orchestration

benchmark:        ## compare the last build on each local platform
	.venv/bin/python scripts/benchmark.py \
	  --run-results target/postgres/run_results.json --label postgres \
	  --run-results target/sqlserver/run_results.json --label sqlserver \
	  --run-results target/oracle/run_results.json --label oracle

docs:
	$(DBT) docs generate --target $(TARGET) && $(DBT) docs serve --target $(TARGET)

clean:
	$(DBT) clean
