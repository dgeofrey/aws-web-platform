output "state_bucket" {
  description = "Name of the state bucket. Use it as `bucket` in each environment's backend.hcl."
  value       = aws_s3_bucket.state.bucket
}

output "region" {
  description = "Region of the state bucket."
  value       = var.region
}
