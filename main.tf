# Create an S3 bucket for storing the Excel files with a unique name
resource "aws_s3_bucket" "project_data_bucket" {
  bucket = "${var.s3_bucket_name}"
}

# Create a DynamoDB table for storing processed data
resource "aws_dynamodb_table" "project_data" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ProjectID"
  range_key      = "Timestamp"

  attribute {
    name = "ProjectID"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "S"
  }
}

# Create an IAM role for the Lambda function with the necessary trust policy
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Create an IAM policy for the Lambda function to allow it to interact with S3, DynamoDB, and CloudWatch Logs
resource "aws_iam_policy" "lambda_execution_policy" {
  name = "lambda_execution_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${aws_s3_bucket.project_data_bucket.bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.dynamodb_table_name}"
      }
    ]
  })
}

# Attach the IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}

# Create a Lambda function to process the Excel files
resource "aws_lambda_function" "process_excel" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime

  # Specify the S3 bucket and key where the deployment package is stored
  s3_bucket     = var.lambda_deployment_bucket
  s3_key        = var.lambda_deployment_key

  # Provide the hash of the deployment package to detect changes
  source_code_hash = filebase64sha256(var.lambda_deployment_package)

  # Set environment variables for the Lambda function
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.project_data.name
    }
  }

  # Ensure IAM role and policy attachment are created before the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution_policy_attachment
  ]
}

# Allow S3 to invoke the Lambda function when a new object is created
resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_excel.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.project_data_bucket.arn
}

# Configure the S3 bucket to trigger the Lambda function upon object creation
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.project_data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_excel.arn
    events              = ["s3:ObjectCreated:*"]
  }

  # Ensure Lambda permission is created before bucket notification
  depends_on = [
    aws_lambda_permission.allow_s3_invocation
  ]
}

# Create a CloudWatch Event Rule to trigger the Lambda function on a schedule (every day)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = var.cloudwatch_event_rule_name
  schedule_expression = var.cloudwatch_schedule_expression
}

# Add the Lambda function as a target for the CloudWatch Event Rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "LambdaFunctionSchedule"
  arn       = aws_lambda_function.process_excel.arn
}

# Allow CloudWatch Events to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_excel.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
