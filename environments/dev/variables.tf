variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ca-central-1"
}

variable "project" {
  description = "Project name, used in resource names and tags."
  type        = string
  default     = "webplatform"
}

variable "environment" {
  description = "Environment name, used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span."
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway for private subnet egress. Required by the web tier, which installs packages at boot."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of application instances."
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Desired number of application instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of application instances."
  type        = number
  default     = 4
}
