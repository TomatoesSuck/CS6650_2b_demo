########################################
# Root Module
# Wires together:
# - network  : ALB + Target Group (ip) + Security Groups
# - ecr      : ECR repo (for image)
# - logging  : CloudWatch Log Group
# - ecs      : ECS Fargate Service behind ALB with Auto Scaling
# - docker   : Build & push image to ECR (provider config lives in provider.tf)
########################################


module "sqs" {
  source = "./modules/sqs"
  allowed_sns_topic_arn = module.sns.topic_arn   # 👈 把 SNS ARN 传给 SQS 策略
}


module "sns" {
  source        = "./modules/sns"
  sqs_queue_arn = module.sqs.queue_arn      # 👈 把 SQS ARN 传给 SNS 订阅
}

module "worker" {
  source = "./modules/worker"

  cluster_arn             = module.ecs.cluster_arn
  subnet_ids              = module.network.subnet_ids
  security_group_ids      = [module.network.service_sg_id]
  aws_region              = var.aws_region
  sqs_queue_url  = module.sqs.queue_url
  sqs_queue_name = module.sqs.queue_name
  worker_image  = "${module.ecr.repository_url}:latest"
  task_execution_role_arn = module.ecs.task_execution_role_arn
  task_role_arn           = module.ecs.worker_task_role_arn
  worker_concurrency = 180   # 5 / 20 / 100
}

############################
# Network (ALB + TG + SGs)
############################
module "network" {
  source = "./modules/network"

  # Name prefix for ALB / Target Group / Security Groups
  service_name = var.service_name

  # Must match the container port exposed by your app
  container_port = var.container_port

  public_subnet_ids = [
    "subnet-026547752d0fd146d", # us-west-2a
    "subnet-017391497517cfdfc", # us-west-2b
  ]
}

############################
# ECR Repository
############################
module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

############################
# CloudWatch Logging
############################
module "logging" {
  source            = "./modules/logging"
  service_name      = var.service_name
  retention_in_days = var.log_retention_days
}

############################
# IAM Roles (reuse LabRole)
############################
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

############################
# ECS (Fargate + ALB + Auto Scaling)
############################
module "ecs" {
  source = "./modules/ecs"
  sns_topic_arn = module.sns.topic_arn
  aws_region    = var.aws_region
  service_name   = var.service_name
  image          = "${module.ecr.repository_url}:latest"
  container_port = var.container_port

  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.service_sg_id]

  execution_role_arn = data.aws_iam_role.lab_role.arn
  task_role_arn      = data.aws_iam_role.lab_role.arn

  log_group_name = module.logging.log_group_name
  region         = var.aws_region

  target_group_arn = module.network.target_group_arn

  min_capacity       = 2
  max_capacity       = 4
  cpu_target         = 70
  scale_out_cooldown = 300
  scale_in_cooldown  = 300
  assign_public_ip   = true
}

########################################
# Docker build & push to ECR
# Provider credentials & registry_auth are defined in provider.tf
########################################
resource "docker_image" "app" {
  # Build the image and tag it with the ECR repo URL + :latest
  name = "${module.ecr.repository_url}:latest"

  build {
    context = "../src" # relative path from terraform/ to src/
    # Dockerfile defaults to "Dockerfile" inside the context
  }
}

resource "docker_registry_image" "app" {
  # Push the built :latest image to ECR
  name = docker_image.app.name
}

############################
# Useful Outputs
############################
output "alb_dns_name" {
  description = "Public DNS name of the ALB (visit http://<alb_dns_name>/health)"
  value       = module.network.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL where the image is pushed"
  value       = module.ecr.repository_url
}


