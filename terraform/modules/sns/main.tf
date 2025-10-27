resource "aws_sns_topic" "order_events" {
  name = "order-processing-events"
}

# SNS → SQS 订阅
resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = var.sqs_queue_arn           # 👈 注意：这里必须是 Queue ARN，不是 URL
}