variable "app_subnet_ids" { type = list(string) }
variable "sg_app_id"      { type = string }
variable "instance_type"  { type = string }
variable "key_name" {
  type    = string
  default = null
}
variable "user_data_vars" { type = map(string) }