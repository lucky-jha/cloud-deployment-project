# ============================================================================
# Phase 6 — AWS Budget with Alerts
# ============================================================================
# Email alerts when monthly AWS spend crosses thresholds.
# Free to create (AWS allows 2 budgets per account at no cost).
# ============================================================================

variable "budget_alert_email" {
  description = "Email to receive budget alerts"
  type        = string
}

resource "aws_budgets_budget" "monthly" {
  name              = "${var.project_name}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "50"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  # Alert at 80% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Alert at 100% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Forecasted alert at 100%
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}