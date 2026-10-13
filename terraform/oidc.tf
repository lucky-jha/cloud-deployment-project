# ============================================================================
# Phase 5 — GitHub OIDC Provider + IAM Role for CI/CD
# ============================================================================
# Allows GitHub Actions workflows to authenticate to AWS without long-lived
# credentials. GitHub issues a signed OIDC token for each workflow run;
# AWS verifies it and issues temporary (1-hour) credentials.
#
# Zero secrets stored in GitHub. Zero IAM users. Zero rotation.
# ============================================================================

# ----------------------------------------------------------------------------
# OIDC Provider — tells AWS to trust GitHub as an identity provider
# ----------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # The audience GitHub sends in its OIDC tokens
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC token signing certificate thumbprint.

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # primary root CA
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd", # backup CA (added 2023)
  ]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}