

resource "aws_db_subnet_group" "this" {
  name       = "rds-subnets"
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "this" {
  identifier              = "appdb"
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = var.username
  password                = var.password
  db_name                 = var.db_name
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [var.db_sg_id]
  publicly_accessible     = false
  skip_final_snapshot     = true
}


