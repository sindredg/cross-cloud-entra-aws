output "permission_set_names" {
  description = "Names of the Terraform-managed IAM Identity Center permission sets."
  value       = module.identity_center.permission_set_names
}

output "assigned_group_names" {
  description = "SCIM-managed groups assigned to the current AWS account."
  value       = module.identity_center.assigned_group_names
}

output "private_access_target_repository_url" {
  description = "ECR repository for the private target image, when the footprint is deployed."
  value       = one(module.private_access[*].target_repository_url)
}

output "private_access_application_segment_lookup" {
  description = "Command returning the running task's private IP for the Private Access application segment."
  value       = one(module.private_access[*].application_segment_lookup)
}

output "private_access_connector_instance_id" {
  description = "Connector host instance ID for SSM Fleet Manager, when the footprint is deployed."
  value       = one(module.private_access[*].connector_instance_id)
}

output "aws_region" {
  description = "Region the project deploys into."
  value       = var.aws_region
}
