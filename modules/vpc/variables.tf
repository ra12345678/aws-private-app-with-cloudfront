variable "project"      { type = string }
variable "vpc_cidr"     { type = string }
variable "public_cidrs" { type = list(string) }
variable "app_cidrs"    { type = list(string) }
variable "db_cidrs"     { type = list(string) }
