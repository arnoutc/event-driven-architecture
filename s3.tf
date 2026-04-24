resource "aws_s3_bucket" "ingestion" {
  bucket = "json-ingestion-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "validated" {
  bucket = "json-validated-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "rejected" {
  bucket = "json-rejected-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_notification" "eventbridge" {
  bucket = aws_s3_bucket.ingestion.id
}
