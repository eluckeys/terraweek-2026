output "container_url" {
  value = "http://localhost:${var.external_port}"
}

output "name_prefix" {
  value = local.name_prefix
}

output "upper_tags" {
  value = local.upper_tags
}

output "instance_size" {
  value = local.instance_size
}
