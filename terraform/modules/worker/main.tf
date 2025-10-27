variable "cluster_arn" {}
variable "subnet_ids" {}
variable "security_group_ids" {}
variable "aws_region" {}
variable "sqs_queue_url" {}
variable "worker_image" {}
variable "task_execution_role_arn" {}
variable "task_role_arn" {}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "worker" {
  family                   = "order-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name       = "order-worker"
      image      = var.worker_image
      essential  = true

      # ✅ 用 entryPoint 替换镜像默认 ENTRYPOINT
      entryPoint = ["/app/worker"]  # 比 ["./worker"] 更保险
      command    = []

      environment = [
        { name = "AWS_REGION",         value = var.aws_region },
        { name = "SQS_QUEUE_URL",      value = var.sqs_queue_url },
        { name = "WORKER_CONCURRENCY", value = tostring(var.worker_concurrency) }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/order-worker",
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# --- ECS Service ---
resource "aws_ecs_service" "worker_service" {
  name            = "order-worker-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true
    security_groups  = var.security_group_ids
  }
}

# --- Auto Scaling Target ---
resource "aws_appautoscaling_target" "worker_scaling_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.worker_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# --- Auto Scaling Policy (基于 SQS 积压) ---
resource "aws_cloudwatch_metric_alarm" "queue_backlog_high" {
  alarm_name          = "WorkerQueueBacklogHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  dimensions = {
    QueueName = var.sqs_queue_name
  }
  alarm_actions = [aws_appautoscaling_policy.worker_scale_out.arn]
}

resource "aws_appautoscaling_policy" "worker_scale_out" {
  name               = "worker-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.worker_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.worker_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker_scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown        = 60
    step_adjustment {
      scaling_adjustment          = 2
      metric_interval_lower_bound = 0
    }
  }
}
