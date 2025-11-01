

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for the ALB"
  vpc_id      = var.vpc_id

  # Ingress will be attached separately via aws_security_group_rule
  # (e.g., from CloudFront or specific CIDRs)

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}


resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Security group for the application instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP from ALB subnet range"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # or your ALB subnet CIDRs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# -------------------------
# Database Security Group
# -------------------------
resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Security group for the database"
  vpc_id      = var.vpc_id

  # Outbound access (for monitoring, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# -------------------------
# Allow inbound MySQL traffic from App SG
# -------------------------
resource "aws_security_group_rule" "app_to_db_mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
  description              = "Allow MySQL from app to DB"
}



