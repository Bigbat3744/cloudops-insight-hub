variable "aws_region" {
  description = "Region for all resources (Cost Explorer itself is served from us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "cloudops-insight-hub"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "table_name" {
  type    = string
  default = "cloudops-usage"
}

variable "function_name" {
  type    = string
  default = "cloudops-aws-collector"
}

variable "collection_schedule" {
  description = "EventBridge schedule for the daily collection (UTC)"
  type        = string
  default     = "cron(0 9 * * ? *)"
}

variable "log_retention_days" {
  type    = number
  default = 14
}
