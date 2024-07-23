variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "sam-automation-data-bucket"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "ProjectData"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "process_excel"
}

variable "lambda_handler" {
  description = "The handler for the Lambda function"
  type        = string
  default     = "index.lambda_handler"
}

variable "lambda_runtime" {
  description = "The runtime for the Lambda function"
  type        = string
  default     = "python3.8"
}

variable "cloudwatch_schedule_expression" {
  description = "The schedule expression for CloudWatch Event Rule"
  type        = string
  default     = "rate(1 day)"
}

variable "cloudwatch_event_rule_name" {
  description = "The name of the CloudWatch Event Rule"
  type        = string
  default     = "LambdaFunctionSchedule"
}

variable "lambda_deployment_bucket" {
  description = "The S3 bucket where the Lambda deployment package is stored"
  type        = string
  default     = "lambda-deployment-artifacts-eu-west-2"
}

variable "lambda_deployment_key" {
  description = "The S3 key for the Lambda deployment package"
  type        = string
  default     = "lambda_function.zip"
}

variable "lambda_deployment_package" {
  description = "The path to the Lambda deployment package"
  type        = string
  default     = "lambda_function.zip"
}
