terraform {
  cloud {
    organization = "alex-personal-terraform"

    workspaces {
      tags = ["aws-infrastructure"]
    }
  }

  required_version = "1.3.7"
}

locals {
  namespace = "${var.app_name}-${var.environment}"
}

module "log" {
  source = "../modules/cloudwatch"

  namespace                     = local.namespace
  secret_cloudwatch_log_key_arn = module.kms.secret_cloudwatch_log_key_arn
}

module "vpc" {
  source = "../modules/vpc"

  namespace = local.namespace
}

module "kms" {
  source = "../modules/kms"

  namespace = local.namespace
  region    = var.region

  secrets = {
    database_url    = module.rds.db_url
    redis_url       = module.elasticache.redis_primary_endpoint
    secret_key_base = var.secret_key_base
  }
}

module "security_group" {
  source = "../modules/security_group"

  namespace                     = local.namespace
  vpc_id                        = module.vpc.vpc_id
  app_port                      = var.app_port
  private_subnets_cidr_blocks   = module.vpc.private_subnets_cidr_blocks
  rds_port                      = var.rds_port
  elasticache_port              = var.elasticache_port
  bastion_allowed_ip_connection = var.bastion_allowed_ip_connection
}

module "s3" {
  source = "../modules/s3"

  namespace = local.namespace
}

module "alb" {
  source = "../modules/alb"

  vpc_id             = module.vpc.vpc_id
  namespace          = local.namespace
  app_port           = var.app_port
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = module.security_group.alb_security_group_ids
  health_check_path  = var.health_check_path
}

module "ecs" {
  source = "../modules/ecs"

  subnets                            = module.vpc.private_subnet_ids
  namespace                          = local.namespace
  region                             = var.region
  app_host                           = module.alb.alb_dns_name
  app_port                           = var.app_port
  ecr_repo_name                      = var.app_name
  security_groups                    = module.security_group.ecs_security_group_ids
  alb_target_group_arn               = module.alb.alb_target_group_arn
  aws_cloudwatch_log_group_name      = module.log.aws_cloudwatch_log_group_name
  deployment_maximum_percent         = var.ecs.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.ecs.deployment_minimum_healthy_percent
  web_container_cpu                  = var.ecs.web_container_cpu
  web_container_memory               = var.ecs.web_container_memory
  desired_count                      = var.ecs.task_desired_count
  health_check_path                  = var.health_check_path
  max_capacity                       = var.ecs.max_capacity
  max_cpu_threshold                  = var.ecs.max_cpu_threshold

  secrets_variables = module.kms.secrets_variables
  secret_arns       = module.kms.secret_arns
}

module "rds" {
  source = "../modules/rds"

  namespace = local.namespace

  vpc_security_group_ids = module.security_group.rds_security_group_ids
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnet_ids

  instance_type = var.rds_instance_type
  database_name = var.environment
  username      = var.rds_username
  password      = var.rds_password
  port          = var.rds_port

  autoscaling_min_capacity = var.rds_autoscaling_min_capacity
  autoscaling_max_capacity = var.rds_autoscaling_max_capacity
}

module "elasticache" {
  source = "../modules/elasticache"

  namespace = local.namespace

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = module.security_group.elasticache_security_group_ids
  port               = var.elasticache_port
}

module "bastion" {
  source = "../modules/bastion"

  namespace = local.namespace

  subnet_ids                  = module.vpc.public_subnet_ids
  instance_security_group_ids = module.security_group.bastion_security_group_ids
}
