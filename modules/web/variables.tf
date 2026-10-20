variable "name" {
  description = "Name prefix for web tier resources. Kept short because ALB and target group names max out at 32 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,24}$", var.name))
    error_message = "name must be 1-24 characters: lowercase letters, numbers and hyphens."
  }
}

variable "vpc_id" {
  description = "VPC to deploy into."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the load balancer (at least two AZs)."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the application instances."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"
}

variable "ami_ssm_parameter" {
  description = "Public SSM parameter that resolves to the AMI ID, so the latest patched image is used without hardcoding IDs."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 10
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling group."
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling group."
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Average CPU utilisation (%) the target tracking policy aims to hold."
  type        = number
  default     = 50
}

variable "allowed_ingress_cidrs" {
  description = "CIDR ranges allowed to reach the load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, an HTTPS listener is created and HTTP redirects to HTTPS."
  type        = string
  default     = null
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the load balancer (recommended for production)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to all resources, including launched instances and volumes."
  type        = map(string)
  default     = {}
}
