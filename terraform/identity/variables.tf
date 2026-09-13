variable "aws_region" {
  description = "AWS region containing the IAM Identity Center instance."
  type        = string
  default     = "eu-north-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name."
  }
}

variable "aws_profile" {
  description = "Optional AWS CLI profile. Set to null to use ambient credentials."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.aws_profile == null || length(trimspace(var.aws_profile)) > 0
    error_message = "aws_profile must be null or a non-empty profile name."
  }
}

variable "name_prefix" {
  description = "Lowercase prefix applied to project-managed AWS resources."
  type        = string
  default     = "crosscloud"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,17}$", var.name_prefix))
    error_message = "name_prefix must be 2-18 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Environment tag applied to project-managed AWS resources."
  type        = string
  default     = "project"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment must be 2-16 lowercase letters, numbers, or hyphens and start with a letter."
  }
}
