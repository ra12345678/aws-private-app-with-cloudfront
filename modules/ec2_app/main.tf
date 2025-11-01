data "aws_ami" "selected" {
  most_recent = false

  filter {
    name   = "image-id"
    values = ["ami-0bdd88bd06d16ba03"]
  }
}

locals {
  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

if command -v dnf >/dev/null 2>&1; then
  dnf -y update
  dnf -y install java-17-amazon-corretto-headless
else
  yum -y update
  amazon-linux-extras enable corretto17 || true
  yum -y install java-17-amazon-corretto-headless
fi

JAVA_BIN="$(readlink -f "$(command -v java)")"
JAVA_HOME="$${JAVA_BIN%/bin/java}"

echo "JAVA_HOME=$${JAVA_HOME}" >> /etc/environment
echo "export JAVA_HOME=$${JAVA_HOME}" > /etc/profile.d/java.sh
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile.d/java.sh
chmod +x /etc/profile.d/java.sh
EOF
}

locals {
  # take first 2 subnets (length can be unknown; keys below are still static)
  app_subnets     = slice(var.app_subnet_ids, 0, 2)
  app_subnet_map  = { for idx, id in local.app_subnets : format("az%02d", idx + 1) => id }
}

resource "aws_instance" "app" {
  for_each               = local.app_subnet_map
  ami                    = data.aws_ami.selected.id
  instance_type          = var.instance_type
  subnet_id              = each.value
  vpc_security_group_ids = [var.sg_app_id]
  key_name               = var.key_name
  user_data              = local.user_data
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "app-${each.key}" }
}

resource "aws_iam_role" "ssm" {
  name               = "ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm.name
}


