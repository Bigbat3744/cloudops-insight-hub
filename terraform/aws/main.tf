# terraform/aws/main.tf

provider "aws" {
  region = "us-east-1"
}

# DynamoDB table for usage data
resource "aws_dynamodb_table" "usage_table" {
  name         = "cloudops-usage"
  billing_mode = "PAY_PER_REQUEST" # No capacity planning needed
  hash_key     = "pk"              # Partition key
  range_key    = "sk"              # Sort key

  attribute {
    name = "pk"
    type = "S" # String
  }

  attribute {
    name = "sk"
    type = "S" # String
  }

  # Optional: Auto-delete old data to save costs
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Optional: Point-in-time recovery (good for production)
  point_in_time_recovery {
    enabled = false # Set to true for production
  }

  tags = {
    Project     = "CloudOps Insight Hub"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "cloudops-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM role policy for Lambda 
resource "aws_iam_role_policy" "lambda_cost_explorer" {
  name = "lambda-cost-explorer-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast"
        ]
        Resource = "*"
      }
    ]
  })
}

# lambda_cost_explorer policy
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.usage_table.arn,
          "${aws_dynamodb_table.usage_table.arn}/index/*"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for CloudWatch + DynamoDB
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "billing_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "logs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "collector" {
  function_name = "cloudops-aws-collector"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  filename      = "lambda_function.zip"
}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "cloudops-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.collector.arn
}

resource "aws_apigatewayv2_route" "usage_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /usage"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

# EventBridge Rule - Trigger Lambda daily at 9 AM UTC
resource "aws_cloudwatch_event_rule" "daily_cost_collection" {
  name                = "cloudops-daily-cost-collection"
  description         = "Trigger cost collection Lambda daily at 9 AM UTC"
  schedule_expression = "cron(0 9 * * ? *)" # 9 AM UTC daily

  event_pattern = jsonencode({
    source      = ["manual.test"]
    detail-type = ["Scheduled Event"]

  })
}

# EventBridge Target - Point to Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_cost_collection.name
  target_id = "CloudOpsCostCollectorLambda"
  arn       = aws_lambda_function.collector.arn

  # Pass default parameters (7 days, store=true)
  input = jsonencode({
    queryStringParameters = {
      days  = "7"
      store = "true"
    }
  })
}

# Lambda Permission - Allow EventBridge to invoke
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cost_collection.arn
}

# Output the EventBridge rule name
output "eventbridge_rule_name" {
  value       = aws_cloudwatch_event_rule.daily_cost_collection.name
  description = "Name of the EventBridge rule for daily cost collection"
}
