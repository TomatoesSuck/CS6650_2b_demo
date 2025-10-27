output "queue_url" {
  description = "URL of the order-processing SQS queue"
  value       = aws_sqs_queue.orders_queue.id
}

output "queue_arn" {
  description = "ARN of the SQS queue (for SNS subscription)"
  value       = aws_sqs_queue.orders_queue.arn
}
output "queue_name" {
  value = aws_sqs_queue.orders_queue.name
}
