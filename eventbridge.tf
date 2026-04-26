resource "aws_schemas_registry" "json_ingestion" {
  name        = "json-file-ingestion"
  description = "Schemas for JSON file ingestion events"
}

resource "aws_cloudwatch_event_rule" "json_created" {
  name        = "json-object-created"
  description = "Trigger on JSON uploads to ingestion build"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.ingestion.bucket]
      }
      object = {
        key: [{
          suffix: ".json"
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "validator" {
  rule = aws_cloudwatch_event_rule.json_created.name
  target_id = "json-validator"
  arn = aws_lambda_function.validator.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id = "AllowEventBridgeInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.json_created.arn
}
