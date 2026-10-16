# AWS Three-Tier Architecture — Highly Available, Automated & Self-Healing

> An end-to-end Cloud/DevOps portfolio project that provisions AWS infrastructure with Terraform, packages a Flask application with Docker, stores images in Amazon ECR, runs the application on private EC2 instances behind an Application Load Balancer, uses Amazon RDS for PostgreSQL, and automates deployments with GitHub Actions and AWS OIDC.

<p align="center">
  <img alt="AWS" src="https://img.shields.io/badge/AWS-ap--south--1-orange?logo=amazonaws" />
  <img alt="Terraform" src="https://img.shields.io/badge/Terraform-%3E%3D1.10-7B42BC?logo=terraform" />
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Multi--stage-2496ED?logo=docker" />
  <img alt="GitHub Actions" src="https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions" />
  <img alt="PostgreSQL" src="https://img.shields.io/badge/PostgreSQL-16.4-336791?logo=postgresql" />
  <img alt="License" src="https://img.shields.io/badge/License-MIT-green" />
</p>

## Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Key Features](#-key-features)
- [Technology Stack](#-technology-stack)
- [Repository Structure](#-repository-structure)
- [Implementation: Phase by Phase](#-implementation-phase-by-phase)
- [CI/CD Workflow](#-cicd-workflow)
- [Security Design](#-security-design)
- [Testing and Verification](#-testing-and-verification)
- [Deployment Guide](#-deployment-guide)
- [Configuration and Secrets](#-configuration-and-secrets)
- [Troubleshooting and Lessons Learned](#-troubleshooting-and-lessons-learned)
- [Cost Considerations and Cleanup](#-cost-considerations-and-cleanup)
- [Roadmap](#-roadmap)
- [What I Learned](#-what-i-learned)
- [Author](#-author)
- [License](#-license)

## 🎯 Project Overview

This project demonstrates how to design and automate a multi-tier web application deployment on AWS. Rather than placing the application and database on one publicly accessible virtual machine, the infrastructure separates public entry traffic, application compute, and database storage into distinct network tiers.

The Flask application runs in Docker containers on EC2 instances in private subnets. An Application Load Balancer (ALB) accepts incoming HTTP traffic and routes it to healthy application instances. An Auto Scaling Group (ASG) maintains application capacity and can replace unhealthy instances. Amazon RDS for PostgreSQL stores persistent application data in a private database tier.

Terraform defines the infrastructure as code, while GitHub Actions automates image building and deployment. GitHub Actions authenticates to AWS using OpenID Connect (OIDC), avoiding long-lived AWS access keys stored as GitHub secrets.

### Project goals

- Design a three-tier AWS architecture across two Availability Zones.
- Provision repeatable infrastructure with Terraform.
- Package the application into a small, non-root Docker image.
- Keep EC2 application instances and the database out of direct public access.
- Route traffic only to healthy application targets.
- Replace failed instances automatically through Auto Scaling.
- Automate image publication and rolling deployment through GitHub Actions.
- Apply practical security controls, secrets management, logging, and cost alerts.
- Document validation, operational lessons, and future improvements.

## 🏗️ Architecture

![AWS Three-Tier Architecture](docs/architecture.png)

### Request flow

```text
                         Internet / Users
                                |
                           HTTP :80
                                |
                   +-------------------------+
                   | Application Load Balancer|
                   | Public subnets in 2 AZs  |
                   +-------------------------+
                                |
                     TCP :5000 from ALB SG
                                |
              +-----------------------------------+
              | Auto Scaling Group                |
              | EC2 + Docker in private app tiers |
              | AZ-A                     AZ-B     |
              +-----------------------------------+
                                |
                     TCP :5432 from App SG
                                |
                   +-------------------------+
                   | Amazon RDS PostgreSQL    |
                   | Private DB subnets       |
                   | Multi-AZ deployment      |
                   +-------------------------+
```

### Supporting services

- **Amazon ECR** stores versioned Docker images.
- **Terraform state on S3** supports shared state and state locking.
- **AWS Systems Manager (SSM) Session Manager** provides administrative access without opening SSH to the internet.
- **AWS Systems Manager Parameter Store** stores the database password as a `SecureString` parameter.
- **GitHub Actions + AWS OIDC** authenticate the CI/CD workflow using temporary AWS credentials.
- **Amazon CloudWatch** supports operational logs and metrics.
- **S3 access logging bucket and lifecycle rules** control ALB log retention and storage growth.
- **AWS Budgets** provides spending alerts.

### Network layout

The VPC uses `10.0.0.0/16` and six subnets across two Availability Zones:

| Tier | Subnet CIDRs | Purpose |
|---|---|---|
| Public | `10.0.1.0/24`, `10.0.2.0/24` | ALB and NAT Gateways |
| Private application | `10.0.11.0/24`, `10.0.12.0/24` | EC2 instances running Docker |
| Private database | `10.0.21.0/24`, `10.0.22.0/24` | RDS subnet group |

The public route table directs internet-bound traffic through an Internet Gateway. Private application subnets use NAT Gateways for required outbound access. The database remains in private subnets and is not publicly accessible.

## ✨ Key Features

### High availability and recovery

- Two Availability Zones for the ALB and application capacity.
- Auto Scaling Group configured with desired capacity `2`, minimum `2`, and maximum `4` instances.
- ALB health checks on `/health` to identify healthy application targets.
- ELB health checks for the Auto Scaling Group so unhealthy targets can be replaced.
- RDS configured for Multi-AZ deployment.
- Instance refresh used to roll application instances during deployment.

### Containerization

- Python 3.12 Flask application.
- Multi-stage Docker build to reduce the final image size.
- Non-root container user (`appuser`, UID 1000).
- Gunicorn WSGI server rather than Flask's development server.
- Docker health check and pinned Python dependencies.
- Amazon ECR image repository with image scanning and lifecycle policy.

### Automation

- GitHub Actions workflow builds and pushes the application image.
- Images are tagged with the commit SHA for traceability.
- AWS OIDC federation supplies temporary AWS credentials to CI/CD.
- Terraform updates the launch template and the workflow initiates an ASG instance refresh.
- Deployment waits for the refresh to finish instead of treating the trigger alone as a successful rollout.

### Security

- Security-group chain: `Internet → ALB SG → App SG → DB SG`.
- No inbound SSH rule is required for EC2 administration.
- EC2 uses an instance role to pull ECR images and retrieve its required parameter.
- IMDSv2 is enforced on EC2 instances.
- RDS, EBS root volumes, and relevant S3 storage are encrypted at rest.
- Database credentials are retrieved from SSM Parameter Store at boot.
- GitHub Actions uses OIDC instead of persistent AWS access keys.

### Cost controls

- ECR lifecycle policy retains a limited number of recent images.
- S3 lifecycle policy transitions and expires ALB logs.
- AWS Budget alerts are configured around a monthly budget.
- Instance sizes are kept small for a portfolio environment.
- The ASG can scale in to its configured minimum capacity.

> **Important:** This is a portfolio and learning project, not a claim of formal production certification. Costs, availability, security, and performance depend on the AWS account, region, configuration, and workload. Review the plan and actual service configuration before using it for a real workload.

## 🧰 Technology Stack

| Area | Technology |
|---|---|
| Cloud provider | AWS, `ap-south-1` (Mumbai) |
| Infrastructure as Code | Terraform `>= 1.10` |
| Compute | EC2, Amazon Linux 2023, Auto Scaling Group |
| Networking | VPC, subnets, route tables, Internet Gateway, NAT Gateways |
| Load balancing | Application Load Balancer, target group, health checks |
| Containers | Docker, multi-stage Dockerfile |
| Image registry | Amazon ECR |
| Database | Amazon RDS for PostgreSQL 16.4, Multi-AZ |
| Application | Python 3.12, Flask, Gunicorn |
| CI/CD | GitHub Actions |
| CI/CD identity | AWS IAM OIDC federation |
| Secrets | AWS Systems Manager Parameter Store (`SecureString`) |
| Access management | IAM, security groups, SSM Session Manager, IMDSv2 |
| Logs and metrics | Amazon CloudWatch, ALB access logs in S3 |
| Cost management | AWS Budgets, S3/ECR lifecycle policies |

## 📂 Repository Structure

```text
.
├── app/
│   ├── app.py                    # Flask routes and request handlers
│   ├── db.py                     # PostgreSQL connection pool and helpers
│   ├── requirements.txt          # Python dependencies
│   ├── Dockerfile                # Multi-stage, non-root container build
│   ├── templates/
│   │   └── index.html            # Dashboard UI
│   └── static/
│       └── style.css             # Dashboard styling
├── terraform/
│   ├── provider.tf               # AWS provider and remote state backend
│   ├── variables.tf              # Input variable declarations
│   ├── terraform.tfvars          # Environment-specific variable values
│   ├── vpc.tf                    # VPC, subnets, gateways, routes
│   ├── security-group.tf         # Tiered security groups
│   ├── ecr.tf                    # ECR repository and lifecycle policy
│   ├── alb.tf                    # ALB, target group, listener
│   ├── iam.tf                    # EC2 instance role and permissions
│   ├── launch_template.tf        # EC2 launch template and metadata settings
│   ├── user_data.sh.tpl          # Instance bootstrap script
│   ├── asg.tf                    # Auto Scaling Group and refresh settings
│   ├── rds.tf                    # PostgreSQL RDS and parameter configuration
│   ├── oidc.tf                   # GitHub OIDC identity provider
│   ├── oidc_role.tf              # GitHub Actions IAM role and trust policy
│   ├── s3.tf                     # ALB log bucket and lifecycle rules
│   ├── budget.tf                 # AWS Budget and alerts
│   └── outputs.tf                # Useful Terraform outputs
├── bootstrap/
│   └── main.tf                   # Initial S3 backend bucket resources
├── docs/
│   ├── architecture.png          # Architecture diagram
│   └── screenshots/
│       └── dashboard.png         # Dashboard screenshot
├── .github/
│   └── workflows/
│       └── deploy.yml            # GitHub Actions deployment workflow
├── .gitignore
├── LICENSE
└── README.md
```

*The tree documents the expected project layout. Keep it synchronized with the actual repository whenever files are added, removed, or renamed.*

## 🔧 Implementation: Phase by Phase

This section describes the major implementation stages, the reason for each stage, and the design decisions involved.

### Phase 1 — Terraform state and networking foundation

**Objective:** Create a repeatable, multi-AZ network foundation before deploying compute resources.

Implemented components:

- VPC `10.0.0.0/16` with DNS support and DNS hostnames enabled.
- Two public subnets for the ALB and NAT Gateways.
- Two private application subnets for EC2 instances.
- Two private database subnets for RDS.
- Internet Gateway for public subnet routing.
- NAT Gateway per Availability Zone for outbound access from private application subnets.
- Route tables that separate public routing from private application routing.
- S3 backend bootstrap resources for Terraform state, including versioning and encryption.

**Why this matters:** Terraform state maps configuration to real infrastructure. A remote backend supports collaboration and continuity, while versioning can help recover from accidental state-object changes. State can contain sensitive values, so access to the backend must be tightly restricted. Initialize the backend only after the bootstrap bucket exists.

**Validation:** Review subnet CIDRs for overlap, confirm route-table associations, and inspect `terraform plan` before applying changes.

### Phase 2 — Network security and container registry

**Objective:** Restrict traffic between tiers and establish a private place to store application images.

The security model is:

```text
Internet → ALB security group → App security group → DB security group
```

| Security group | Inbound access | Purpose |
|---|---|---|
| ALB | HTTP `80` (and HTTPS `443` if configured) from approved public sources | Public entry point |
| App | TCP `5000` only from the ALB security group | Flask/Gunicorn application traffic |
| DB | TCP `5432` only from the application security group | PostgreSQL connections |

Egress should be restricted to the destinations and ports the application needs. No inbound TCP port `22` is needed when using SSM Session Manager.

Amazon ECR is configured as the private container registry. The repository uses image scanning and a lifecycle policy to limit the number of old images retained.

**Why this matters:** Security-group references express trust between tiers without relying on broad source CIDR ranges. ECR keeps deployment artifacts in AWS and lets the EC2 instance role pull images without storing registry credentials on the server.

**Validation:** Check each ingress and egress rule, verify that the application port is not open to the public internet, and confirm that the EC2 role has only the ECR permissions it requires.

### Phase 3 — Application Load Balancer and compute layer

**Objective:** Serve the application through a stable endpoint and replace unhealthy compute instances.

The ALB spans the public subnets and forwards requests to a target group on TCP port `5000`. The target group's `/health` endpoint is used for health checks. The documented health-check settings are a 30-second interval, 5-second timeout, two failed checks, and HTTP `200` as the expected status.

The launch template configures Amazon Linux 2023, an encrypted `gp3` root volume, a dynamically selected AMI, and mandatory IMDSv2. User data installs Docker and the required AWS/SSM components, retrieves configuration at boot, pulls the application image from ECR, and starts the container through a systemd-managed service.

The Auto Scaling Group spans the private application subnets, registers instances with the target group, uses ELB health checks, and is configured for desired capacity `2`, minimum `2`, and maximum `4`.

**Why this matters:** The ALB provides a stable public entry point while EC2 instances remain private. Health checks help stop routing traffic to unhealthy targets, and the ASG replaces failed instances. A successful replacement does not by itself guarantee zero failed requests; deregistration, startup time, application readiness, and remaining capacity all affect user traffic.

**Validation:** Confirm target registration and health, verify that private instances have no public IP exposure, test SSM access, and observe the ASG after terminating a test instance.

### Phase 4 — Flask application, Docker image, and database integration

**Objective:** Package the application consistently and keep application data in a managed database.

The application is split into two main modules:

- `app/app.py` contains the Flask routes and request handlers.
- `app/db.py` contains PostgreSQL connection and data-access helpers.

The dashboard reports information such as the serving instance, Availability Zone, database-backed visit count, and database latency. The `/health` endpoint supports load-balancer health checks, while `/api/visits` exposes the visit counter used during verification.

The Dockerfile uses a multi-stage build, runs the application as a non-root user, and launches Gunicorn. The documented final image size is approximately 146 MB; actual size depends on the current dependencies and build context.

Amazon RDS for PostgreSQL is configured for private access and Multi-AZ deployment, with encryption at rest and a seven-day backup-retention setting. The database security group allows PostgreSQL connections only from the application security group.

The database password is generated during provisioning and stored in SSM Parameter Store as a `SecureString`. The instance role retrieves the parameter during bootstrap, and the startup script writes the runtime environment file with restrictive file permissions before starting the container.

The database helper uses a connection pool, initialization retry logic, and an atomic SQL update for the visit counter to reduce race conditions during concurrent requests.

**Why this matters:** Containers standardize packaging, Gunicorn is intended for production-style WSGI serving, RDS separates persistent data from replaceable compute, and Parameter Store avoids hard-coding the database password in the application source.

**Validation:** Build and run the image, check `/health`, confirm database connectivity, verify that the visit counter persists across application-instance replacement, and inspect logs for accidental secret disclosure.

### Phase 5 — GitHub Actions CI/CD with AWS OIDC

**Objective:** Automate the build and release process without long-lived AWS access keys.

The GitHub Actions workflow in `.github/workflows/deploy.yml` is designed to run when changes are pushed to `main` that affect `app/**` or the workflow itself.

The pipeline follows this sequence:

1. Check out the repository.
2. Request an OIDC identity token from GitHub Actions.
3. Assume the configured AWS IAM role through AWS STS and receive temporary credentials.
4. Authenticate Docker to Amazon ECR.
5. Build the Docker image.
6. Tag the image with the Git commit SHA.
7. Push the image to ECR.
8. Run Terraform to update the launch template with the new image version.
9. Cancel an in-progress instance refresh when appropriate and start a fresh ASG instance refresh.
10. Wait for the refresh to complete and report the workflow result.

The IAM trust policy should be scoped to the intended repository and branch/ref. The deployment role should grant only the permissions required for the pipeline. The intended design avoids storing static AWS access keys in repository secrets.

**Important deployment detail:** Updating a launch template does not always start an ASG instance refresh automatically. The workflow explicitly starts the refresh so the new launch-template version is rolled out to instances.

**Validation:** Check the workflow run, verify that the image tag matches the commit SHA, inspect the active launch-template version, and confirm that the replacement targets become healthy before considering the deployment complete.

### Phase 6 — Logging, lifecycle policies, and cost alerts

**Objective:** Make operations easier to investigate and put guardrails around ongoing storage and cloud spend.

- ALB access logs are written to an S3 bucket with public access blocked and encryption enabled.
- The S3 lifecycle policy transitions older logs to lower-cost storage classes and expires them after the configured retention period.
- ECR lifecycle rules retain the latest ten images and remove older images according to policy.
- AWS Budgets is configured around a `$50` monthly budget, with alerts at 80% and 100% actual spend and a forecast alert at 100%.
- Small instance sizes are used for the portfolio environment, but eligibility and pricing depend on account, region, and current AWS terms.

**Validation:** Confirm that the ALB can deliver logs to S3, inspect lifecycle and budget configuration, and check AWS Cost Explorer or Billing for actual charges. Budget notifications are alerts, not hard spending caps.

### Phase 7 — Reliability and performance verification

**Objective:** Test behavior under concurrent traffic and during an instance failure rather than relying only on a successful deployment.

The documented test scenarios include:

- HTTP load against `/` using `hey`.
- Concurrent requests against `/api/visits` to exercise the database-backed counter.
- Terminating one EC2 instance while sending requests through the ALB.
- Observing ASG replacement and target health.
- Rolling instances through an ASG instance refresh.

The test figures recorded in this repository are listed in [Testing and Verification](#-testing-and-verification). They are observations from a particular test environment, not a guarantee of performance for other workloads or AWS accounts.

## 🔁 CI/CD Workflow

```text
Developer pushes application change to main
                    |
                    v
            GitHub Actions workflow
                    |
                    v
          Authenticate with AWS OIDC
                    |
                    v
             Build Docker image
                    |
                    v
          Tag image with commit SHA
                    |
                    v
               Push image to ECR
                    |
                    v
      Update Terraform launch template
                    |
                    v
          Start ASG instance refresh
                    |
                    v
       New instances pull the new image
                    |
                    v
      ALB health checks verify targets
                    |
                    v
          Workflow reports the result
```

### Why use commit-SHA image tags?

A commit-SHA tag ties a deployed image to a specific source revision. It makes it easier to identify what code is running and to select a previous image for a rollback. Avoid relying only on mutable tags such as `latest` for release traceability.

### Why use OIDC?

With OIDC federation, GitHub Actions obtains temporary AWS credentials by assuming an IAM role trusted for the appropriate repository/ref. This avoids maintaining long-lived AWS access keys as GitHub secrets. The trust policy and role permissions still require careful scoping and review.

## 🔐 Security Design

| Control | Purpose |
|---|---|
| Private application subnets | Prevent direct public ingress to EC2 application instances |
| Private database subnets | Keep RDS off the public internet |
| Chained security groups | Permit only expected tier-to-tier traffic |
| SSM Session Manager | Administrative access without opening SSH ingress |
| EC2 instance role | Provide AWS permissions to instances without embedded access keys |
| IMDSv2 | Require session-oriented metadata access |
| Encrypted EBS, RDS, and S3 storage | Protect supported data at rest |
| SSM Parameter Store `SecureString` | Store the database password outside application source code |
| GitHub OIDC | Use temporary AWS credentials in CI/CD |
| ECR image scanning | Identify image vulnerabilities for review |
| Least-privilege IAM | Reduce the impact of a compromised workflow or instance |

### Security checklist before publishing or deploying

- [ ] Do not commit AWS access keys, database passwords, tokens, or private keys.
- [ ] Ensure `terraform.tfstate`, state backups, and sensitive `.tfvars` files are excluded from Git.
- [ ] Confirm the OIDC trust policy is scoped to the correct repository and branch/ref.
- [ ] Confirm the GitHub Actions role cannot perform unnecessary destructive operations.
- [ ] Keep the RDS instance private and restrict port `5432` to the application security group.
- [ ] Keep application port `5000` inaccessible directly from the internet.
- [ ] Review IAM policies, SSM parameter permissions, S3 bucket policies, and log access.
- [ ] Do not publish Terraform plans or logs if they contain sensitive values.
- [ ] Rotate any credential immediately if it has ever been committed or exposed.

## 🧪 Testing and Verification

### Load test: dashboard route

The repository records the following result for a `hey` run with 5,000 requests and 200 concurrent workers against `/`:

| Metric | Recorded result |
|---|---:|
| Total requests | 5,000 |
| Duration | 4.12 seconds |
| Requests per second | 1,212.62 |
| Average latency | 0.164 seconds |
| P95 latency | 0.321 seconds |
| P99 latency | 0.452 seconds |
| Successful HTTP responses | 5,000 × `200` |
| Errors | 0 |

### Load test: database-backed visit counter

The repository records the following result for 1,000 requests with 50 concurrent workers against `/api/visits`:

| Metric | Recorded result |
|---|---:|
| Total requests | 1,000 |
| Duration | 2.85 seconds |
| Requests per second | 351.47 |
| Average latency | 0.142 seconds |
| Successful HTTP responses | 1,000 × `200` |
| Errors | 0 |

### Self-healing test

The documented test terminated one EC2 instance while sending requests through the ALB.

| Metric | Recorded result |
|---|---:|
| Test duration | Approximately 5 minutes |
| Requests | Approximately 600 |
| Successful requests | Approximately 590 (98.3%) |
| Transient failures | Approximately 10 during target deregistration/replacement |
| Total outage observed | 0 seconds of complete service outage |
| Instance replacement time | Approximately 3 minutes |
| Manual intervention | None during the test |

The surviving instance handled traffic while the ASG replaced the terminated instance. The recorded result includes transient request failures, so it should not be described as 100% request success. Actual results depend on the timing of health checks, target deregistration, application startup, and workload.

### Rolling deployment verification

The project uses ASG instance refresh with a configured minimum healthy percentage of 50% and a 60-second warm-up setting. Verify the deployment in practice by watching target health, instance refresh status, and HTTP responses throughout the rollout. Do not assume a zero-downtime outcome without repeatable test evidence.

> **Reproducibility note:** Keep dated test logs, the exact command, workload settings, region, instance types, and commit SHA alongside screenshots or other evidence. Results written here describe the test results recorded for this project and are not an independent benchmark.

## 🚀 Deployment Guide

> **Cost warning:** This project can create billable resources, including NAT Gateways, an ALB, EC2 instances, RDS Multi-AZ, ECR storage, and log storage. Review expected costs before applying Terraform. Do not deploy into a production AWS account without reviewing the configuration.

### Prerequisites

- An AWS account and access to deploy the required services in `ap-south-1`.
- AWS CLI configured for local administration.
- Terraform `>= 1.10`.
- Docker.
- Git.
- A GitHub repository with Actions enabled.
- Appropriate IAM permissions for the initial backend bootstrap and Terraform provisioning.

### 1. Clone the repository

```bash
git clone https://github.com/lucky-jha/cloud-deployment-project.git
cd cloud-deployment-project
```

### 2. Review configuration

Review the Terraform files and environment-specific values before provisioning. Confirm region, resource names, CIDRs, budget email, OIDC repository/ref settings, and all variables. Do not put secrets in tracked files.

```bash
cd bootstrap
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the plan carefully, then apply the bootstrap configuration to create the remote-state resources:

```bash
terraform apply
```

The backend bucket must exist before Terraform can initialize a configuration that uses it as its backend. Follow the backend settings in the repository and initialize the main Terraform configuration only after bootstrap is complete.

### 3. Initialize and validate the main infrastructure

```bash
cd ../terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Read the complete plan before applying it. Verify the selected account and region and confirm the plan will not modify unrelated resources.

```bash
terraform apply
```

Terraform may display sensitive values or resource identifiers in output. Treat state and execution logs as potentially sensitive and restrict access appropriately.

### 4. Configure GitHub Actions OIDC

In the GitHub repository settings, configure Actions permissions and the AWS OIDC trust relationship according to `oidc.tf` and `oidc_role.tf`. The trust policy must match the actual repository owner/repository/ref claims emitted by GitHub. Do not copy an example subject claim blindly; inspect the claims and current workflow configuration for your repository.

Confirm that the deployment role has only the permissions required to push images, update the launch template, and initiate or monitor the instance refresh. Do not store permanent AWS access keys in GitHub secrets for this OIDC flow.

### 5. Deploy an application change

Make a change under `app/`, commit it, and push it to the configured branch:

```bash
git add app/
git commit -m "Update application"
git push origin main
```

Open the **Actions** tab in GitHub and inspect the workflow run. Confirm the image is pushed to ECR, the launch template references the expected image, the instance refresh completes, and the new targets become healthy.

### 6. Verify the application

Use the ALB DNS name exposed by the Terraform outputs. For example:

```bash
curl -i http://<ALB-DNS-NAME>/health
curl -i http://<ALB-DNS-NAME>/api/visits
```

Replace `<ALB-DNS-NAME>` with the actual output from your deployment. The health endpoint should return the configured success status, and the visit endpoint should return the application's expected response. Use the dashboard to inspect the instance/AZ information where available.

### 7. Administer instances without SSH

Use AWS Systems Manager Session Manager after confirming that the EC2 instance has the required instance role, SSM agent, and network access to the SSM endpoints. No public SSH rule should be necessary.

### Important notes

- These steps are a deployment outline; exact variable names and backend settings must match the files in the checked-out repository.
- Run `terraform plan` before each apply and review destructive changes.
- If the workflow applies Terraform, avoid running competing applies against the same state at the same time.
- A successful workflow run should be followed by application-level health verification.

## 🔑 Configuration and Secrets

The project uses Terraform variables and AWS-managed configuration. Before deploying, review the exact variable declarations in `terraform/variables.tf` and values in the environment-specific configuration file.

- Keep non-sensitive configuration separate from credentials.
- Store the database password in SSM Parameter Store as a `SecureString` and limit access to the specific parameter ARN.
- Use IAM roles for EC2 and GitHub Actions rather than embedding AWS access keys.
- Never commit `terraform.tfstate`, state backups, `.env` files containing secrets, private keys, or credentials.
- If `terraform.tfvars` contains sensitive values, remove it from version control and use an ignored local file or a supported CI secret-injection method instead. A `.gitignore` entry does not remove a file that is already tracked.
- Treat Terraform state as sensitive even when the password is stored in SSM: Terraform resources and generated values may still place sensitive data in state depending on how they are configured.

## 🛠️ Troubleshooting and Lessons Learned

### 1. Terraform state drift

**Problem:** Manually creating or modifying Terraform-managed resources in the AWS Console can cause drift and unexpected plans or destroy behavior.

**Lesson:** Make routine changes through Terraform. If manual recovery is necessary, reconcile the real infrastructure with state and configuration before applying again.

### 2. Duplicate security-group rules

**Problem:** Defining the same ingress or egress rule in multiple Terraform resources can produce duplicate-permission errors.

**Lesson:** Give each rule a single source of ownership and review the planned security-group changes.

### 3. GitHub OIDC trust-policy mismatch

**Problem:** The token's subject and other claims must match the IAM role's trust policy. A mismatch prevents role assumption.

**Lesson:** Inspect the current repository identity and GitHub OIDC claims; do not assume the subject format is identical across repositories or configurations.

### 4. Terraform variable precedence

**Problem:** A value in a higher-precedence variable source can override an environment variable unexpectedly.

**Lesson:** Keep deployment-specific image tags out of static `terraform.tfvars` when CI must supply a commit-specific value. Check Terraform's documented variable precedence and inspect the plan to confirm the value that will be used.

### 5. Launch-template changes and instance refresh

**Problem:** Updating a launch template does not necessarily cause existing ASG instances to be replaced automatically.

**Lesson:** Trigger and monitor an instance refresh explicitly when required, and verify that the refresh uses the intended launch-template version.

### 6. Health checks and transient failures

**Problem:** A replacement instance needs time to boot, pull the image, start the application, connect to the database, and pass health checks.

**Lesson:** Configure health-check grace periods, warm-up, target deregistration, and application readiness deliberately. Test under traffic rather than assuming instance replacement guarantees zero failed requests.

## 💰 Cost Considerations and Cleanup

The project documentation estimates an example running cost of approximately **US$2.70 per day / US$80 per month** for the described resources. This is an estimate from the project notes, not a live quote; actual costs vary by region, service pricing, usage, data transfer, storage, and account discounts. NAT Gateways and Multi-AZ RDS can be significant cost drivers, and small instances do not make the whole architecture free.

Cost controls used by the project include:

- ECR lifecycle rules to limit stored images.
- S3 lifecycle transitions and expiration for ALB logs.
- AWS Budget notifications.
- Small instance sizes for the learning environment.
- Auto Scaling capacity limits.

### Before you finish a session

1. Check AWS Billing/Cost Explorer and confirm which resources are still running.
2. If you no longer need the environment, use the correct Terraform working directory and state to destroy resources that Terraform manages.
3. Review dependencies before destroying resources. Do not delete a backend bucket or state object before the infrastructure using that state is safely removed and the state is no longer needed.
4. Check for resources created manually or retained by lifecycle/deletion settings, such as snapshots, log objects, ECR images, or other residual storage.
5. Verify in the AWS Console that billable resources have actually been removed.

> AWS Budgets sends notifications; it does not automatically cap spending. Always verify cleanup in the AWS account.

## 🗺️ Roadmap

- [ ] Configure HTTPS with an ACM certificate and an HTTPS ALB listener.
- [ ] Add Route 53 DNS and an alias record for a custom domain.
- [ ] Add AWS WAF rules where appropriate.
- [ ] Evaluate VPC endpoints for ECR, SSM, and CloudWatch to reduce NAT dependency.
- [ ] Add a separate staging environment and a controlled promotion process.
- [ ] Add automated infrastructure tests, for example with Terratest.
- [ ] Add Prometheus and Grafana if deeper metrics and dashboards are needed.
- [ ] Add Trivy image scanning to the CI pipeline and define how findings block or warn on releases.
- [ ] Add an explicit rollback workflow and document recovery objectives.
- [ ] Document repeatable load tests and retain dated evidence for each run.

## 🧠 What I Learned

Working through this project helped me connect cloud concepts into a single deployment lifecycle:

- Designing public, private application, and private database tiers in a VPC.
- Using Terraform to describe, validate, and manage AWS infrastructure.
- Understanding Terraform state, drift, variable precedence, and safe change planning.
- Building Docker images and running a Flask application with Gunicorn as a non-root user.
- Using ECR as a private image registry and IAM roles for image pulls.
- Configuring an ALB, target health checks, and an Auto Scaling Group.
- Storing database credentials in Parameter Store and restricting database access through security groups.
- Using GitHub OIDC to exchange repository identity for temporary AWS credentials.
- Automating image builds and rolling deployments through GitHub Actions.
- Testing service behavior under load and during instance replacement.
- Considering logs, lifecycle policies, budgets, and teardown as part of cloud engineering.

The most valuable part of the project was troubleshooting the interactions between services—not just creating individual AWS resources.

## 👨‍💻 Author

**Lucky Jha** — Computer Engineering Student | Cloud & DevOps Engineer in Training

- GitHub: [@lucky-jha](https://github.com/lucky-jha)
- Project repository: [cloud-deployment-project](https://github.com/lucky-jha/cloud-deployment-project)
- LinkedIn: [lucky-jha](https://www.linkedin.com/in/lucky-jha/)

I'm building hands-on projects around AWS, Linux, Terraform, Docker, and CI/CD to develop practical cloud infrastructure and deployment skills.

## 📄 License

This project is fully made my self and feel free to fork ... thanks for scrolling till end of this project .

---

*Built through hands-on implementation, troubleshooting, testing, and iterative improvement.*
