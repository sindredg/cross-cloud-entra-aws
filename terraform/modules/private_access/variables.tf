variable "name_prefix" {
  description = "Lowercase prefix applied to the resources in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the project VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "connector_subnet_cidr" {
  description = "CIDR block of the routed subnet holding the connector."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.connector_subnet_cidr))
    error_message = "connector_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "target_subnet_cidr" {
  description = "CIDR block of the isolated subnet holding the private target."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.target_subnet_cidr))
    error_message = "target_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "connector_instance_type" {
  description = "Instance type for the Windows connector host. Microsoft recommends four vCPUs and 8 GiB."
  type        = string
  default     = "t3.xlarge"
}

variable "target_task_cpu" {
  description = "Fargate CPU units for the private target task. Grafana needs more than the smallest size."
  type        = number
  default     = 512
}

variable "target_task_memory" {
  description = "Fargate memory (MiB) for the private target task."
  type        = number
  default     = 1024
}

variable "target_image_tag" {
  description = "Tag of the private target image in the project ECR repository."
  type        = string
  default     = "latest"
}

variable "log_retention_days" {
  description = "Retention for the private target log group. Kept short; this is a test footprint."
  type        = number
  default     = 7
}

variable "connector_key_name" {
  description = <<-EOT
    Name of an existing EC2 key pair used to retrieve the connector's Windows
    administrator password. Create the key pair outside Terraform so no private
    key material enters state. Set to null to skip the association.
  EOT
  type        = string
  default     = null
  nullable    = true
}

variable "target_port" {
  description = "TCP port the private target listens on and the port published as an application segment."
  type        = number
  default     = 3000

  validation {
    condition     = var.target_port > 0 && var.target_port <= 65535
    error_message = "target_port must be a valid TCP port."
  }
}

variable "tags" {
  description = "Tags applied to the resources in this module."
  type        = map(string)
  default     = {}
}
