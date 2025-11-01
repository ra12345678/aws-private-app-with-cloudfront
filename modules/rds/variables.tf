variable "vpc_id"         { type = string }
variable "db_subnet_ids"  { type = list(string) }
variable "db_sg_id"       { type = string }
variable "engine"         { type = string }      # "mysql"
variable "engine_version" { type = string }
variable "username"       { type = string }
variable "password"       { type = string }
variable "db_name"        { type = string }