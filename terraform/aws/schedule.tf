resource "aws_cloudwatch_event_rule" "daily_cost_collection" {
  name                = "${var.project_name}-daily-collection"
  description         = "Collect AWS cost data daily"
  schedule_expression = var.collection_schedule
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_cost_collection.name
  target_id = "CostCollector"
  arn       = aws_lambda_function.collector.arn

  input = jsonencode({
    queryStringParameters = {
      days  = "7"
      store = "true"
    }
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cost_collection.arn
}
