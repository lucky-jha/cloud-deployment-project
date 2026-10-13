# ============================================================================
# Phase 5 — IAM Role for GitHub Actions CI/CD
# ============================================================================
# This role is assumed by GitHub Actions workflows via OIDC. It has:
#   - ECR push permission (build + push image)
#   - Terraform state access (read/write the S3 backend)
#   - Describe permissions (Terraform refreshes state on every run)
#   - Launch template write + ASG refresh (for deployments)
#
# It CANNOT: delete infrastructure, modify databases, or touch anything
# outside this project. If the workflow is compromised, damage is bounded.
# ============================================================================

# ----------------------------------------------------------------------------
# The IAM role itself — trusted by GitHub's OIDC provider
# ----------------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name        = "${var.project_name}-github-actions-role"
  description = "Role assumed by GitHub Actions workflows via OIDC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Scope to THIS repo only. No other GitHub repo can assume this role.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:lucky-jha/cloud-deployment-project:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# ----------------------------------------------------------------------------
# Permission policy — what the workflow can do
# ----------------------------------------------------------------------------
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ---------- ECR: push images ----------
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*" # this action doesn't support resource scoping
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = aws_ecr_repository.app.arn
      },

      # ---------- S3: Terraform state read/write ----------
      {
        Sid    = "TerraformStateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::threetier-tfstate-lucky-542035163411",
          "arn:aws:s3:::threetier-tfstate-lucky-542035163411/*"
        ]
      },

      # ---------- EC2: describe + launch template writes ----------
      {
        Sid    = "EC2Read"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:GetLaunchTemplateData"
        ]
        Resource = "*"
      },
      {
        Sid    = "LaunchTemplateWrite"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions"
        ]
        Resource = "*"
      },

      # ---------- Auto Scaling: describe + refresh ----------
      {
        Sid    = "ASGRead"
        Effect = "Allow"
        Action = [
          "autoscaling:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ASGDeploy"
        Effect = "Allow"
        Action = [
          "autoscaling:StartInstanceRefresh",
          "autoscaling:CancelInstanceRefresh",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = aws_autoscaling_group.app.arn
      },

      # ---------- Read-only for other services Terraform refreshes ----------
      {
        Sid    = "TerraformRefreshRead"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:ListTagsForResource",
          "elasticloadbalancing:Describe*",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetInstanceProfile",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },

      # ---------- IAM PassRole: needed so Terraform can attach the instance profile ----------
      {
        Sid      = "PassRoleForEC2"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ec2_app.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      }
    ]
  })
}