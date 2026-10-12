locals {
  engines = {
    postgres = {
      engine         = "postgres"
      engine_version = "16"
      family         = "postgres16"
      port           = 5432
      license_model  = null
      db_name        = "analytics"
      # Tuned for analytical (ELT) workloads rather than OLTP.
      parameters = {
        "rds.force_ssl"                   = "1"
        "work_mem"                        = "65536"
        "maintenance_work_mem"            = "1048576"
        "max_parallel_workers_per_gather" = "4"
        "random_page_cost"                = "1.1"
        "log_min_duration_statement"      = "5000"
      }
    }
    sqlserver = {
      engine         = "sqlserver-se"
      engine_version = "16.00"
      family         = "sqlserver-se-16.0"
      port           = 1433
      license_model  = "license-included"
      db_name        = null
      parameters = {
        "rds.force_ssl"                  = "1"
        "cost threshold for parallelism" = "50"
        "max degree of parallelism"      = "4"
        "optimize for ad hoc workloads"  = "1"
      }
    }
    oracle = {
      engine         = "oracle-se2"
      engine_version = "19"
      family         = "oracle-se2-19"
      port           = 1521
      license_model  = "license-included"
      db_name        = "ANALYTIC"
      parameters = {
        "parallel_max_servers" = "8"
      }
    }
  }
  e = local.engines[var.engine]
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "${var.engine} access for dbt / Airflow"
  vpc_id      = var.vpc_id
  tags        = var.tags

  ingress {
    description = "${var.engine} from allowed networks"
    from_port   = local.e.port
    to_port     = local.e.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Responses only within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_cidr_blocks
  }
}

resource "aws_db_parameter_group" "this" {
  name   = var.name
  family = local.e.family
  tags   = var.tags

  dynamic "parameter" {
    for_each = local.e.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name = "${var.name}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "monitoring.rds.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = local.e.engine
  engine_version = local.e.engine_version
  license_model  = local.e.license_model
  instance_class = var.instance_class
  db_name        = local.e.db_name
  port           = local.e.port

  username                      = "dbt_admin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  iam_database_authentication_enabled = var.engine == "postgres"
  backup_retention_period             = var.backup_retention_days
  copy_tags_to_snapshot               = true
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = !var.deletion_protection
  final_snapshot_identifier           = var.deletion_protection ? "${var.name}-final" : null
  auto_minor_version_upgrade          = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn
  enabled_cloudwatch_logs_exports = {
    postgres  = ["postgresql"]
    sqlserver = ["error"]
    oracle    = ["alert", "listener"]
  }[var.engine]

  tags = var.tags
}
