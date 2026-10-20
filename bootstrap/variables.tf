variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "ca-central-1"
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep previous versions of state files before they expire."
  type        = number
  default     = 90
}
