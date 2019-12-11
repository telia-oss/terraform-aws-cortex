module "cortex_distributor" {
  source                            = "telia-oss/ecs-fargate/aws"
  version                           = "3.2.0"
  name_prefix                       = "cortex-distributor"
  vpc_id                            = var.vpc_id
  cluster_id                        = aws_ecs_cluster.cortex.id
  private_subnet_ids                = var.private_subnet_ids
  desired_count                     = 1
  task_container_image              = var.cortex_image
  task_container_port               = 80
  task_definition_cpu               = 1024
  task_definition_memory            = 2048
  health_check_grace_period_seconds = 30
  service_registry_arn              = aws_service_discovery_service.cortex_distributor.arn
  lb_arn                            = module.alb_cortex.arn
  tags                              = var.tags

  task_container_command = [
    "-target=distributor",
    "-consul.hostname=consul.cluster.service.local:8500",
    "-log.level=debug",
    "-distributor.replication-factor=3",
    "-auth.enabled=false", # Disables multi-tenancy, remove when X-Org-Id header is set.
  ]

  health_check = {
    port    = "traffic-port"
    path    = "/"
    matcher = 404
  }
}

resource "aws_lb_listener_rule" "cortex_distributor" {
  listener_arn = aws_lb_listener.cortex_http.arn
  priority     = 112

  # action {
  #   type = "authenticate-cognito"

  #   authenticate_cognito {
  #     user_pool_arn       = aws_cognito_user_pool.cpa.arn
  #     user_pool_client_id = aws_cognito_user_pool_client.cpa.id
  #     user_pool_domain    = aws_cognito_user_pool_domain.cpa.domain
  #   }
  # }

  action {
    type             = "forward"
    target_group_arn = module.cortex_distributor.target_group_arn
  }

  condition {
    field  = "host-header"
    values = [aws_route53_record.cortex_dns_record["distributor"].name]
  }
}

resource "aws_security_group_rule" "cortex_distributor_lb" {
  security_group_id        = module.cortex_distributor.service_sg_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = module.alb_cortex.security_group_id
}

resource "aws_service_discovery_service" "cortex_distributor" {
  name = "cortex-distributor"

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

resource "aws_security_group_rule" "cortex_distributor_to_self" {
  security_group_id = module.cortex_distributor.service_sg_id
  type              = "ingress"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  self              = true
}

# resource "aws_security_group_rule" "cortex_distributor_to_consul" {
#   security_group_id        = var.consul_service_sg_id
#   type                     = "ingress"
#   protocol                 = "all"
#   from_port                = 0
#   to_port                  = 0
#   source_security_group_id = module.cortex_distributor.service_sg_id
# }

# resource "aws_security_group_rule" "consul_to_cortex_distributor" {
#   security_group_id        = module.cortex_distributor.service_sg_id
#   type                     = "ingress"
#   protocol                 = "all"
#   from_port                = 0
#   to_port                  = 0
#   source_security_group_id = var.consul_service_sg_id
# }

# resource "aws_security_group_rule" "prometheus_to_cortex_distributor" {
#   security_group_id        = module.cortex_distributor.service_sg_id
#   type                     = "ingress"
#   protocol                 = "all"
#   from_port                = 0
#   to_port                  = 0
#   source_security_group_id = var.prometheus_service_sg_id
# }

resource "aws_security_group_rule" "distributor_ingress" {
  security_group_id = module.cortex_distributor.service_sg_id
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
