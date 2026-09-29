variable "project" {
  description = "Project name, used as a prefix for all resources"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
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
  description = "Cost centre label applied to all resources for billing allocation"
  type        = string
  default     = "engineering"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west2"
}

variable "vpc_cidr" {
  description = "CIDR block for the primary subnet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.2.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.3.0.0/16"
}

variable "master_cidr" {
  description = "CIDR for GKE control plane (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "gke_machine_type" {
  description = "Machine type for GKE node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "gke_node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 2
}

variable "gke_node_min" {
  description = "Minimum nodes per zone for autoscaling"
  type        = number
  default     = 1
}

variable "gke_node_max" {
  description = "Maximum nodes per zone for autoscaling"
  type        = number
  default     = 5
}

variable "use_preemptible" {
  description = "Use preemptible VMs for non-prod node pools (significant cost saving)"
  type        = bool
  default     = false
}

variable "postgres_version" {
  description = "Cloud SQL PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for Cloud SQL"
  type        = string
  default     = "dbadmin"
}

variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
