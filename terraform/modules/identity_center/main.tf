data "aws_ssoadmin_instances" "current" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.current.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0]

  managed_policy_attachments = merge([
    for permission_set_key, permission_set in var.permission_sets : {
      for managed_policy_arn in permission_set.managed_policy_arns :
      "${permission_set_key}:${managed_policy_arn}" => {
        permission_set_key = permission_set_key
        managed_policy_arn = managed_policy_arn
      }
    }
  ]...)
}

data "aws_identitystore_group" "this" {
  for_each = var.permission_sets

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value.group_name
    }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = var.permission_sets

  name             = each.value.name
  description      = each.value.description
  instance_arn     = local.instance_arn
  session_duration = each.value.session_duration
  tags             = var.tags
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = var.permission_sets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  principal_id       = data.aws_identitystore_group.this[each.key].group_id
  principal_type     = "GROUP"
  target_id          = var.target_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.managed_policy_attachments

  depends_on = [aws_ssoadmin_account_assignment.this]

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set_key].arn
  managed_policy_arn = each.value.managed_policy_arn
}
