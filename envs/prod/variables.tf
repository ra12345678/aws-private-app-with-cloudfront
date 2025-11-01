variable "region" { type = string }
variable "project" { type = string }
variable "vpc_cidr" { type = string }
variable "public_cidrs" { type = list(string) } # 2 AZs
variable "app_cidrs" { type = list(string) }    # 2 AZs
variable "db_cidrs" { type = list(string) }     # 2 AZs

# EC2 + RDS
variable "instance_type" { type = string }
variable "key_name" { type = string }      # optional
variable "db_engine" { type = string }     # "mysql"
variable "db_engine_ver" { type = string } # e.g., "8.0"
variable "db_username" { type = string }
variable "db_password" { type = string } # store securely (e.g., SSM)
variable "db_name" { type = string }

# CloudFront + S3
variable "ui_bucket_name" { type = string }
variable "domain_name" { type = string }  # optional (CF alternate domain)
variable "acm_cert_arn" { type = string } # in us-east-1 if using custom domain
