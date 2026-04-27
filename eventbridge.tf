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

# Destination API

resource "aws_cloudwatch_event_connection" "destination_api" {
  name               = "validated-events-api-connection"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "x-api-key"
      value = "dummy"
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "destination" {
  name = "validated-events-api"
  invocation_endpoint = "${aws_apigatewayv2_api.receiver_api.api_endpoint}/validated"
  http_method = "POST"
  connection_arn = aws_cloudwatch_event_connection.destination_api.arn
  invocation_rate_limit_per_second = 5
}

resource "aws_cloudwatch_event_rule" "validated_events" {
  name = "validated-json-events"

  event_pattern = jsonencode({
    source = ["com.example.validation"]
    detail-type = ["JsonValidated"]
  })
}

resource "aws_cloudwatch_event_target" "api_destination" {
  rule = aws_cloudwatch_event_rule.validated_events.name
  target_id = "validated-api-destination"
  arn = aws_cloudwatch_event_api_destination.destination.arn

  role_arn = aws_iam_role.eventbridge_api_destination_role.arn

  dead_letter_config {
    arn = aws_sqs_queue.api_destination_dlq.arn
  }

  retry_policy {
    maximum_retry_attempts = 5
    maximum_event_age_in_seconds = 3600
  }
}

resource "aws_iam_role" "eventbridge_api_destination_role" {
  name = "eventbridge-api-destination-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Effect = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action = "sts:AssumeRole"
      }]
  })
}

resource "aws_iam_role_policy" "eventbridge_api_destination_policy" {
  role = aws_iam_role.eventbridge_api_destination_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "events:InvokeApiDestination"
        ]
        Resource = aws_cloudwatch_event_api_destination.destination.arn
      },
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.api_destination_dlq.arn
      }
    ]
  })
}

