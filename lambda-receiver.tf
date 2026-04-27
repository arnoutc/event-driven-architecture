resource "aws_lambda_function" "api_receiver" {
  function_name = "validated-event-receiver"
  runtime = "python3.12"
  handler = "receiver.lambda_handler"
  role = aws_iam_role.lambda_basic.arn
  
  filename = "receiver.zip"
  source_code_hash = filebase64sha256("receiver.zip")
}

resource "aws_iam_role" "lambda_basic" {
  name = "lambda-basic-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com"},
        Action = "sts:AssumeRole"
      }]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  role = aws_iam_role.lambda_basic.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }]
  } )
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_receiver.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.receiver_api.execution_arn}/*/*"
}