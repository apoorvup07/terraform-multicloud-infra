variable "project" {
  description = "Project name, used as a prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cost_centre" {
  description = "Cost centre tag applied to all resources for billing allocation"
  type        = string
  default     = "engineering"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to deploy into (min 2 for HA)"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets. Disable in dev to reduce cost."
  type        = bool
  default     = true
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "eks_instance_type" {
  description = "EC2 instance type for EKS managed node group"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_count" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min" {
  description = "Minimum number of EKS worker nodes (for autoscaling)"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Maximum number of EKS worker nodes (for autoscaling)"
  type        = number
  default     = 6
}

variable "use_spot_instances" {
  description = "Use spot instances for non-prod node groups (significant cost saving)"
  type        = bool
  default     = false
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "Instance class for Aurora cluster instances"
  type        = string
  default     = "db.t3.medium"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
