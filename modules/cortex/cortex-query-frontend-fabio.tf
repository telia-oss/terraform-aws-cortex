locals {
  cortex_fabio_port = 9998
}

module "cortex_fabio" {
  source                            = "telia-oss/ecs-fargate/aws"
  version                           = "3.2.0"
  name_prefix                       = "cortex-fabio"
  vpc_id                            = var.vpc_id
  cluster_id                        = aws_ecs_cluster.cortex.id
  private_subnet_ids                = var.private_subnet_ids
  desired_count                     = 1
  task_container_image              = "fabiolb/fabio:latest"
  task_container_port               = local.cortex_fabio_port
  task_definition_cpu               = 512
  task_definition_memory            = 1024
  health_check_grace_period_seconds = 30
  service_registry_arn              = aws_service_discovery_service.cortex_fabio.arn
  lb_arn                            = module.alb_cortex.arn
  tags                              = var.tags

  task_container_command = [
    "-registry.consul.addr", "consul.cluster.service.local:8500",
  ]

  health_check = {
    port    = local.cortex_fabio_port
    path    = "/health"
    matcher = 200
  }
}

resource "aws_lb_listener_rule" "cortex_fabio" {
  listener_arn = aws_lb_listener.cortex_http.arn
  priority     = 115

  action {
    type             = "forward"
    target_group_arn = module.cortex_fabio.target_group_arn
  }

  condition {
    field  = "host-header"
    values = [aws_route53_record.cortex_dns_record["fabio"].name]
  }
}

resource "aws_security_group_rule" "cortex_fabio_lb" {
  security_group_id        = module.cortex_fabio.service_sg_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = local.cortex_fabio_port
  to_port                  = local.cortex_fabio_port
  source_security_group_id = module.alb_cortex.security_group_id
}

resource "aws_service_discovery_service" "cortex_fabio" {
  name = "cortex-fabio"

  dns_config {
    namespace_id = var.service_discovery_private_dns_namespace_id

    dns_records {
      ttl  = 10
      type = "SRV"
    }

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

#####################################################################
########################## Security Groups ##########################
#####################################################################

resource "aws_security_group_rule" "from_fabio_to" {
  for_each = {
    # consul  = var.consul_service_sg_id,
    querier = module.cortex_querier.service_sg_id,
  }

  security_group_id        = each.value
  source_security_group_id = module.cortex_fabio.service_sg_id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}

resource "aws_security_group_rule" "to_fabio_from" {
  for_each = {
    self = module.cortex_fabio.service_sg_id,
    # ssh  = module.ssh.service_sg_id,
    # consul     = var.consul_service_sg_id,
    # prometheus = var.prometheus_service_sg_id,
    # grafana    = var.grafana_service_sg_id,
  }

  security_group_id        = module.cortex_fabio.service_sg_id
  source_security_group_id = each.value

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}
