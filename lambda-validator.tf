resource "aws_lambda_function" "validator" {
  function_name = "json-schema-validator"
  role = aws_iam_role.validator_lambda.arn
  runtime = "python3.12"
  handler = "handler.lambda_handler"
  timeout = 30

  architectures = ["arm64"]   # ✅ important as needed by runtime Lambda

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  layers = [
    aws_lambda_layer_version.jsonschema_layer.arn
  ]

  environment {
    variables = {
      VALIDATED_BUCKET = aws_s3_bucket.validated.bucket
      REJECTED_BUCKET = aws_s3_bucket.rejected.bucket
      SCHEMA_REGISTRY = aws_schemas_registry.json_ingestion.name
    }
  }
}

resource "aws_lambda_layer_version" "jsonschema_layer" {
  layer_name          = "jsonschema-deps"
  description         = "jsonschema + native dependencies (rpds)"
  compatible_runtimes = ["python3.12"]

  filename         = "${path.module}/lambda-layer.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda-layer.zip")
}

resource "aws_iam_role_policy" "lambda_eventbridge_publish" {
  role = aws_iam_role.validator_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["events:PutEvents"]
      Resource = "*"
    }]
  })
}
