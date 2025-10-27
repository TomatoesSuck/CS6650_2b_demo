########################################
# Network module variables
# These variables control how your ALB and ECS network resources are created.
# - service_name: base name prefix for ALB, Target Group, and Security Groups
# - container_port: container port exposed to the ALB (default 8080)
# - cidr_blocks: which IP ranges are allowed to access the ALB (default 0.0.0.0/0)
########################################

# Prefix used in naming AWS resources (e.g., ALB, Target Group, Security Groups)
# Example: if service_name = "estore", ALB becomes "estore-alb"
variable "service_name" {
  description = "Base name prefix for ALB, Target Group, and Security Groups"
  type        = string
}

# Port number on which the ECS container listens (e.g., 8080)
# This should match the container's exposed port and the ALB target group port.
variable "container_port" {
  description = "Port number exposed by ECS containers and registered to the ALB Target Group"
  type        = number
  default     = 8080
}

# Allowed IP ranges for accessing the ALB via HTTP (port 80)
# For public access, keep as 0.0.0.0/0.
# To restrict access (e.g., company VPN or VPC CIDR), replace with your subnet range.
variable "cidr_blocks" {
  description = "List of CIDR ranges allowed to access the ALB on port 80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


variable "public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Exactly two subnet IDs in different AZs for the ALB. If empty, the module will auto-discover from the default VPC."
}