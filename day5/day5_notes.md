# Day 5 — Modules: Reusable, Composable Infrastructure

## What I built
Took Day 3's VPC + EC2 stack and turned it into a reusable module (`modules/web_stack/`), then called that same module twice from the root config using `for_each` — once for `dev`, once for `staging` — each getting its own fully isolated VPC.

## Module structure
```
day5/
├── terraform.tf          # provider config
├── main.tf                # root config calling the module
├── outputs.tf             # root outputs
└── modules/
    └── web_stack/
        ├── data.tf         # AMI + AZ data sources
        ├── main.tf         # VPC, subnet, IGW, route table, SG, EC2 (count)
        ├── variables.tf    # env_name, instance_count
        └── outputs.tf      # vpc_id, web_instance_ips
```

**Key design choice:** the module takes `env_name` as an input and uses it in every resource's `Name` tag / SG name (e.g. `tws-vpc-${var.env_name}`) so that calling it twice never causes a naming collision between environments — each environment's resources are clearly distinguishable in the AWS console.

## Root config — module composition via `for_each`
```hcl
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
```

```hcl
output "all_vpc_ids" {
  value = { for k, m in module.web_stack : k => m.vpc_id }
}
output "all_web_ips" {
  value = { for k, m in module.web_stack : k => m.web_instance_ips }
}
```

## Result
```
$ terraform plan
Plan: 14 to add, 0 to change, 0 to destroy.

$ terraform apply -auto-approve
Apply complete! Resources: 14 added, 0 changed, 0 destroyed.

all_vpc_ids = {
  "dev"     = "vpc-02ab0069adfe1bec2"
  "staging" = "vpc-0953d6d5827a8e755"
}
all_web_ips = {
  "dev"     = ["13.234.136.183"]
  "staging" = ["43.204.25.218"]
}
```

Two completely separate, independent VPCs — same module code, different `env_name` input. 14 resources total = 7 resources × 2 environments (VPC, subnet, IGW, route table, route table association, security group, EC2 instance).

```
$ terraform destroy -auto-approve
Destroy complete! Resources: 14 destroyed.
```

## Takeaway
This is the real value of modules: I didn't rewrite any VPC/subnet/SG logic for `staging` — I just called the same module a second time with a different key. If I needed a `prod` environment tomorrow, it's one more entry in the `envs` map, not fifty more lines of duplicated `.tf` code. This is exactly the kind of duplication I used to handle with copy-pasted Ansible playbooks or shell scripts across environments — modules give Terraform the same "write once, parameterize per environment" pattern, but with full dependency tracking built in.
