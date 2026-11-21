output "api_url" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/usage"
}

output "function_name" {
  value = aws_lambda_function.collector.function_name
}

output "table_name" {
  value = aws_dynamodb_table.usage_table.name
}

output "schedule_rule_name" {
  value = aws_cloudwatch_event_rule.daily_cost_collection.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.collector.name
}

output "reader_function_name" {
  value = aws_lambda_function.reader.function_name
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/name/${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
