variable "project"           { type = string }
variable "s3_bucket_domain"  { type = string }
variable "s3_bucket_arn"     { type = string }
variable "s3_oac_id"         { type = string }

variable "vpc_id"            { type = string }
variable "alb_arn"           { type = string }
variable "alb_sg_id"         { type = string }

variable "domain_name"{ 
    type = string 
    default = null 
}
variable "acm_cert_arn"      { 
    type = string
    default = null 
}

variable "dns_name" {
  type = string
  default = null
}