###############################################################################
# Dev Environment — calls both AWS and GCP modules
###############################################################################

module "aws" {
  source = "../../modules/aws"

  project     = var.project
  environment = "dev"
  region      = var.aws_region

  # Dev-optimised: smaller instances and spot nodes.
  # NAT stays on: EKS nodes live in private subnets and need egress to join the
  # cluster and pull images (or add VPC endpoints for ECR/S3/STS instead).
  eks_instance_type  = "t3.small"
  eks_node_count     = 1
  eks_node_min       = 1
  eks_node_max       = 3
  use_spot_instances = true
  enable_nat_gateway = true
  db_instance_class  = "db.t3.micro"

  tags = {
    Owner = var.owner
    Team  = var.team
  }
}

module "gcp" {
  source = "../../modules/gcp"

  project     = var.project
  project_id  = var.gcp_project_id
  environment = "dev"
  region      = var.gcp_region

  # Dev-optimised: preemptible nodes, smallest SQL tier
  gke_machine_type = "e2-standard-2"
  gke_node_count   = 1
  gke_node_min     = 1
  gke_node_max     = 3
  use_preemptible  = true
  db_tier          = "db-f1-micro"

  labels = {
    owner = var.owner
    team  = var.team
  }
}
