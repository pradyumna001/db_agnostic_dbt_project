locals {
  db = "${var.database_name}_${upper(var.env)}"
  wh = "TRANSFORM_WH_${upper(var.env)}"
  # Masking per PII class (matches pii_class values in model YAML). PII_READER sees clear text.
  mask_rules = {
    email       = "regexp_replace(val, '^[^@]+', '*****')"
    phone       = "concat('***-***-', right(val, 4))"
    name        = "concat(left(val, 1), '****')"
    address     = "'** REDACTED **'"
    postal_code = "concat(left(val, 2), '***')"
    card        = "'****'"
  }
}

resource "snowflake_resource_monitor" "transform" {
  name            = "${local.wh}_MONITOR"
  credit_quota    = var.monthly_credit_quota
  frequency       = "MONTHLY"
  start_timestamp = "IMMEDIATELY"
  notify_triggers = [75, 90]
  suspend_trigger = 100
}

resource "snowflake_warehouse" "transform" {
  name                         = local.wh
  warehouse_size               = var.warehouse_size
  auto_suspend                 = 60
  auto_resume                  = true
  initially_suspended          = true
  max_cluster_count            = var.env == "prod" ? 3 : 1
  min_cluster_count            = 1
  scaling_policy               = "STANDARD"
  resource_monitor             = snowflake_resource_monitor.transform.name
  statement_timeout_in_seconds = 3600
}

resource "snowflake_database" "analytics" {
  name                        = local.db
  data_retention_time_in_days = var.data_retention_days
}

resource "snowflake_schema" "layer" {
  for_each = toset(["RAW", "BRONZE", "SILVER", "GOLD", "OPS", "GOVERNANCE"])
  database = snowflake_database.analytics.name
  name     = each.key
}

# ---------------------------------------------------------------- roles
resource "snowflake_account_role" "role" {
  for_each = toset(["TRANSFORMER", "GOLD_READER", "PII_READER"])
  name     = "${each.key}_${upper(var.env)}"
}

resource "snowflake_grant_account_role" "pii_reader_inherits_gold" {
  role_name        = snowflake_account_role.role["GOLD_READER"].name
  parent_role_name = snowflake_account_role.role["PII_READER"].name
}

resource "snowflake_grant_privileges_to_account_role" "transformer_wh" {
  account_role_name = snowflake_account_role.role["TRANSFORMER"].name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transform.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_db" {
  account_role_name = snowflake_account_role.role["TRANSFORMER"].name
  privileges        = ["USAGE", "CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_schemas" {
  account_role_name = snowflake_account_role.role["TRANSFORMER"].name
  all_privileges    = true
  on_schema {
    all_schemas_in_database = snowflake_database.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_apply_tag" {
  account_role_name = snowflake_account_role.role["TRANSFORMER"].name
  privileges        = ["APPLY TAG"]
  on_account        = true
}

resource "snowflake_grant_privileges_to_account_role" "reader_db" {
  for_each          = toset(["GOLD_READER"])
  account_role_name = snowflake_account_role.role[each.key].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "reader_gold_schema" {
  account_role_name = snowflake_account_role.role["GOLD_READER"].name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${snowflake_database.analytics.name}\".\"GOLD\""
  }
  depends_on = [snowflake_schema.layer]
}

# ---------------------------------------------------------------- dbt service user (key-pair only)
resource "snowflake_service_user" "dbt" {
  name              = "SVC_DBT_${upper(var.env)}"
  default_role      = snowflake_account_role.role["TRANSFORMER"].name
  default_warehouse = snowflake_warehouse.transform.name
  rsa_public_key    = var.dbt_service_user_public_key
}

resource "snowflake_grant_account_role" "dbt_transformer" {
  role_name = snowflake_account_role.role["TRANSFORMER"].name
  user_name = snowflake_service_user.dbt.name
}

# ---------------------------------------------------------------- tag-based masking
# dbt sets GOVERNANCE.PII_CLASS = '<class>' on PII columns; the policy attached to the tag masks them.
resource "snowflake_tag" "pii_class" {
  database       = snowflake_database.analytics.name
  schema         = snowflake_schema.layer["GOVERNANCE"].name
  name           = "PII_CLASS"
  allowed_values = concat(keys(local.mask_rules), ["date"])
  masking_policies = [
    snowflake_masking_policy.pii_string.fully_qualified_name,
    snowflake_masking_policy.pii_date.fully_qualified_name,
  ]
}

resource "snowflake_masking_policy" "pii_string" {
  database = snowflake_database.analytics.name
  schema   = snowflake_schema.layer["GOVERNANCE"].name
  name     = "MASK_PII_STRING"
  argument {
    name = "VAL"
    type = "VARCHAR"
  }
  return_data_type = "VARCHAR"
  body             = <<-SQL
    case
      when is_role_in_session('${snowflake_account_role.role["PII_READER"].name}') then val
      else case system$get_tag_on_current_column('${snowflake_database.analytics.name}.GOVERNANCE.PII_CLASS')
      %{for cls, expr in local.mask_rules~}
        when '${cls}' then ${expr}
      %{endfor~}
        else '** MASKED **'
      end
    end
  SQL
}

resource "snowflake_masking_policy" "pii_date" {
  database = snowflake_database.analytics.name
  schema   = snowflake_schema.layer["GOVERNANCE"].name
  name     = "MASK_PII_DATE"
  argument {
    name = "VAL"
    type = "DATE"
  }
  return_data_type = "DATE"
  body             = "case when is_role_in_session('${snowflake_account_role.role["PII_READER"].name}') then val else date_trunc('year', val) end"
}
