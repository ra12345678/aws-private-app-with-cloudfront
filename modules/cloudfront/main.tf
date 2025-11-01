# --- inputs this module expects ---
# variable "project" {}
# variable "s3_bucket_domain" {}
# variable "s3_bucket_arn" {}
# variable "s3_oac_id" {}
# variable "vpc_id" {}
# variable "alb_arn" {}
# variable "alb_sg_id" {}
# variable "domain_name" { default = null }
# variable "acm_cert_arn" { default = null }

# 1) VPC Origin that targets your **internal ALB**
# resource "aws_cloudfront_vpc_origin" "api" {
#   vpc_origin_endpoint_config {
#     name                   = "${var.project}-api-origin"
#     arn                    = var.alb_arn
#     http_port              = 80
#     https_port             = 8443
#     origin_protocol_policy = "https-only"

#     origin_ssl_protocols {
#       items    = ["TLSv1.2"]
#       quantity = 1
#     }
#   }
# }

resource "aws_cloudfront_vpc_origin" "api" {
  vpc_origin_endpoint_config {
    name                   = "api-internal-alb"          # any friendly name
    arn                    = var.alb_arn                 # e.g., aws_lb.api.arn
    http_port              = 80                          # ALB listener port
    origin_protocol_policy = "http-only"                 # CloudFront→origin over HTTP
    https_port             = 8443
    # NOTE: Some provider versions *incorrectly* require https fields even with http-only.
    # If you hit that, uncomment these 2 lines as a workaround (CF will still use HTTP):
    # https_port = 443
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  # Optional tags
  tags = {
    Name = "api-vpc-origin"
  }
}

data "aws_ec2_managed_prefix_list" "cf_origin_ipv4" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Allow HTTP 80 from CloudFront's VPC Origin SG to your ALB SG
resource "aws_security_group_rule" "allow_cf_to_alb_80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = var.alb_sg_id
  prefix_list_ids          = [data.aws_ec2_managed_prefix_list.cf_origin_ipv4.id]
  description              = "Allow CloudFront VPC Origin to ALB:80"
}

# 3) Distribution: S3 default; /api/* → VPC Origin
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
data "aws_cloudfront_cache_policy" "s3_ui_cache_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "s3_ui_host_header_only" {
  name = "Managed-HostHeaderOnly"
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  default_root_object = "index.html"
  comment         = "${var.project} UI+API"
  price_class     = "PriceClass_100"

  # Use top-level aliases list instead of a block
  aliases = var.domain_name != null ? [var.domain_name] : []

  # S3 (UI) origin with OAC
  origin {
    origin_id                = "s3-ui"
    domain_name              = var.s3_bucket_domain
    origin_access_control_id = var.s3_oac_id

    # Required placeholder with OAC
    s3_origin_config {
      origin_access_identity = ""
    }
  }

  # API origin via VPC Origin
  origin {
    origin_id   = "api-vpc-origin"
    domain_name = var.dns_name

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.api.id
  }
}

  default_cache_behavior {
    target_origin_id         = "s3-ui"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.s3_ui_cache_optimized.id
    # origin_request_policy_id = data.aws_cloudfront_origin_request_policy.s3_ui_host_header_only.id
  }

  ordered_cache_behavior {
    path_pattern             = "api/*" # no leading slash
    target_origin_id         = "api-vpc-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
    cached_methods           = ["GET","HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  # Single viewer_certificate block that works for both cases
  viewer_certificate {
    cloudfront_default_certificate = var.acm_cert_arn == null
    # Only used when you actually pass an ACM cert
    acm_certificate_arn      = var.acm_cert_arn
    ssl_support_method       = var.acm_cert_arn != null ? "sni-only" : null
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Bucket policy for OAC (uses the real distribution ARN)
data "aws_iam_policy_document" "s3_ui_policy" {
  statement {
    sid     = "AllowCloudFrontReadViaOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${var.s3_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ui" {
  bucket = replace(var.s3_bucket_arn, "arn:aws:s3:::", "")
  policy = data.aws_iam_policy_document.s3_ui_policy.json
}

output "distribution_id"  { value = aws_cloudfront_distribution.this.id }
output "distribution_arn" { value = aws_cloudfront_distribution.this.arn }
output "domain_name"      { value = aws_cloudfront_distribution.this.domain_name }
