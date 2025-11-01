########################
# 1) Network (VPC, subnets, routes, NAT, IGW)
########################
module "vpc" {
  source       = "../../modules/vpc"
  project      = var.project
  vpc_cidr     = var.vpc_cidr
  public_cidrs = var.public_cidrs
  app_cidrs    = var.app_cidrs
  db_cidrs     = var.db_cidrs
}

########################
# 2) VPC Endpoints (SSM interfaces, S3 gateway)
########################
module "endpoints" {
  source         = "../../modules/endpoints"
  vpc_id         = module.vpc.vpc_id
  app_subnet_ids = module.vpc.app_subnet_ids
  rt_private_ids = module.vpc.app_route_table_ids
}

########################
# 3) Security Groups (ALB, EC2, RDS — minimal chain)
########################
module "security" {
  source = "../../modules/security"
  vpc_id = module.vpc.vpc_id
}

########################
# 4) RDS (private DB subnets, SG from module.security)
########################
module "rds" {
  source        = "../../modules/rds"
  vpc_id        = module.vpc.vpc_id
  db_subnet_ids = module.vpc.db_subnet_ids
  db_sg_id      = module.security.sg_db_id

  engine         = var.db_engine
  engine_version = var.db_engine_ver
  username       = var.db_username
  password       = var.db_password
  db_name        = var.db_name
}

########################
# 5) EC2 App (private app subnets, uses sg_app)
########################
module "ec2_app" {
  source         = "../../modules/ec2_app"
  app_subnet_ids = module.vpc.app_subnet_ids
  sg_app_id      = module.security.sg_app_id
  instance_type  = var.instance_type
  key_name       = var.key_name

  user_data_vars = {
    DB_URL  = "jdbc:mysql://${module.rds.db_endpoint}:3306/${var.db_name}?useSSL=false&allowPublicKeyRetrieval=true"
    DB_USER = var.db_username
    DB_PASS = var.db_password
    PORT    = "80"
  }
}

########################
# 6) Internal ALB (targets: EC2 instances; health: /health)
########################
module "alb" {
  source              = "../../modules/alb"
  vpc_id              = module.vpc.vpc_id
  app_subnet_ids      = module.vpc.app_subnet_ids
  sg_alb_id           = module.security.sg_alb_id
  target_instance_ids = module.ec2_app.instance_ids
  target_port         = 80
  health_check_path   = "/health"
}

########################
# 7) S3 (UI) with OAC
########################
module "s3_ui" {
  source      = "../../modules/s3_ui"
  bucket_name = var.ui_bucket_name
  distribution_arn = module.cloudfront.distribution_arn
}

########################
# 8) CloudFront (S3 OAC + ALB origin)
########################
module "cloudfront" {
  source  = "../../modules/cloudfront"
  project = var.project

  # S3 (UI)
  s3_bucket_domain = module.s3_ui.bucket_domain
  s3_bucket_arn    = module.s3_ui.bucket_arn
  s3_oac_id        = module.s3_ui.oac_id

  # ALB (API) — pass ARN; module should resolve DNS and use custom_origin_config
  vpc_id    = module.vpc.vpc_id
  alb_arn   = module.alb.alb_arn
  alb_sg_id = module.security.sg_alb_id
  dns_name = module.alb.alb_dns

  # Optional custom domain
  domain_name  = var.domain_name
  acm_cert_arn = var.acm_cert_arn
}
