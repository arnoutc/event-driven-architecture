resource "aws_sqs_queue" "api_destination_dlq" {
    name = "validated-events-api-dlq"
    message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue_policy" "dlq_policy" {
  queue_url = aws_sqs_queue.api_destination_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "events.amazonaws.com"}
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.api_destination_dlq.arn
      }
    ]   
  })
}