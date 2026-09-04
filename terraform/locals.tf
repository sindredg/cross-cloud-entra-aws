locals {
  common_tags = {
    Project     = "Cross-Cloud Identity"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  identity_center_permission_sets = {
    administrators = {
      name             = "${var.name_prefix}-Administrator"
      description      = "Administrative access for the cross-cloud project."
      group_name       = "AWS-Administrators"
      session_duration = "PT1H"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AdministratorAccess"
      ]
    }

    developers = {
      name             = "${var.name_prefix}-Developer"
      description      = "Workload administration without IAM administration."
      group_name       = "AWS-Developers"
      session_duration = "PT4H"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/PowerUserAccess"
      ]
    }

    auditors = {
      name             = "${var.name_prefix}-Auditor"
      description      = "Read-only security audit access."
      group_name       = "AWS-Auditors"
      session_duration = "PT4H"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/SecurityAudit"
      ]
    }
  }
}

# Single-AZ test footprint for Phase 5 and Phase 6. One routed subnet for the connector, one isolated subnet for the private target. See ADR-019.
locals {
  private_access_network = {
    vpc_cidr              = "10.20.0.0/16"
    connector_subnet_cidr = "10.20.0.0/24"
    target_subnet_cidr    = "10.20.1.0/24"
  }
}
