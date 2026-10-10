# AWS 3-Tier Architecture — Highly Available & Cost-Optimized

> A production-grade 3-tier web application on AWS, fully provisioned with Terraform and deployed via a Docker + GitHub Actions CI/CD pipeline.

![AWS](https://img.shields.io/badge/AWS-ap--south--1-orange?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-7B42BC?logo=terraform)
![Docker](https://img.shields.io/badge/Docker-multi--stage-2496ED?logo=docker)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Architecture

```
                          ┌─────────────────────────────────────┐
                          │           Internet                  │
                          └────────────────┬────────────────────┘
                                           │ HTTP/HTTPS
                                           ▼
                          ┌─────────────────────────────────────┐
                          │   Application Load Balancer (ALB)   │
                          │   Public Subnets · AZ-a + AZ-b      │
                          └────────────────┬────────────────────┘
                                           │ port 5000 (from sg-alb only)
                                           ▼
        ┌──────────────────────────────────┴──────────────────────────────────┐
        │                                                                     │
        ▼                                                                     ▼
┌───────────────────┐                                                ┌───────────────────┐
│  EC2 (Docker)     │                                                │  EC2 (Docker)     │
│  Private App-AZ-a │                                                │  Private App-AZ-b │
└─────────┬─────────┘                                                └─────────┬─────────┘
          │                                                                    │
          │ port 5432 (from sg-app only)                                       │
          └────────────────────┬───────────────────────────────────────────────┘
                               ▼
                    ┌──────────────────────────┐
                    │  RDS PostgreSQL (Multi-AZ)│
                    │  Private DB Subnets       │
                    └──────────────────────────┘
```

> Full architecture diagram coming in a later phase (draw.io / Lucidchart export).

---

## Project Overview

This project provisions a **highly available, multi-AZ, 3-tier web application** on AWS using **Terraform**, and deploys the application as a **Docker container** to EC2 instances managed by an **Auto Scaling Group**.

### Goals

- **High Availability:** multi-AZ deployment, no single point of failure
- **Self-healing:** ALB health checks + ASG replace unhealthy instances automatically
- **Elastic:** target-tracking auto scaling based on CPU utilization
- **Secure:** chained security groups, private subnets for app & DB, SSM Session Manager (no SSH), OIDC-based CI/CD (no long-lived credentials)
- **Cost-optimized:** right-sized instances, scheduled scaling, S3 lifecycle policies, AWS Budgets alerts
- **Infrastructure as Code:** 100% Terraform, remote state on S3 with DynamoDB/native locking
- **Reproducible:** Dockerized app, CI/CD pipeline via GitHub Actions

---

## Tech Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (ap-south-1 · Mumbai) |
| IaC | Terraform ≥ 1.5 |
| Compute | EC2 (Amazon Linux 2023), Auto Scaling Group |
| Container | Docker (multi-stage build), Amazon ECR |
| Networking | VPC, Subnets, IGW, NAT Gateway, Route Tables, Security Groups |
| Load Balancing | Application Load Balancer (ALB) |
| Database | Amazon RDS for PostgreSQL (Multi-AZ) |
| Monitoring | CloudWatch, CloudWatch Logs, SNS |
| CI/CD | GitHub Actions, AWS OIDC federation |
| App Stack | Python 3.12, Flask, Gunicorn |
| Cost Control | AWS Budgets, S3 Lifecycle policies, ECR Lifecycle |

---

## Repository Structure

```
aws-3tier-cicd/
├── terraform/                       # Infrastructure as Code
│   ├── provider.tf                  # AWS provider + S3 backend
│   ├── variables.tf                 # Input variables
│   ├── terraform.tfvars             # Variable values (non-secret)
│   ├── vpc.tf                       # VPC, subnets, IGW, NATs, routes
│   ├── security-group.tf            # Chained security groups
│   ├── ecr.tf                       # ECR repository + lifecycle
│   ├── alb.tf                       # ALB, target group, listener
│   ├── outputs.tf                   # Output values
│   └── ...                          # (RDS, ASG, CloudWatch — later phases)
├── bootstrap/                       # One-time S3 + lock table setup
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── app/                             # Flask application
│   ├── app.py                       # Flask app with /, /health, /version
│   ├── requirements.txt             # Pinned dependencies
│   ├── Dockerfile                   # Multi-stage, non-root, gunicorn
│   └── .dockerignore
├── .github/workflows/               # CI/CD (Phase 5)
├── .gitignore
├── .gitattributes
└── README.md
```

---

## Features

### High Availability
- VPC spans **2 Availability Zones**
- **2 NAT Gateways** (one per AZ) for redundant egress
- **ALB** deployed across both public subnets
- **RDS Multi-AZ** (Phase 3) with automatic failover
- **ASG** maintains instances across both AZs

### Security
- **Chained security groups:** `sg-alb → sg-app → sg-db`, referenced by SG ID (never by CIDR)
- App tier **not reachable from the internet** — only from ALB
- DB tier **only reachable from app tier**
- **No SSH** — access via **SSM Session Manager** (outbound-only, no port 22 open)
- **Least-privilege egress** — explicit allow rules instead of the default "allow all"
- **OIDC-based CI/CD** (Phase 5) — no long-lived AWS credentials in GitHub

### Self-Healing
- **ALB health checks** on `/health` (interval 30s, threshold 2)
- Unhealthy instances are **automatically removed** from rotation
- **ASG replaces terminated instances** within ~90 seconds
- **RDS Multi-AZ** promotes standby on primary failure (~60–120s)

### Cost Optimization
- **Right-sized instances** (t3.micro for dev)
- **ECR lifecycle policy** — keeps last 10 images, expires older
- **S3 lifecycle policy** (Phase 6) — moves old logs to Glacier
- **AWS Budgets** alerts (Phase 6) — notify at 80% / 100% thresholds
- **Scheduled scaling** (Phase 4) — scale down at night for dev environments

### Observability
- **CloudWatch metrics** for ALB, EC2, ASG, RDS
- **CloudWatch Alarms** (Phase 4) for CPU, memory, 5XX rates
- **Centralized logs** — app logs to CloudWatch Logs via Docker's log driver
- **SNS notifications** (Phase 6) for alarm state changes

---

## Prerequisites

To reproduce this project you'll need:

| Tool | Version | Purpose |
|---|---|---|
| AWS Account | — | With permission to create VPC, EC2, RDS, IAM, ECR |
| AWS CLI | v2 | Interacting with AWS |
| Terraform | ≥ 1.5 | Infrastructure provisioning |
| Docker | 20+ | Building the app image |
| Git | any | Version control |
| (Optional) VS Code | — | Editor with Terraform + Docker extensions |

**Configure AWS credentials locally:**

```bash
aws configure
# Enter: Access Key, Secret Key, Region (ap-south-1), Output (json)
```

---

## Implementation — Phase by Phase

### Phase 1 — Networking Foundation

**Goal:** Build the VPC and all networking layers.

**Resources created:**
- VPC `10.0.0.0/16` with DNS hostnames + support enabled
- 6 subnets across 2 AZs:
  - 2 public (`10.0.1.0/24`, `10.0.2.0/24`)
  - 2 private app (`10.0.11.0/24`, `10.0.12.0/24`)
  - 2 private DB (`10.0.21.0/24`, `10.0.22.0/24`)
- Internet Gateway (for public subnets)
- 2 NAT Gateways (one per AZ, for private subnet egress)
- 3 Route tables:
  - 1 public (→ IGW)
  - 2 private (→ NAT, one per AZ)

**Key design decision:** One NAT Gateway per AZ. If AZ-a fails, AZ-b's resources still have internet access. This is the "no single point of failure" pattern.

**Cost note:** Each NAT Gateway is ~$0.045/hour. 2 NATs = ~$2.16/day. Destroy when not in use.

**File:** `terraform/vpc.tf`

---

### Phase 2A — Chained Security Groups

**Goal:** Define least-privilege firewall rules for each tier.

**Traffic flow:**

```
Internet ─80/443─▶ sg-alb ─5000─▶ sg-app ─5432─▶ sg-db
```

**Security groups:**

| SG | Inbound | Outbound |
|---|---|---|
| `sg-alb` | 80, 443 from `0.0.0.0/0` | 5000 → `sg-app` |
| `sg-app` | 5000 from `sg-alb` | 5432 → `sg-db`, 443 + 80 → internet |
| `sg-db` | 5432 from `sg-app` | (none — DB doesn't initiate) |

**Why chained SG references?**
Referencing SG IDs (instead of CIDRs) creates a **provable security boundary**. The app tier is not reachable from anywhere except the ALB. If an attacker compromises a random resource in the VPC, they still cannot reach port 5000 on the app.

**No port 22 open anywhere.** Access to instances is via SSM Session Manager, which uses outbound HTTPS only.

**File:** `terraform/security-group.tf`

---

### Phase 2B — Elastic Container Registry (ECR)

**Goal:** Private registry for the app image.

**Resources created:**
- ECR repository `threetier-app`
- Image scanning on push (catches CVEs)
- AES256 encryption at rest
- Lifecycle policy: keep last 10 images, expire older

**Dockerfile highlights:**
- Multi-stage build (builder + runtime) → image is 146 MB instead of ~400 MB
- Non-root user (`appuser`, UID 1000)
- Gunicorn as WSGI server (not Flask's dev server)
- `HEALTHCHECK` configured for `/health`
- Pinned dependencies including `setuptools<82` (fixes the `pkg_resources` issue in slim Python images)

**Push flow:**

```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.ap-south-1.amazonaws.com

docker build -t threetier-app:v1 ./app
docker tag threetier-app:v1 <ECR_URL>:v1
docker tag threetier-app:v1 <ECR_URL>:latest
docker push <ECR_URL>:v1
docker push <ECR_URL>:latest
```

**File:** `terraform/ecr.tf`

---

### Phase 2C — Application Load Balancer + Target Group

**Goal:** Public entry point for HTTP traffic.

**Resources created:**
- Target Group `threetier-tg-app` (HTTP, port 5000, target_type=instance)
- Application Load Balancer `threetier-alb` (public subnets, sg-alb)
- Listener on port 80 → forwards to target group

**Health check configuration:**

| Setting | Value | Why |
|---|---|---|
| Path | `/health` | Matches Flask endpoint |
| Interval | 30s | Standard |
| Timeout | 5s | Fast failure detection |
| Healthy threshold | 2 | Fast recovery |
| Unhealthy threshold | 2 | Fast removal |
| Matcher | `200` | Strict |

**Deregistration delay:** 30 seconds (dev-fast). Production would use 300s.

**Test at this stage:**

```bash
curl http://<ALB_DNS_NAME>/
# Expected: HTTP 503 — no instances registered yet
# (Phase 2D fixes this by adding the ASG)
```

**File:** `terraform/alb.tf`

---

### Phase 2D — Launch Template + Auto Scaling Group

**Goal:** Auto-scaling fleet of Dockerized app instances registered with the ALB.

**Resources created:**

- **IAM role** `threetier-ec2-app-role` with 3 managed policies:
  - `AmazonSSMManagedInstanceCore` — Session Manager access (no SSH keys, no open port 22)
  - `AmazonEC2ContainerRegistryReadOnly` — pull images from ECR via instance role
  - `CloudWatchAgentServerPolicy` — ship logs and metrics
- **IAM instance profile** `threetier-ec2-app-profile`
- **Launch Template** `threetier-lt-app-*`:
  - Dynamic AMI lookup (latest Amazon Linux 2023)
  - `t3.micro` instances (free tier eligible)
  - Encrypted gp3 root volume
  - IMDSv2 enforced (`http_tokens = "required"`)
  - `user_data` script: installs Docker, pulls image from ECR using instance role, runs as systemd service
- **Auto Scaling Group** `threetier-asg-app-*`:
  - Desired 2, Min 2, Max 4
  - Spans both private app subnets → one instance per AZ
  - Registered with the ALB target group
  - `health_check_type = "ELB"`
  - `instance_refresh` enabled for rolling updates

**Self-healing test — verified:**

1. Terminated one instance via `aws ec2 terminate-instances`
2. ASG detected loss and began replacement
3. New instance launched, booted, pulled image, registered with ALB
4. **Total recovery time: ~4 minutes**
5. **Load test during failure:** 320 requests sent (2 req/sec for the duration)
   - **309 succeeded (96.6%)**
   - 11 transient 503s during the target-deregistration window
   - The surviving AZ handled all successful requests — no total outage

**Evidence:** Screenshots in `docs/screenshots/` show the ASG state transition and the continuous success counter climbing while one target was down.

**Files:** `terraform/iam.tf`, `terraform/launch_template.tf`, `terraform/user_data.sh.tpl`, `terraform/asg.tf`

---

### Phase 3 — RDS PostgreSQL Multi-AZ *(upcoming)*

**Goal:** Managed database with automatic failover.

**Planned resources:**
- DB subnet group (spanning private DB subnets)
- RDS PostgreSQL instance (`db.t3.micro` for dev, Multi-AZ)
- Secrets Manager entry for the master password
- Security group `sg-db` (already created in Phase 2A)

---

### Phase 4 — CloudWatch Monitoring + Auto Scaling Policies *(upcoming)*

**Goal:** Observability + elasticity.

**Planned resources:**
- CloudWatch alarms (CPU high, 5XX rate, unhealthy hosts)
- Target-tracking scaling policy (CPU 60%)
- SNS topic for alarm notifications

---

### Phase 5 — GitHub Actions CI/CD with OIDC *(upcoming)*

**Goal:** Automated build → push → deploy on every commit.

**Planned resources:**
- GitHub OIDC provider in IAM
- IAM role for GitHub Actions (no long-lived credentials)
- GitHub Actions workflow:
  - Build Docker image
  - Push to ECR (tagged with commit SHA)
  - Trigger ASG Instance Refresh for rolling deployment

---

### Phase 6 — Cost Controls: S3 Lifecycle + Budgets *(upcoming)*

**Goal:** Keep the AWS bill predictable.

**Planned resources:**
- S3 bucket for ALB access logs + application logs
- S3 lifecycle policy (Standard → IA → Glacier → delete)
- AWS Budget with alerts at 80% and 100%

---

### Phase 7 — Load & Failure Testing + Documentation *(upcoming)*

**Goal:** Prove the architecture works under stress and failure.

**Planned tests:**
- Load test with `hey` / `ab` / `k6`
- Kill an instance → observe ASG replacement
- Simulate AZ failure → observe traffic rerouting
- RDS failover test

---

## Terraform Remote State Setup

State is stored in S3 with native lockfile-based locking (Terraform ≥ 1.10).

### One-time bootstrap

```bash
cd bootstrap
terraform init
terraform apply
```

This creates:
- S3 bucket `threetier-tfstate-<unique>` (versioned, encrypted, public access blocked)
- (Optional) DynamoDB table for legacy locking

### Main project backend

The `terraform/` folder uses the S3 backend configured in `provider.tf`:

```hcl
backend "s3" {
  bucket       = "threetier-tfstate-<unique>"
  key          = "threetier/dev/terraform.tfstate"
  region       = "ap-south-1"
  encrypt      = true
  use_lockfile = true
}
```

---

## Testing

### Verify infrastructure

```bash
terraform state list          # Should show ~35 resources
terraform output              # Show all outputs
```

### Verify ECR

```bash
aws ecr list-images --repository-name threetier-app --region ap-south-1
```

### Verify ALB

```bash
curl -v http://$(terraform output -raw alb_dns_name)/
```

### Verify security groups

```bash
aws ec2 describe-security-groups --group-ids $(terraform output -raw sg_app_id) \
  --query "SecurityGroups[0].[IpPermissions,IpPermissionsEgress]" --output json
```

Confirm: **only** `sg-alb` can reach `sg-app` on port 5000.

---

## Cost Optimization Strategy

| Technique | Savings |
|---|---|
| Two NAT Gateways only where needed | Reduces data processing costs |
| ECR lifecycle policy (10 images) | Prevents unbounded storage growth |
| S3 lifecycle (Standard → IA → Glacier) | Log storage drops 80%+ over time |
| Target-tracking scaling | Right-sized fleet based on demand |
| Scheduled scaling (dev) | Scale to zero at night for non-prod |
| AWS Budgets alerts | Catch runaway costs early |
| Multi-stage Docker builds | Smaller images → faster pulls → lower EC2 time |

---

## Lessons Learned

A few things that took longer than expected — documented so future-me doesn't repeat them.

1. **Terraform state drift is real.** Mixing manual console resources with Terraform-managed infrastructure causes havoc at destroy time. Fix: never touch the console inside a managed VPC.
2. **AWS SG rules are unique per (peer, port, protocol).** Adding the same rule twice (even from different Terraform resources) fails with `InvalidPermission.Duplicate`.
3. **Slim Python Docker images don't include `setuptools`.** Gunicorn needs `pkg_resources`, which needs `setuptools<82` explicitly added to `requirements.txt`.
4. **NAT Gateway creation/destruction is slow (~2 min each).** Plan destroy windows accordingly.
5. **Remote state on S3 is not optional.** Local state is a disaster waiting to happen.
6. **Chained SG references require careful ordering.** Terraform resolves the graph correctly, but manual edits can break it.

---

## Roadmap / Future Work

- [ ] Add HTTPS listener with ACM certificate (requires a domain)
- [ ] Add WAF in front of ALB
- [ ] Add Route 53 hosted zone + alias record
- [ ] Migrate app to ECS Fargate (serverless containers)
- [ ] Add VPC endpoints for ECR, SSM, CloudWatch Logs (avoid NAT egress)
- [ ] Add a second environment (staging) using Terraform workspaces
- [ ] Add Terratest for automated infrastructure testing

---

## Author

**Lucky Jha**
Cloud & DevOps Engineer (in training)

- GitHub: [@luckyjha](https://github.com/) *(update with your real handle)*
- LinkedIn: *(update)*

---

## License

MIT — feel free to fork and adapt.