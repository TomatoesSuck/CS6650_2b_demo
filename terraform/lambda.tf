variable "lambda_execution_role_arn" {
  description = "Use your LabRole ARN"
  type        = string
}

locals {
  lambda_zip_path = "../src/lambda/build/lambda.zip"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/order-lambda-processor"
  retention_in_days = 7
}

resource "aws_lambda_function" "processor" {
  function_name    = "order-lambda-processor"
  role             = var.lambda_execution_role_arn
  handler          = "bootstrap"
  runtime          = "provided.al2"
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  memory_size      = 512
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT = "production"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.sns.topic_arn
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = module.sns.topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.processor.arn
}

