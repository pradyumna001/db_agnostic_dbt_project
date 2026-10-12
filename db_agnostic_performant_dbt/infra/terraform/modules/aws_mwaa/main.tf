data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "airflow" {
  bucket = "${var.name}-airflow-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "airflow" {
  bucket = aws_s3_bucket.airflow.id
  versioning_configuration { status = "Enabled" } # required by MWAA
}

resource "aws_s3_bucket_server_side_encryption_configuration" "airflow" {
  bucket = aws_s3_bucket.airflow.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "airflow" {
  bucket = aws_s3_bucket.airflow.id
  rule {
    id     = "expire-old-dag-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_public_access_block" "airflow" {
  bucket                  = aws_s3_bucket.airflow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_security_group" "mwaa" {
  name        = "${var.name}-mwaa"
  description = "MWAA workers and webserver"
  vpc_id      = var.vpc_id
  tags        = var.tags

  ingress {
    description = "Self-referencing (required by MWAA)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Warehouses, package index and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  env_arn = "arn:aws:airflow:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:environment/${var.name}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["airflow.amazonaws.com", "airflow-env.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-mwaa-execution"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    actions   = ["airflow:PublishMetrics"]
    resources = [local.env_arn]
  }
  statement {
    actions   = ["s3:GetObject*", "s3:GetBucket*", "s3:List*"]
    resources = [aws_s3_bucket.airflow.arn, "${aws_s3_bucket.airflow.arn}/*"]
  }
  statement {
    actions   = ["s3:GetAccountPublicAccessBlock"]
    resources = ["*"]
  }
  statement {
    actions = [
      "logs:CreateLogStream", "logs:CreateLogGroup", "logs:PutLogEvents", "logs:GetLogEvents",
      "logs:GetLogRecord", "logs:GetLogGroupFields", "logs:GetQueryResults",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:airflow-${var.name}-*"]
  }
  statement {
    actions   = ["logs:DescribeLogGroups", "cloudwatch:PutMetricData"]
    resources = ["*"]
  }
  statement {
    actions   = ["sqs:ChangeMessageVisibility", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage", "sqs:SendMessage"]
    resources = ["arn:aws:sqs:${data.aws_region.current.name}:*:airflow-celery-*"]
  }
  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey*", "kms:Encrypt"]
    resources = [var.kms_key_arn]
  }
  statement {
    sid       = "AirflowSecretsBackend"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secret_name_prefix}/airflow/*"]
  }
  statement {
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "mwaa-execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_mwaa_environment" "this" {
  name               = var.name
  airflow_version    = var.airflow_version
  environment_class  = var.environment_class
  max_workers        = var.max_workers
  execution_role_arn = aws_iam_role.execution.arn
  kms_key            = var.kms_key_arn

  source_bucket_arn      = aws_s3_bucket.airflow.arn
  dag_s3_path            = "dags/"
  requirements_s3_path   = "requirements.txt"
  startup_script_s3_path = "startup.sh"

  webserver_access_mode = "PRIVATE_ONLY"

  airflow_configuration_options = {
    "secrets.backend"                 = "airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend"
    "secrets.backend_kwargs"          = jsonencode({ connections_prefix = "${var.secret_name_prefix}/airflow/connections", variables_prefix = "${var.secret_name_prefix}/airflow/variables" })
    "core.dag_file_processor_timeout" = "300"
    "core.dagbag_import_timeout"      = "240"
  }

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = slice(var.private_subnet_ids, 0, 2)
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "WARNING"
    }
    scheduler_logs {
      enabled   = true
      log_level = "WARNING"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "WARNING"
    }
    worker_logs {
      enabled   = true
      log_level = "WARNING"
    }
  }

  tags = var.tags
}
