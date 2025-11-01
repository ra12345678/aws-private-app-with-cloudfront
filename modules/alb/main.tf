variable "vpc_id"             { type = string }
variable "app_subnet_ids"     { type = list(string) }
variable "sg_alb_id"          { type = string }
variable "target_instance_ids"{ type = list(string) }
variable "target_port"        { type = number }
variable "health_check_path"  { type = string }

resource "aws_lb" "this" {
  name               = "alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.app_subnet_ids
}

resource "aws_lb_target_group" "tg" {
  name        = "app-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  health_check {
    path = var.health_check_path
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

locals {
  target_instance_map = {
    for idx, id in tolist(var.target_instance_ids) :
    format("ti%03d", idx) => id
  }
}
# Register EC2 instances
resource "aws_lb_target_group_attachment" "att" {
  for_each         = local.target_instance_map
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = each.value
  port             = var.target_port
}

output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns" { value = aws_lb.this.dns_name }
