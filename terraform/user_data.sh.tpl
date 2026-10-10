#!/bin/bash
set -euo pipefail

# ============================================================================
# user_data — runs on first boot of each app instance
# ============================================================================
# 1. Install Docker
# 2. Authenticate to ECR
# 3. Pull the image
# 4. Run the container as a systemd service (survives reboots)
# ============================================================================

exec > >(tee /var/log/user-data.log| logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting user_data at $(date) ==="

#insatalling docker 

dnf update -y
dnf install -y docker
systemctl enable --now docker

# ---------- Authenticate to ECR ----------
# Uses the instance IAM role — no credentials needed
REGION="${aws_region}"
ECR_URL="${ecr_repository_url}"
APP_VERSION="${app_version}"
CONTAINER_PORT="${container_port}"

echo "=== Authenticating to ECR ==="
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $(echo $ECR_URL | cut -d/ -f1)
  
# ---------- Pull the image ----------
echo "=== Pulling image $ECR_URL:$APP_VERSION ==="
docker pull $ECR_URL:$APP_VERSION

# ---------- Run the container ----------
# Using a systemd unit so it auto-restarts on failure and on boot
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
ExecStartPre=-/usr/bin/docker stop app-container
ExecStartPre=-/usr/bin/docker rm app-container
ExecStartPre=/usr/bin/docker pull $ECR_URL:$APP_VERSION
ExecStart=/usr/bin/docker run --rm --name app-container \\
  -p $CONTAINER_PORT:$CONTAINER_PORT \\
  -e APP_VERSION=$APP_VERSION \\
  -e PORT=$CONTAINER_PORT \\
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

echo "=== user_data complete at $(date) ==="
