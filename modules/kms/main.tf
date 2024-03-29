data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}

resource "aws_kms_key" "service_key" {
  description             = "KMS key for ${var.namespace}-service"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window

  tags = {
    Name = "${var.namespace}-kms-key"
  }
}

resource "aws_kms_key" "cloudwatch_log_key" {
  description         = "KMS key for ${var.namespace} cloudwatch logs"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.cloudwatch_log_key.json

  tags = {
    Name = "${var.namespace}-kms-cloudwatch-log-key"
  }
}

data "aws_iam_policy_document" "cloudwatch_log_key" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.aws_account_id}:root"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "logs.${var.region}.amazonaws.com",
      ]
    }
  }
}

# Append a random string to the secret names because once we tear down the infra, the secret does not actually
# get deleted right away, which means that if we try to recreate the infra, it'll fail as the
# secret name already exists.
resource "random_string" "service_secret_random_suffix" {
  length  = 6
  special = false
}

resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = var.secrets

  name                    = "${var.namespace}/${lower(each.key)}-${random_string.service_secret_random_suffix.result}"
  description             = "Secret 'secret_${lower(each.key)}' for ${var.namespace}"
  kms_key_id              = aws_kms_key.service_key.arn
  recovery_window_in_days = 0

  tags = {
    Name = "${var.namespace}-kms"
  }
}

resource "aws_secretsmanager_secret_version" "service_secrets" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.service_secrets[lower(each.key)].id
  secret_string = each.value
}

locals {
  # Create a secrets ARN collection for granting "secretsmanager:GetSecretValue" permission
  secret_arns = [for secret in aws_secretsmanager_secret.service_secrets : secret.arn]

  # Get Secret Names Array
  secret_names = keys(var.secrets)

  # Create a secrets map { secret_name : secret_arn } using ZipMap Function for iteration
  secrets_name_arn_map = zipmap(local.secret_names, local.secret_arns)

  # Create secrets formatted for the Task Definition
  secrets_variables = [for secret_key, secret_arn in local.secrets_name_arn_map :
    tomap({ "name" = upper(secret_key), "valueFrom" = secret_arn })
  ]

  secret_cloudwatch_log_key_arn = aws_kms_key.cloudwatch_log_key.arn
}
