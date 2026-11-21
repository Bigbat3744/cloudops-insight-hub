data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid       = "ReadCostData"
    actions   = ["ce:GetCostAndUsage"]
    resources = ["*"]
  }

  statement {
    sid       = "WriteTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  statement {
    sid       = "WriteUsageTable"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.usage_table.arn]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${var.function_name}-least-privilege"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role" "reader_role" {
  name               = "${var.reader_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "reader_permissions" {
  statement {
    sid       = "ReadUsageTable"
    actions   = ["dynamodb:Query"]
    resources = [aws_dynamodb_table.usage_table.arn]
  }

  statement {
    sid       = "WriteTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.reader.arn}:*"]
  }
}

  
resource "aws_iam_role_policy" "reader_permissions" {
  name   = "${var.reader_function_name}-read-only"
  role   = aws_iam_role.reader_role.id
  policy = data.aws_iam_policy_document.reader_permissions.json 
}
