locals {
  catalog = "${var.catalog_name}_${var.env}"
}

resource "databricks_service_principal" "dbt" {
  display_name = "svc-dbt-${var.env}"
}

resource "databricks_group" "group" {
  for_each     = toset(["transformers", "gold_readers", "pii_readers"])
  display_name = "${each.key}_${var.env}"
}

resource "databricks_group_member" "dbt_transformer" {
  group_id  = databricks_group.group["transformers"].id
  member_id = databricks_service_principal.dbt.id
}

resource "databricks_catalog" "analytics" {
  name         = local.catalog
  comment      = "db_agnostic_performant_dbt (${var.env})"
  storage_root = var.catalog_storage_root
  properties   = { purpose = "medallion" }
}

resource "databricks_schema" "layer" {
  for_each     = toset(["raw", "bronze", "silver", "gold", "ops", "governance"])
  catalog_name = databricks_catalog.analytics.name
  name         = each.key
}

resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.analytics.name
  grant {
    principal  = databricks_group.group["transformers"].display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "USE_SCHEMA", "CREATE_TABLE", "CREATE_FUNCTION", "SELECT", "MODIFY", "APPLY_TAG"]
  }
  grant {
    principal  = databricks_group.group["gold_readers"].display_name
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = databricks_group.group["pii_readers"].display_name
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "gold" {
  schema = databricks_schema.layer["gold"].id
  grant {
    principal  = databricks_group.group["gold_readers"].display_name
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = databricks_group.group["pii_readers"].display_name
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = databricks_group.group["transformers"].display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

# Mask functions in `governance` must be executable by readers so masked columns stay queryable.
resource "databricks_grants" "governance" {
  schema = databricks_schema.layer["governance"].id
  grant {
    principal  = databricks_group.group["gold_readers"].display_name
    privileges = ["USE_SCHEMA", "EXECUTE"]
  }
  grant {
    principal  = databricks_group.group["pii_readers"].display_name
    privileges = ["USE_SCHEMA", "EXECUTE"]
  }
  grant {
    principal  = databricks_group.group["transformers"].display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

resource "databricks_sql_endpoint" "transform" {
  name                      = "dbt-transform-${var.env}"
  cluster_size              = var.warehouse_size
  min_num_clusters          = 1
  max_num_clusters          = var.max_clusters
  auto_stop_mins            = 10
  enable_serverless_compute = true
  warehouse_type            = "PRO"
  tags {
    custom_tags {
      key   = "project"
      value = "db_agnostic_performant_dbt"
    }
  }
}

resource "databricks_permissions" "warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.transform.id
  access_control {
    service_principal_name = databricks_service_principal.dbt.application_id
    permission_level       = "CAN_USE"
  }
}
