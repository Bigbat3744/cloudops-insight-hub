data "archive_file" "collector" {
  type        = "zip"
  source_file = "${path.module}/../../backend/collectors/lambda_function.py"
  output_path = "${path.module}/build/collector.zip"
}

resource "aws_cloudwatch_log_group" "collector" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "collector" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.collector.output_path
  source_code_hash = data.archive_file.collector.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.usage_table.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.collector,
    aws_iam_role_policy.lambda_permissions,
  ]
}

data "archive_file" "reader" {
  type        = "zip"
  source_file = "${path.module}/../../backend/api/lambda_function.py"
  output_path = "${path.module}/build/reader.zip"
}

resource "aws_cloudwatch_log_group" "reader" {
  name              = "/aws/lambda/${var.reader_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "reader" {
  function_name    = var.reader_function_name
  role             = aws_iam_role.reader_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.reader.output_path
  source_code_hash = data.archive_file.reader.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.usage_table.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.reader,
    aws_iam_role_policy.reader_permissions,
  ]
}
