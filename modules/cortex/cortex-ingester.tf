module "cortex_ingester" {
  source = "git@github.com:telia-oss/terraform-aws-ecs.git//modules/service?ref=enable-network-mode-awsvpc"

  name_prefix                       = "cortex-ingester"
  vpc_id                            = var.vpc_id
  private_subnet_ids                = var.private_subnet_ids
  cluster_id                        = module.cluster.id
  cluster_role_name                 = module.cluster.role_name
  desired_count                     = 3
  task_container_image              = var.cortex_image
  task_container_cpu                = 2048
  task_container_memory_reservation = 959
  placement_constraint              = "distinctInstance"
  stop_timeout                      = 2400
  health_check_grace_period         = 30
  service_registry_arn              = aws_service_discovery_service.cortex_ingester.arn
  tags                              = var.tags

  target = {
    protocol      = "HTTP"
    port          = 80
    load_balancer = module.alb_cortex.arn
  }

  task_container_command = [
    "-target=ingester",
    "-ingester.claim-on-rollout=true",
    "-distributor.replication-factor=3",
    "-consul.hostname=consul.cluster.service.local:8500",
    "-chunk.storage-client=aws-dynamo",
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
    "-log.level=debug",
  ]

  health_check = {
    port    = "traffic-port"
    path    = "/ready"
    matcher = 204
  }
}

resource "aws_service_discovery_service" "cortex_ingester" {
  name = "cortex-ingester"

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

resource "aws_lb_listener_rule" "cortex_ingester" {
  listener_arn = aws_lb_listener.cortex_http.arn
  priority     = 116

  action {
    type             = "forward"
    target_group_arn = module.cortex_ingester.target_group_arn
  }

  condition {
    field  = "host-header"
    values = [aws_route53_record.cortex_dns_record["ingester"].name]
  }
}

resource "aws_security_group_rule" "cortex_ingester_lb" {
  security_group_id        = module.cluster.security_group_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = module.alb_cortex.security_group_id
}

resource "aws_iam_role_policy_attachment" "cortex_ingester_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = module.cortex_ingester.task_role_name
}

#####################################################################
########################## Security Groups ##########################
#####################################################################

resource "aws_security_group_rule" "from_cluster_to" {
  for_each = {
    # consul      = var.consul_service_sg_id,
    distributor = module.cortex_distributor.service_sg_id,
  }

  security_group_id        = each.value
  source_security_group_id = module.cluster.security_group_id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}

resource "aws_security_group_rule" "to_cluster_from" {
  for_each = {
    self        = module.cluster.security_group_id
    distributor = module.cortex_distributor.service_sg_id,
    querier     = module.cortex_querier.service_sg_id,
    # consul      = var.consul_service_sg_id,
    # prometheus  = var.prometheus_service_sg_id
  }

  security_group_id        = module.cluster.security_group_id
  source_security_group_id = each.value

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}
