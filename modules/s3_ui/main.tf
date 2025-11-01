
resource "aws_s3_bucket" "ui" {
  bucket        = var.bucket_name
  force_destroy = true
  tags = {
    Name = var.bucket_name
  }
}

# Strongly recommended for private buckets
resource "aws_s3_bucket_public_access_block" "ui" {
  bucket                  = aws_s3_bucket.ui.id
  block_public_acls       = true
  block_public_policy     = false # must be false so our bucket policy can apply
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OAC to be attached on the CloudFront origin (in your distribution resource)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for UI bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Your account (not strictly required here, but often useful)
data "aws_caller_identity" "current" {}

# Create a policy only if we have a real distribution ARN
locals {
  have_dist = try(trim(var.distribution_arn) != "", true)
}

# Bucket policy bound to the specific distribution via AWS:SourceArn (OAC pattern)
data "aws_iam_policy_document" "bucket_policy" {
  count = local.have_dist ? 1 : 0

  # Allow CloudFront (this distribution) to GET objects
  statement {
    sid     = "AllowCloudFrontReadViaOAC"
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.ui.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.distribution_arn]
    }
  }

  # (Optional) Allow CloudFront to List the bucket (useful if you serve directory indexes)
  # Remove this statement if you don't need listing.
  statement {
    sid     = "AllowCloudFrontListViaOAC"
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.ui.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ui" {
  count  = local.have_dist ? 1 : 0
  bucket = aws_s3_bucket.ui.id
  policy = data.aws_iam_policy_document.bucket_policy[0].json

  depends_on = [
    aws_s3_bucket_public_access_block.ui
  ]
}
