locals {
  envs = {
    dev     = 1
    staging = 1
  }
}

module "web_stack" {
  for_each       = local.envs
  source         = "./modules/web_stack"
  env_name       = each.key
  instance_count = each.value
}
