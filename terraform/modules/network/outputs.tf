########################################
# Network module outputs
# Expose values needed by the root or ECS module:
# - Subnet IDs (for wiring tasks/ALB)
# - ALB DNS name (for testing/ingress)
# - Target Group ARN (to attach ECS service)
# - Security Group IDs (attach to ECS tasks, reference ALB SG)
########################################

# IDs of all subnets in the chosen VPC
# Useful for passing into ECS service/network configuration.
output "subnet_ids" {
  description = "IDs of the default VPC subnets"
  value       = data.aws_subnets.default.ids
}

# Public DNS name of the Application Load Balancer
# Use this to access your service via http://<alb_dns_name>
output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

# ARN of the ALB (sometimes useful for alarms, logs, or tagging)
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

# Target Group ARN to be referenced by the ECS service's load_balancer block
output "target_group_arn" {
  description = "Target Group ARN used by the ECS service"
  value       = aws_lb_target_group.this.arn
}

# Security Group ID attached to the ALB (ingress :80 from Internet)
output "alb_sg_id" {
  description = "Security Group ID for the ALB (ingress :80)"
  value       = aws_security_group.alb_sg.id
}

# Security Group ID attached to ECS tasks (ingress from ALB on container port)
output "service_sg_id" {
  description = "Security Group ID for ECS tasks (ingress from ALB)"
  value       = aws_security_group.service_sg.id
}
