########################################
# ECS module variables (formatted properly)
########################################

variable "service_name" {
  type        = string
  description = "ECS service and resource name prefix"
}

variable "image" {
  type        = string
  description = "Full image URL incl. tag, e.g., <acct>.dkr.ecr.<region>.amazonaws.com/repo:tag"
}

variable "container_port" {
  type        = number
  default     = 8080
  description = "Container port exposed by the ECS task and ALB Target Group"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets where ECS Fargate tasks run"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security Groups attached to ECS tasks (should include network.service_sg_id)"
}

variable "execution_role_arn" {
  type        = string
  description = "IAM role for ECS task execution (pull image, write logs)"
}

variable "task_role_arn" {
  type        = string
  description = "IAM role used by the ECS container application itself"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name for container logs"
}

variable "region" {
  type        = string
  description = "AWS region (used for CloudWatch logging configuration)"
}

variable "target_group_arn" {
  type        = string
  description = "ARN of the ALB Target Group to attach ECS Service to"
}

########################################
# Auto Scaling parameters
########################################

variable "min_capacity" {
  type        = number
  default     = 2
  description = "Minimum number of running tasks (initial desired count)"
}

variable "max_capacity" {
  type        = number
  default     = 4
  description = "Maximum number of running tasks allowed by Auto Scaling"
}

variable "cpu_target" {
  type        = number
  default     = 70
  description = "Average CPU utilization target for scaling policy"
}

variable "scale_out_cooldown" {
  type        = number
  default     = 300
  description = "Cooldown (seconds) before another scale-out event can occur"
}

variable "scale_in_cooldown" {
  type        = number
  default     = 300
  description = "Cooldown (seconds) before another scale-in event can occur"
}

########################################
# Task sizing
########################################

variable "cpu" {
  type        = number
  default     = 256
  description = "vCPU units allocated to each Fargate task (e.g., 256 = 0.25 vCPU)"
}

variable "memory" {
  type        = number
  default     = 512
  description = "Memory (MiB) allocated to each Fargate task"
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Attach a public IP to Fargate task ENI so it can reach the Internet"
}


variable "sns_topic_arn" { type = string }
variable "aws_region"     { type = string } # 没有就加