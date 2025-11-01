# Interface endpoints
locals {
  services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

resource "aws_security_group" "endpoints" {
  name        = "endpoints-sg"
  description = "Allow HTTPS to interface endpoints from VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # tighten as needed
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "endpoints-sg"
  }
}

resource "aws_vpc_endpoint" "iface" {
  for_each            = toset(local.services)
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoints.id]
  subnet_ids          = var.app_subnet_ids
  private_dns_enabled = true
}

data "aws_region" "current" {}

# S3 gateway endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.rt_private_ids
}
