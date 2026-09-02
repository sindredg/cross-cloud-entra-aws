variable "target_account_id" {
  description = "AWS account receiving the IAM Identity Center assignments."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.target_account_id))
    error_message = "target_account_id must contain exactly 12 digits."
  }
}

variable "permission_sets" {
  description = "Permission sets and SCIM-managed groups assigned to the target account."
  type = map(object({
    name                = string
    description         = string
    group_name          = string
    session_duration    = string
    managed_policy_arns = set(string)
  }))

  validation {
    condition     = length(var.permission_sets) > 0
    error_message = "At least one permission set must be configured."
  }

  validation {
    condition     = alltrue([for item in values(var.permission_sets) : can(regex("^PT([1-9]|1[0-2])H$", item.session_duration))])
    error_message = "Each session_duration must be an ISO 8601 duration from PT1H through PT12H."
  }
}

variable "tags" {
  description = "Tags applied to each permission set."
  type        = map(string)
  default     = {}
}
