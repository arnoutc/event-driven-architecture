resource "aws_iam_role" "validator_lambda" {
  name = "json-validator-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "validator_policy" {
  role = aws_iam_role.validator_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read uploaded JSON
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.ingestion.arn}/*"
      },

      # Write validated / rejected files
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = [
          "${aws_s3_bucket.validated.arn}/*",
          "${aws_s3_bucket.rejected.arn}/*"
        ]
      },

      # Fetch schemas from EventBridge Registry
      {
        Effect = "Allow"
        Action = [
          "schemas:DescribeSchema",
          "schemas:GetDiscoveredSchema"
        ]
        Resource = "*"
      },

      # Logging
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
