variable "aws_region" {
  description = "The aws region"
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "ID of the VPC"
}

variable "subdomain" {}
variable "prefix" {}


variable "tags" {
  type = map(string)
}

variable "cortex_image" {
  type    = string
  default = "cortexproject/cortex:master-06c4340e"
}

variable "public_route53_zone_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list
}

variable "public_subnet_ids" {
  type = list
}

variable "consul_service_sg_id" {
  type = string
}

variable "prometheus_service_sg_id" {
  type = string
}

variable "grafana_service_sg_id" {
  type = string
}

variable "service_discovery_private_dns_namespace_id" {
  type = string
}
