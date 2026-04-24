resource "aws_lambda_function" "validator" {
  function_name = "json-schema-validator"
  role = aws_iam_role.validator_lambda.arn
  runtime = "python3.13"
  handler = "handler.lambda_handler"
  timeout = 30

  filename = "lambda.zip"

  environment {
    variables = {
      VALIDATED_BUCKET = aws_s3_bucket.validated.bucket
      REJECTED_BUCKET = aws_s3_bucket.rejected.bucket
      SCHEMA_REGISTRY = aws_schemas_registry.json_ingestion.name
    }
  }
}