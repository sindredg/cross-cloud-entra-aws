output "permission_set_names" {
  description = "Names of the managed permission sets."
  value       = { for key, item in aws_ssoadmin_permission_set.this : key => item.name }
}

output "assigned_group_names" {
  description = "Display names of the assigned SCIM-managed groups."
  value       = { for key, item in var.permission_sets : key => item.group_name }
}
