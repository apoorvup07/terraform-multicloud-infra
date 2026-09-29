# terraform-multicloud-infra

Terraform modules for provisioning equivalent infrastructure across **AWS** and **GCP** from a single configuration. Designed for teams running multi-cloud strategies with consistent networking, compute, and security posture.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Root Configuration                      │
│                   (environments/dev)                     │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌───────────────┐         ┌───────────────┐
│  AWS Module   │         │  GCP Module   │
│               │         │               │
│  • VPC        │         │  • VPC        │
│  • EKS        │         │  • GKE        │
│  • RDS Aurora │         │  • Cloud SQL  │
│  • IAM Roles  │         │  • IAM SA     │
│  • S3 Backend │         │  • GCS Bucket │
└───────────────┘         └───────────────┘
```

## Features

- **Unified interface** — identical input variables across AWS and GCP modules
- **Environment-aware** — `dev` is implemented; modules switch behaviour for `prod` (spot/preemptible off, deletion protection on). `staging`/`prod` roots are on the roadmap
- **Remote state ready** — add an `s3` (AWS) or `gcs` (GCP) backend block; the quick start shows the `-backend-config` flags
- **Least-privilege IAM** — scoped roles and service accounts per environment
- **Cost-tagged resources** — all resources tagged for cost allocation and optimisation
- **CI** — `terraform fmt` + `validate` on every push/PR with no cloud credentials; plan/apply workflows run on demand

## Repository Structure

```
terraform-multicloud-infra/
├── modules/
│   ├── aws/                  # AWS reusable module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── gcp/                  # GCP reusable module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
├── environments/
│   ├── dev/                  # Dev environment (both clouds)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── aws.tfvars
│   │   └── gcp.tfvars
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
└── README.md
```

## Prerequisites

| Tool        | Version  |
|-------------|----------|
| Terraform   | >= 1.5.0 |
| AWS CLI     | >= 2.x   |
| gcloud CLI  | >= 450.x |
| kubectl     | >= 1.28  |

## Quick Start

### 1. Configure credentials

```bash
# AWS
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-west-1"

# GCP
gcloud auth application-default login
export GOOGLE_PROJECT="your-project-id"
```

### 2. Initialise and deploy the dev environment

The dev root deploys **both** clouds in one plan, so it needs both variable files (and credentials for both):

```bash
cd environments/dev
terraform init
terraform plan  -var-file="aws.tfvars" -var-file="gcp.tfvars" -out=dev.tfplan
terraform apply dev.tfplan
```

Set `gcp_project_id` in `gcp.tfvars` first. To keep state remote, add a `backend "s3"` or `backend "gcs"` block and pass `-backend-config=...` to `terraform init`.

### 3. Verify cluster access

```bash
# AWS EKS
aws eks update-kubeconfig --region eu-west-1 --name my-cluster-dev

# GCP GKE
gcloud container clusters get-credentials my-cluster-dev --region europe-west2
```

## Module Inputs

### AWS Module

| Variable              | Type   | Default       | Description                        |
|-----------------------|--------|---------------|------------------------------------|
| `environment`         | string | —             | Environment name (dev/staging/prod)|
| `region`              | string | `eu-west-1`   | AWS region                         |
| `vpc_cidr`            | string | `10.0.0.0/16` | VPC CIDR block                     |
| `eks_node_count`      | number | `2`           | EKS managed node group count       |
| `eks_instance_type`   | string | `t3.medium`   | EKS node instance type             |
| `db_instance_class`   | string | `db.t3.medium`| Aurora instance class              |
| `enable_nat_gateway`  | bool   | `true`        | Enable NAT gateway for private subnets |
| `tags`                | map    | `{}`          | Additional resource tags           |

### GCP Module

| Variable              | Type   | Default            | Description                        |
|-----------------------|--------|--------------------|------------------------------------|
| `environment`         | string | —                  | Environment name                   |
| `region`              | string | `europe-west2`     | GCP region                         |
| `vpc_cidr`            | string | `10.1.0.0/16`      | VPC subnet CIDR                    |
| `gke_node_count`      | number | `2`                | GKE node pool count                |
| `gke_machine_type`    | string | `e2-standard-2`    | GKE node machine type              |
| `db_tier`             | string | `db-f1-micro`      | Cloud SQL tier                     |
| `labels`              | map    | `{}`               | Additional resource labels         |

## Cost Optimisation Built-in

This module implements several cost-saving patterns from production experience:

- **S3 lifecycle policies** — transition to IA after 30 days, Glacier after 90
- **Node scaling bounds** — EKS node group min/max and GKE node-pool autoscaling
- **Spot/preemptible nodes** — `capacity_type = SPOT` (EKS) and preemptible GKE nodes in non-prod
- **Resource tagging** — environment, owner, team and cost-centre tags/labels on every resource
- **Small dev defaults** — `t3.small` nodes and `db.t3.micro` Aurora in dev


## CI/CD Integration

GitHub Actions workflows are included:

- **`ci.yml` (every push/PR)** — `terraform fmt -check` and `terraform validate`, no credentials needed
- **`terraform-plan.yml` / `terraform-apply.yml` (on demand)** — plan and apply for dev once cloud credentials and a state bucket are added as repository secrets; apply reports to Slack

See `.github/workflows/` for full configuration.

## Security

- All S3 buckets have public access blocked and versioning enabled
- IAM roles follow least-privilege — scoped per environment
- Aurora's master password is managed by AWS (`manage_master_user_password`), so it never appears in Terraform state
- The Cloud SQL password is generated with `random_password` and stored in Secret Manager; it *is* present in state, which is why state must live in an encrypted, access-controlled backend

## Contributing

1. Branch from `main`
2. Run `terraform fmt` and `terraform validate` before committing
3. Open a PR — CI runs `fmt` and `validate` automatically

## Fixes made while preparing this repo

- EKS "spot" flag previously only added a `NO_SCHEDULE` taint (nodes stayed On-Demand and nothing could schedule on them); it now sets `capacity_type = "SPOT"`.
- Dev had NAT disabled while nodes sit in private subnets, so nodes could not join the cluster; NAT is now on in dev.
- Cloud SQL used a private IP without private services access, so it could never be created; the module now reserves a peering range and creates the Service Networking connection (enable `servicenetworking.googleapis.com` in the project). `require_ssl`, removed in newer Google providers, is replaced by `ssl_mode = "ENCRYPTED_ONLY"`.
- The dev root referenced variables it never declared, so `terraform validate` failed; `environments/dev/variables.tf` now declares them.

**Known gap:** the on-demand plan/apply workflows still plan each cloud separately with one var file; they need reworking for the single multi-cloud root (both var files and both sets of credentials).

## Licence

MIT
