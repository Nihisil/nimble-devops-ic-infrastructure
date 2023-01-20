variable "namespace" {
  description = "The namespace for the ECS"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "app_host" {
  description = "Application host name"
  type        = string
}

variable "app_port" {
  description = "Application running port"
  type        = number
}

variable "ecr_repo_name" {
  description = "ECR repo name"
  type        = string
}

variable "ecr_tag" {
  description = "ECR tag to deploy"
  type        = string
}

variable "subnets" {
  description = "Subnet where ECS placed"
  type        = list(string)
}

variable "security_groups" {
  description = "One or more VPC security groups associated with ECS cluster"
  type        = list(string)
}

variable "alb_target_group_arn" {
  description = "ALB target group ARN"
}

variable "cpu" {
  description = "ECS task definition CPU"
  type        = number
}

variable "memory" {
  description = "ECS task definition memory"
  type        = number
}

variable "deployment_maximum_percent" {
  description = "Upper limit of the number of running tasks running during deployment"
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit of the number of running tasks running during deployment"
  type        = number
}

variable "desired_count" {
  description = "ECS task definition instance number"
  type        = number
}

variable "web_container_cpu" {
  description = "ECS web container CPU"
  type        = number
}

variable "web_container_memory" {
  description = "ECS web container memory"
  type        = number
}

variable "worker_container_cpu" {
  description = "ECS worker container CPU"
  type        = number
}

variable "worker_container_memory" {
  description = "ECS worker container memory"
  type        = number
}

variable "secrets_variables" {
  description = "List of [{name = \"\", valueFrom = \"\"}] pairs of secret variables"
  type        = list(any)
}

variable "secret_arns" {
  description = "The secrets ARNs for Task Definition"
  type        = list(string)
}