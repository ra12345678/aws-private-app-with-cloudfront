output "bucket_arn"    { value = aws_s3_bucket.ui.arn }
output "bucket_domain" { value = aws_s3_bucket.ui.bucket_regional_domain_name }
output "oac_id"        { value = aws_cloudfront_origin_access_control.oac.id }

