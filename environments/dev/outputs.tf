output "app_url" {
  description = "URL of the application."
  value       = module.web.app_url
}

output "app_version" {
  description = "Content hash of the deployed application build."
  value       = module.web.app_version
}

output "autoscaling_group_name" {
  description = "Name of the application Auto Scaling group."
  value       = module.web.autoscaling_group_name
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "availability_zones" {
  description = "Availability Zones the VPC spans."
  value       = module.vpc.availability_zones
}
