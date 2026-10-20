output "alb_dns_name" {
  description = "DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "app_url" {
  description = "URL of the application."
  value       = "${local.https_enabled ? "https" : "http"}://${aws_lb.this.dns_name}"
}

output "alb_zone_id" {
  description = "Hosted zone ID of the load balancer, for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

output "autoscaling_group_name" {
  description = "Name of the application Auto Scaling group."
  value       = aws_autoscaling_group.app.name
}

output "app_security_group_id" {
  description = "Security group attached to the application instances."
  value       = aws_security_group.app.id
}
