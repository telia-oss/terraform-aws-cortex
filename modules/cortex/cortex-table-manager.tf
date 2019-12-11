module "cortex_table_manager" {
  source                            = "github.com/telia-oss/terraform-aws-ecs-fargate.git?ref=add-no-load-balancer-support"
  name_prefix                       = "cortex-table-manager"
  vpc_id                            = var.vpc_id
  cluster_id                        = aws_ecs_cluster.cortex.id
  private_subnet_ids                = var.private_subnet_ids
  desired_count                     = 1
  task_container_image              = var.cortex_image
  task_container_port               = 80
  task_definition_cpu               = 512
  task_definition_memory            = 1024
  health_check_grace_period_seconds = 10
  service_registry_arn              = aws_service_discovery_service.cortex_table_manager.arn
  tags                              = var.tags

  task_container_command = [
    "-target=table-manager",
    "-log.level=debug",
    "-server.http-listen-port=80",
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
  ]

  health_check = {
    port    = "traffic-port"
    path    = "/ready"
    matcher = 204
  }
}

resource "aws_service_discovery_service" "cortex_table_manager" {
  name = "cortex-table-manager"

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

resource "aws_security_group_rule" "to_table_manager_from" {
  for_each = {
    # ssh = module.ssh.service_sg_id,
    # consul     = var.consul_service_sg_id,
    # prometheus = var.prometheus_service_sg_id,
  }

  security_group_id        = module.cortex_table_manager.service_sg_id
  source_security_group_id = each.value

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
}

resource "aws_iam_role_policy_attachment" "cortex_table_manager_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = module.cortex_table_manager.task_role_name
}
