#!/bin/bash
set -euo pipefail

# ============================================================================
# user_data — runs on first boot of each app instance
# ============================================================================
# 1. Install Docker
# 2. Fetch DB credentials from SSM Parameter Store
# 3. Authenticate to ECR
# 4. Pull the image
# 5. Run the container as a systemd service with DB env vars
# ============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting user_data at $(date) ==="

# ---------- Variables provided by Terraform templatefile() ----------
REGION="${aws_region}"
ECR_URL="${ecr_repository_url}"
APP_VERSION="${app_version}"
CONTAINER_PORT="${container_port}"
DB_HOST="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
SSM_DB_PASSWORD_PATH="${ssm_db_password_path}"

# ---------- Detect AZ from EC2 metadata (IMDSv2) ----------

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "=== Running in AZ: $AWS_AZ ==="

# ---------- Install Docker ----------
dnf update -y
dnf install -y docker
systemctl enable --now docker

# ---------- Fetch DB password from SSM Parameter Store ----------
# The instance role grants ssm:GetParameter on exactly this parameter ARN.
echo "=== Fetching DB password from SSM ==="
DB_PASSWORD=$(aws ssm get-parameter \
  --name "$SSM_DB_PASSWORD_PATH" \
  --with-decryption \
  --region "$REGION" \
  --query "Parameter.Value" \
  --output text)

if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: Failed to retrieve DB password from SSM"
  exit 1
fi

# ---------- Authenticate to ECR ----------
echo "=== Authenticating to ECR ==="
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$(echo "$ECR_URL" | cut -d/ -f1)"

# ---------- Pull the image ----------
echo "=== Pulling image $ECR_URL:$APP_VERSION ==="
docker pull "$ECR_URL:$APP_VERSION"

# ---------- Write env file for the systemd service ----------
# Environment variables in a file are visible only to root; the docker run
# command reads them via `--env-file` so the password never appears in `ps`.

echo "=== Writing env file ==="
install -m 600 -o root -g root /dev/null /etc/app.env
cat > /etc/app.env <<EOF
APP_VERSION=$APP_VERSION
BUILD_SHA=$(cat /etc/machine-id | head -c 12)
PORT=$CONTAINER_PORT
AWS_REGION=$REGION
AWS_AZ=$AWS_AZ                    
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

# ---------- systemd unit ----------
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/app.service <<EOF
[Unit]
Description=Three-tier app container
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=5
TimeoutStopSec=30
ExecStartPre=-/usr/bin/docker stop app-container
ExecStartPre=-/usr/bin/docker rm app-container
ExecStartPre=/usr/bin/docker pull $ECR_URL:$APP_VERSION
ExecStart=/usr/bin/docker run --rm --name app-container \\
  -p $CONTAINER_PORT:$CONTAINER_PORT \\
  --env-file /etc/app.env \\
  --log-driver=json-file \\
  --log-opt max-size=10m \\
  --log-opt max-file=3 \\
  $ECR_URL:$APP_VERSION

ExecStop=/usr/bin/docker stop app-container

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now app.service

# ---------- Give the container a moment to start, then report ----------
sleep 5
echo "=== Container status ==="
docker ps
echo "=== user_data complete at $(date) ==="