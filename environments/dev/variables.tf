variable "project" {
  description = "Project name used as a prefix on every resource"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the AWS module"
  type        = string
  default     = "eu-west-1"
}

variable "gcp_project_id" {
  description = "GCP project ID that the GCP module deploys into"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for the GCP module"
  type        = string
  default     = "europe-west2"
}

variable "owner" {
  description = "Owner tag/label applied to every resource"
  type        = string
}

variable "team" {
  description = "Team tag/label applied to every resource"
  type        = string
}
