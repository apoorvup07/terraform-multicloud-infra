###############################################################################
# GCP Multi-Cloud Infrastructure Module
# Provisions: VPC, GKE, Cloud SQL, GCS, IAM Service Accounts
###############################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_labels = merge(var.labels, {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
    cost_centre = var.cost_centre
  })
}

###############################################################################
# VPC & Subnets
###############################################################################

resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "main" {
  name          = "${local.name_prefix}-subnet"
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  # Secondary ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_router" "main" {
  name    = "${local.name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id
  project = var.project_id
}

resource "google_compute_router_nat" "main" {
  name                               = "${local.name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.project_id
}

###############################################################################
# IAM — Service Account for GKE nodes
###############################################################################

resource "google_service_account" "gke_node" {
  account_id   = "${local.name_prefix}-gke-node"
  display_name = "GKE Node Service Account (${var.environment})"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

###############################################################################
# GKE Cluster
###############################################################################

resource "google_container_cluster" "main" {
  name     = "${local.name_prefix}-cluster"
  location = var.region
  project  = var.project_id

  # Use a separately managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.main.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.environment == "prod"
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    horizontal_pod_autoscaling { disabled = false }
    http_load_balancing { disabled = false }
  }

  resource_labels = local.common_labels

  deletion_protection = var.environment == "prod"
}

resource "google_container_node_pool" "main" {
  name     = "${local.name_prefix}-nodes"
  location = var.region
  cluster  = google_container_cluster.main.name
  project  = var.project_id

  initial_node_count = var.gke_node_count

  autoscaling {
    min_node_count = var.gke_node_min
    max_node_count = var.gke_node_max
  }

  node_config {
    machine_type    = var.gke_machine_type
    service_account = google_service_account.gke_node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Use preemptible nodes in non-prod for cost saving (equivalent to AWS spot)
    preemptible = var.use_preemptible && var.environment != "prod"

    labels = local.common_labels

    shielded_instance_config {
      enable_secure_boot = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

###############################################################################
# Cloud SQL — PostgreSQL (HA in prod)
###############################################################################

# Private services access: Cloud SQL with a private IP needs a peering range
# reserved in the VPC and a Service Networking connection before it can be created.
resource "google_compute_global_address" "private_services" {
  name          = "${local.name_prefix}-psa"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "google_sql_database_instance" "main" {
  name             = "${local.name_prefix}-postgres"
  database_version = var.postgres_version
  region           = var.region
  project          = var.project_id

  deletion_protection = var.environment == "prod"
  depends_on          = [google_service_networking_connection.private_services]

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = var.environment == "prod"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    database_flags {
      name  = "max_connections"
      value = "200"
    }

    user_labels = local.common_labels
  }
}

resource "google_sql_database" "main" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "google_sql_user" "main" {
  name     = var.db_username
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
  project  = var.project_id
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${local.name_prefix}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

###############################################################################
# GCS Bucket — with lifecycle policy for cost optimisation
###############################################################################

resource "google_storage_bucket" "app" {
  name                        = "${local.name_prefix}-app-${var.project_id}"
  location                    = var.region
  project                     = var.project_id
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 30
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age = 90
    }
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition {
      age        = 30
      with_state = "ARCHIVED"
    }
  }

  labels = local.common_labels
}
