# resource "aws_route53_record" "ssh_dns_record" {
#   zone_id         = var.public_route53_zone_id
#   name            = "ssh.${var.subdomain}"
#   type            = "A"
#   allow_overwrite = true

#   alias {
#     name                   = module.ssh_lb_external.dns_name
#     zone_id                = module.ssh_lb_external.zone_id
#     evaluate_target_health = false
#   }
# }

# module "ssh" {
#   # source                            = "../ecs-fargate-timeout"
#   source                            = "telia-oss/ecs-fargate/aws"
#   version                           = "3.2.0"
#   tags                              = var.tags
#   name_prefix                       = "cpa-ssh-service"
#   vpc_id                            = var.vpc_id
#   cluster_id                        = aws_ecs_cluster.cortex.id
#   private_subnet_ids                = var.private_subnet_ids
#   lb_arn                            = module.ssh_lb_external.arn
#   service_registry_arn              = aws_service_discovery_service.ssh.arn
#   desired_count                     = 1
#   task_container_protocol           = "TCP"
#   task_container_image              = "358107645737.dkr.ecr.eu-west-1.amazonaws.com/cpa-prometheus:ssh"
#   task_container_port               = 2222
#   task_definition_cpu               = 256
#   task_definition_memory            = 512
#   health_check_grace_period_seconds = 10
#   health_check = {
#     port     = "2222"
#     protocol = "TCP"
#   }
# }

# resource "aws_service_discovery_service" "ssh" {
#   name = "ssh"

#   dns_config {
#     namespace_id = var.service_discovery_private_dns_namespace_id

#     dns_records {
#       ttl  = 10
#       type = "SRV"
#     }

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }
# }

# module "ssh_lb_external" {
#   source      = "telia-oss/loadbalancer/aws"
#   version     = "3.0.0"
#   name_prefix = "${var.prefix}-ssh-external"
#   type        = "network"
#   internal    = "false"
#   vpc_id      = var.vpc_id
#   subnet_ids  = var.private_subnet_ids
#   tags        = var.tags
# }

# resource "aws_lb_listener" "ssh_tcp" {
#   load_balancer_arn = module.ssh_lb_external.arn
#   port              = "2222"
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = module.ssh.target_group_arn
#   }
# }

# resource "aws_security_group_rule" "ssh_ingress_2222" {
#   security_group_id = module.ssh.service_sg_id
#   type              = "ingress"
#   protocol          = "tcp"
#   from_port         = "2222"
#   to_port           = "2222"
#   cidr_blocks       = ["0.0.0.0/0"]
# }

# resource "aws_security_group_rule" "from_ssh_to" {
#   for_each = {
#     # consul        = var.consul_service_sg_id,
#     # prometheus    = var.prometheus_service_sg_id
#     cluster       = module.cluster.security_group_id
#     distributor   = module.cortex_distributor.service_sg_id,
#     querier       = module.cortex_querier.service_sg_id,
#     queryfrontend = module.cortex_query_frontend.service_sg_id,
#   }

#   security_group_id        = each.value
#   source_security_group_id = module.ssh.service_sg_id

#   type      = "ingress"
#   from_port = 0
#   to_port   = 0
#   protocol  = "all"
# }
