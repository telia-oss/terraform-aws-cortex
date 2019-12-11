module "cortex" {
  source = "../modules/cortex"

  prefix                                     = "cortex"
  subdomain                                  = data.terraform_remote_state.template.outputs.subdomain
  vpc_id                                     = data.terraform_remote_state.template.outputs.vpc_id
  private_subnet_ids                         = data.terraform_remote_state.template.outputs.private_subnet_ids
  public_subnet_ids                          = data.terraform_remote_state.template.outputs.public_subnet_ids
  public_route53_zone_id                     = data.terraform_remote_state.template.outputs.public_route53_zone_id
  tags                                       = data.terraform_remote_state.template.outputs.tags
  consul_service_sg_id                       = data.terraform_remote_state.template.outputs.consul_service_sg_id
  prometheus_service_sg_id                   = data.terraform_remote_state.template.outputs.prometheus_service_sg_id
  grafana_service_sg_id                      = data.terraform_remote_state.template.outputs.grafana_service_sg_id
  service_discovery_private_dns_namespace_id = data.terraform_remote_state.template.outputs.service_discovery_private_dns_namespace_id
}
