data "aws_ami" "ecs" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami*amazon-ecs-optimized"]
  }
}

module "cluster" {
  source  = "telia-oss/ecs/aws//modules/cluster"
  version = "2.0.0"

  name_prefix          = "cortex-ingester"
  vpc_id               = var.vpc_id
  subnet_ids           = var.private_subnet_ids
  instance_ami         = data.aws_ami.ecs.id
  instance_volume_size = 10
  instance_type        = "t3.micro"
  min_size             = 3
  max_size             = 6

  tags = {
    terraform = "True"
  }
}
