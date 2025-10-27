########################################
# Network Module (Complete, with safe defaults)
# Creates:
# - ALB Security Group (HTTP :80 from Internet)
# - Service Security Group (only allow ALB -> container_port)
# - Application Load Balancer (needs 2 subnets in different AZs)
# - Target Group (target_type=ip, health check /health)
# - HTTP Listener :80 forwarding to the Target Group
#
# Features:
# - Random suffix on names to avoid "already exists" collisions
# - Use two subnets in DIFFERENT AZs:
#     * If var.public_subnet_ids is provided → use those
#     * Else auto-discover from default VPC
# - Precondition to fail early if < 2 AZs available
########################################

# --- Discover default VPC & its subnets (used when public_subnet_ids not provided) ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Candidates: explicit input > auto-discovered
locals {
  candidate_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.default.ids
}

# Read AZ info of each candidate subnet
data "aws_subnet" "by_id" {
  for_each = toset(local.candidate_subnet_ids)
  id       = each.value
}

# Pick at most one subnet per AZ; then take first two AZs
locals {
  az_to_subnet = { for _, s in data.aws_subnet.by_id : s.availability_zone => s.id }
  az_subnets   = values(local.az_to_subnet)
  lb_subnets   = length(local.az_subnets) >= 2 ? slice(local.az_subnets, 0, 2) : local.az_subnets
}

# --- Random suffix to avoid name collisions ---
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

########################################
# Security Groups
########################################

# ALB SG: allow HTTP :80 from Internet
resource "aws_security_group" "alb_sg" {
  name        = "${substr(var.service_name, 0, 25)}-alb-sg-${random_string.suffix.result}"
  description = "Allow inbound HTTP (80) from Internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Service SG: ONLY allow traffic from ALB SG on container_port (default 8080)
resource "aws_security_group" "service_sg" {
  name        = "${substr(var.service_name, 0, 25)}-svc-sg-${random_string.suffix.result}"
  description = "Allow traffic from ALB to ECS tasks on container port"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "From ALB to container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# Load Balancer & Target Group
########################################

# ALB must have subnets in at least two different AZs
resource "aws_lb" "this" {
  # Keep name short; ALB name limit applies
  name               = "${substr(var.service_name, 0, 20)}-alb-${random_string.suffix.result}"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.lb_subnets

  lifecycle {
    precondition {
      condition     = length(local.lb_subnets) >= 2
      error_message = "ALB requires two subnets in different AZs. Pass public_subnet_ids with two subnets or create another subnet in a different AZ."
    }
  }
}

# Target Group for Fargate tasks (target_type=ip)
resource "aws_lb_target_group" "this" {
  # TG name limit is 32 chars → trim and add suffix
  name        = "${substr(var.service_name, 0, 20)}-tg-${random_string.suffix.result}"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"               # Required by Fargate
  port        = var.container_port # Must match container port (e.g., 8080)
  protocol    = "HTTP"

  health_check {
    protocol            = "HTTP"
    path                = "/health" # Your app must return 200 on this path
    interval            = 30        # 30 seconds
    healthy_threshold   = 2         # 2 consecutive successes → healthy
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# HTTP listener on :80 forwarding to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}