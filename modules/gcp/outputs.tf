output "vpc_name" {
  description = "Name of the created VPC network"
  value       = google_compute_network.main.name
}

output "subnet_name" {
  description = "Name of the primary subnet"
  value       = google_compute_subnetwork.main.name
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "gke_cluster_endpoint" {
  description = "API server endpoint for the GKE cluster"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "gke_node_service_account" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_node.email
}

output "cloud_sql_connection_name" {
  description = "Connection name for Cloud SQL instance"
  value       = google_sql_database_instance.main.connection_name
}

output "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "db_password_secret_id" {
  description = "Secret Manager secret ID for the database password"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "gcs_bucket_name" {
  description = "Name of the application GCS bucket"
  value       = google_storage_bucket.app.name
}
