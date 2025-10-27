resource "aws_sqs_queue" "orders_queue" {
  name                      = "order-processing-queue"
  visibility_timeout_seconds = 30      # 默认
  message_retention_seconds  = 345600  # 4 天
  receive_wait_time_seconds  = 20      # 长轮询
}

resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.orders_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowSNSToSend",
      Effect    = "Allow",
      Principal = "*",
      Action    = "SQS:SendMessage",
      Resource  = aws_sqs_queue.orders_queue.arn,
      Condition = {
        ArnEquals = { "aws:SourceArn" = var.allowed_sns_topic_arn }
      }
    }]
  })
}