# 原有信息
output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}


###############################################
# ECS Module Outputs  —  用于其他模块（Worker、API）
###############################################

# ✅ 获取当前 AWS 账户信息（用于拼 LabRole）
data "aws_caller_identity" "current" {}

# ✅ 或直接引用 LabRole（推荐：AWS Academy 环境）
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}


# ✅ 新增：Cluster ARN（Worker 模块部署需要）
output "cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

# --------------------------
# 任务执行角色（Execution + Worker Role）
# --------------------------

# ✅ 使用现有 AWS Academy LabRole 作为执行角色
output "task_execution_role_arn" {
  description = "ECS Execution Role for pulling images and writing logs (LabRole)"
  value       = data.aws_iam_role.lab_role.arn
}

# ✅ Worker 使用同样角色（访问 SQS、CloudWatch）
output "worker_task_role_arn" {
  description = "Worker Task Role (LabRole)"
  value       = data.aws_iam_role.lab_role.arn
}