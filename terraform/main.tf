data "aws_caller_identity" "current" {}

module "identity_center" {
  source = "./modules/identity_center"

  target_account_id = data.aws_caller_identity.current.account_id
  permission_sets   = local.identity_center_permission_sets
  tags              = local.common_tags
}

module "private_access" {
  source = "./modules/private_access"
  count  = var.enable_private_access ? 1 : 0

  name_prefix           = var.name_prefix
  vpc_cidr              = local.private_access_network.vpc_cidr
  connector_subnet_cidr = local.private_access_network.connector_subnet_cidr
  target_subnet_cidr    = local.private_access_network.target_subnet_cidr
  connector_key_name    = var.connector_key_name
  tags                  = local.common_tags
}
