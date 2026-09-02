output "permission_set_names" {
  description = "Names of the Terraform-managed IAM Identity Center permission sets."
  value       = module.identity_center.permission_set_names
}

output "assigned_group_names" {
  description = "SCIM-managed groups assigned to the current AWS account."
  value       = module.identity_center.assigned_group_names
}
