variable "sqs_queue_name" {
  type = string
}

variable "worker_concurrency" {
  description = "Number of goroutines to process SQS messages concurrently"
  type        = number
  default     = 1
}