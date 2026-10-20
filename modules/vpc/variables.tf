variable "name" {
  description = "Name prefix for all VPC resources."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR for the VPC. Subnets are carved out as /24s."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && tonumber(split("/", var.cidr_block)[1]) <= 16
    error_message = "cidr_block must be a valid IPv4 CIDR of /16 or larger."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to span (one public and one private subnet per AZ)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "enable_nat_gateway" {
  description = "Create a single NAT gateway so private subnets have outbound internet access."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
