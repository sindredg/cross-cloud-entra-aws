data "aws_caller_identity" "current" {}

module "identity_center" {
  source = "./modules/identity_center"

  target_account_id = data.aws_caller_identity.current.account_id
  permission_sets   = local.identity_center_permission_sets
  tags              = local.common_tags
}
