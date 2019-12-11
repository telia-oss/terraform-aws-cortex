provider "aws" {
  region = "eu-west-1"
}

data "aws_region" "current" {}

resource "aws_ecs_cluster" "cortex" {
  name = "cortex"
  tags = var.tags
}

# ------------------------------------------------------------------------------
# Route 53
# ------------------------------------------------------------------------------
resource "aws_route53_record" "cortex_dns_record" {
  for_each = {
    distributor    = "cortex-distributor"
    ingester       = "cortex-ingester"
    querier        = "cortex-querier"
    query-frontend = "cortex-query-frontend"
    fabio          = "fabio"
  }

  name = "${each.value}.${var.subdomain}"
  #  name            = "cortex.${var.subdomain}"
  zone_id         = var.public_route53_zone_id
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = module.alb_cortex.dns_name
    zone_id                = module.alb_cortex.zone_id
    evaluate_target_health = false
  }
}

# # ------------------------------------------------------------------------------
# # Amazon Certificate Manager
# # ------------------------------------------------------------------------------
# resource "aws_acm_certificate" "cert_cortex" {
#   domain_name       = aws_route53_record.cortex_dns_record.name
#   validation_method = "DNS"
#   tags              = var.tags

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_route53_record" "cert_validation_cortex" {
#   zone_id = var.public_route53_zone_id
#   name    = aws_acm_certificate.cert_cortex.domain_validation_options[0].resource_record_name
#   type    = aws_acm_certificate.cert_cortex.domain_validation_options[0].resource_record_type
#   ttl     = 300

#   records = [
#     aws_acm_certificate.cert_cortex.domain_validation_options[0].resource_record_value,
#   ]
# }

# resource "aws_acm_certificate_validation" "cert_cortex" {
#   certificate_arn = aws_acm_certificate.cert_cortex.arn

#   validation_record_fqdns = [
#     aws_route53_record.cert_validation_cortex.fqdn,
#   ]
# }

# ------------------------------------------------------------------------------
# Create the cortex ALB
# ------------------------------------------------------------------------------
module "alb_cortex" {
  source      = "telia-oss/loadbalancer/aws"
  version     = "3.0.0"
  name_prefix = "${var.prefix}-cortex"
  type        = "application"
  internal    = "false"
  vpc_id      = var.vpc_id
  subnet_ids  = var.public_subnet_ids
  tags        = var.tags
}

# ------------------------------------------------------------------------------
# Create cortex LB default listener and open ingress on port 80
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "cortex_http" {
  load_balancer_arn = module.alb_cortex.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = module.cortex_distributor.target_group_arn
    type             = "forward"
  }

  # default_action {
  #   type = "redirect"

  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# # ------------------------------------------------------------------------------
# # Create cortex LB TLS listener and open ingress on port 443
# # ------------------------------------------------------------------------------
# resource "aws_lb_listener" "cortex_https" {
#   load_balancer_arn = module.alb_cortex.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   certificate_arn   = aws_acm_certificate.cert_cortex.arn

#   default_action {
#     target_group_arn = module.cortex_distributor.target_group_arn
#     type             = "forward"
#   }
# }

resource "aws_security_group_rule" "cortex_ingress_80" {
  security_group_id = module.alb_cortex.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}

# resource "aws_security_group_rule" "cortex_ingress_443" {
#   security_group_id = module.alb_cortex.security_group_id
#   type              = "ingress"
#   protocol          = "tcp"
#   from_port         = "443"
#   to_port           = "443"
#   cidr_blocks       = ["0.0.0.0/0"]
# }
