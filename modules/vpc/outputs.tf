output "vpc_id"             { value = aws_vpc.this.id }
output "public_subnet_ids"  { value = [for s in aws_subnet.public : s.id] }
output "app_subnet_ids"     { value = [for s in aws_subnet.app : s.id] }
output "db_subnet_ids"      { value = [for s in aws_subnet.db : s.id] }
output "app_route_table_ids"{ value = [aws_route_table.app.id] } # single RT