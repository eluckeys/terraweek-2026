output "all_vpc_ids" {
  value = { for k, m in module.web_stack : k => m.vpc_id }
}

output "all_web_ips" {
  value = { for k, m in module.web_stack : k => m.web_instance_ips }
}
