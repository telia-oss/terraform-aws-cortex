module "cortex_querier" {
  source                            = "telia-oss/ecs-fargate/aws"
  version                           = "3.2.0"
  name_prefix                       = "cortex-querier"
  vpc_id                            = var.vpc_id
  cluster_id                        = aws_ecs_cluster.cortex.id
  private_subnet_ids                = var.private_subnet_ids
  desired_count                     = 1
  task_container_image              = var.cortex_image
  task_container_port               = 80
  task_definition_cpu               = 1024
  task_definition_memory            = 2048
  health_check_grace_period_seconds = 30
  service_registry_arn              = aws_service_discovery_service.cortex_querier.arn
  lb_arn                            = module.alb_cortex.arn
  tags                              = var.tags

  task_container_command = [
    "-target=querier",
    "-distributor.replication-factor=3",
    "-consul.hostname=consul.cluster.service.local:8500",
    "-chunk.storage-client=aws-dynamo",
    "-querier.frontend-address=cortex-query-frontend.cluster.service.local:9095",
    "-dynamodb.url=dynamodb://${data.aws_region.current.name}/",
    "-dynamodb.use-periodic-tables=true",
    "-dynamodb.periodic-table.prefix=cortex_index_",
    "-dynamodb.periodic-table.from=2019-11-01",
    "-dynamodb.periodic-table.inactive-enable-ondemand-throughput-mode=true",
    "-dynamodb.periodic-table.tag=product_area=cortex",
    "-dynamodb.chunk-table.from=2019-11-01",
    "-dynamodb.chunk-table.prefix=cortex_data_",
    "-dynamodb.chunk-table.inactive-enable-ondemand-throughput-mode=true",
    "-dynamodb.chunk-table.tag=product_area=cortex",
    "-auth.enabled=false", # Disables multi-tenancy, remove when X-Org-Id header is set.
  ]

  health_check = {
    port    = "traffic-port"
    path    = "/"
    matcher = 404
  }
}

resource "aws_lb_listener_rule" "cortex_querier" {
  listener_arn = aws_lb_listener.cortex_http.arn
  priority     = 113

  action {
    type             = "forward"
    target_group_arn = module.cortex_querier.target_group_arn
  }

  condition {
    field  = "host-header"
    values = [aws_route53_record.cortex_dns_record["querier"].name]
  }
}

resource "aws_security_group_rule" "cortex_querier_lb" {
  security_group_id        = module.cortex_querier.service_sg_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = module.alb_cortex.security_group_id
}

resource "aws_service_discovery_service" "cortex_querier" {
  name = "cortex-querier"

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

resource "aws_iam_role_policy_attachment" "cortex_querier_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = module.cortex_querier.task_role_name
}

#####################################################################
########################## Security Groups ##########################
#####################################################################

resource "aws_security_group_rule" "from_querier_to" {
  for_each = {
    # consul = var.consul_service_sg_id,
  }

  security_group_id        = each.value
  source_security_group_id = module.cortex_querier.service_sg_id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}

resource "aws_security_group_rule" "to_querier_from" {
  for_each = {
    self = module.cortex_querier.service_sg_id,
    # consul     = var.consul_service_sg_id,
    # prometheus = var.prometheus_service_sg_id
  }

  security_group_id        = module.cortex_querier.service_sg_id
  source_security_group_id = each.value

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}
