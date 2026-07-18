# Day 3 — Providers, Resources & First Cloud Infra

## Setup
Initially had an issue where `aws sts get-caller-identity` kept returning the fake LocalStack account (`000000000000`) even after configuring real credentials via `aws configure`. Root cause: an `AWS_ENDPOINT_URL` environment variable (left over from a local `floci`/LocalStack-style AWS emulator running on port 4566) was silently redirecting all AWS API calls to `localhost.floci.io:4566`, overriding the real endpoint regardless of correct credentials. Fixed by unsetting `AWS_ENDPOINT_URL` and `AWS_ENDPOINT_URL_STS` — a good reminder that AWS CLI/SDK resolves config in a strict order (env vars > shared credentials file > config file), and env vars can silently mask correctly-configured credentials.

Provider used: `hashicorp/aws ~> 6.0`, region `ap-south-1` (Mumbai).

## Task 1: Providers & Version Pinning

```hcl
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"
}
```

**Why version pinning matters:** without it, a `terraform init` months later could silently pull a newer provider version with breaking changes or deprecated resource arguments, and the same config could behave differently on a teammate's machine. Pinning guarantees reproducible builds.

**The `~>` (pessimistic constraint) operator:** `~> 6.0` allows any `6.x` version but blocks `7.0` — so you get bug fixes/minor features automatically but never an unexpected major-version breaking change.

## Task 2: Resources vs Data Sources

**Data sources** (read-only lookups, don't create anything):
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

**Resources** (created/managed by Terraform): `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`, `aws_security_group`, `aws_instance`.

**Difference:** a resource is something Terraform creates, tracks in state, and can destroy. A data source only *reads* existing information (here: the latest Amazon Linux 2023 AMI ID, and the list of available AZs in the region) — it never shows up as something to "destroy."

## Task 3: Provisioned a Cloud Stack

Built a minimal, free-tier-friendly network + compute stack:
```
Internet ──▶ [IGW] ──▶ [Route Table] ──▶ [Public Subnet] ──▶ [SG] ──▶ [EC2]
                                          (inside the VPC)
```

Resources created (9 total): `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`, `aws_security_group`, plus 3 EC2 instances.

```
$ terraform apply -auto-approve
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:
named_instance_ips = {
  "api" = "52.66.99.165"
  "db"  = "13.232.93.112"
}
vpc_id = "vpc-095da4917a92d137e"
web_instance_ips = ["13.127.115.242"]
```

```
$ terraform state list
data.aws_ami.al2023
data.aws_availability_zones.available
aws_instance.named["api"]
aws_instance.named["db"]
aws_instance.web[0]
aws_internet_gateway.igw
aws_route_table.public
aws_route_table_association.public
aws_security_group.web
aws_subnet.public
aws_vpc.main
```

## Task 4: Meta-Arguments in Action

- **`count`** — `aws_instance.web` uses `count = var.instance_count` to create N identical instances (tested with 1).
- **`for_each`** — `aws_instance.named` uses `for_each = var.named_instances` (a map: `{ api = "t3.micro", db = "t3.micro" }`) to create named, stable-identity instances — better than `count` here since deleting one (say `db`) won't reindex/touch `api`.
- **`depends_on`** — both instance resources explicitly declare `depends_on = [aws_route_table_association.public]`, forcing Terraform to wait until the subnet has internet routing before launching instances that need it.
- **`lifecycle`** — practiced all three:
  ```hcl
  # on aws_instance.web
  lifecycle {
    create_before_destroy = true
    ignore_changes         = [tags["LastModified"]]
  }

  # on aws_vpc.main
  lifecycle {
    prevent_destroy = true
  }
  ```
  `prevent_destroy` was temporarily enabled to prove Terraform actually blocks a destroy attempt on a protected resource, then disabled again before the real cleanup destroy.

**count vs for_each — my takeaway:** use `count` for throwaway identical resources where order/identity doesn't matter; use `for_each` the moment each instance has a real name/purpose, since it avoids the "delete resource #2, and suddenly #3 becomes #2" reindexing problem `count` has.

## Task 5: Update & Destroy — reading the diff

**Tag change → in-place update, no interruption:**
```
~ resource "aws_instance" "web" {
    ~ tags = { "Name" = "tws-web-0" -> "tws-web-updated-0" }
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```

**instance_type change (t3.micro → t3.small) → also in-place, but with a stop/start:**
```
~ resource "aws_instance" "web" {
    ~ instance_type = "t3.micro" -> "t3.small"
    ~ public_ip     = "13.127.115.242" -> (known after apply)
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```
Learned something I initially assumed wrong: changing `instance_type` does **not** force a destroy/recreate on AWS — Terraform's AWS provider stops and restarts the instance in-place instead. The instance ID stays the same, but `public_ip`/`public_dns` get reassigned (since AWS gives a new public IP on every stop/start unless you use an Elastic IP). Changes that *do* force full replacement are things like changing the `ami` or certain network-level attributes that can't be modified on a running instance.

**Final cleanup:**
```
$ terraform destroy -auto-approve
Destroy complete! Resources: 9 destroyed.
```

## Takeaway
This was the first day working against real AWS instead of local providers — the network primer (VPC → subnet → IGW → route table → SG → EC2) mapped cleanly onto things I already understand from the Linux/networking side, just declared instead of clicked. The env var mishap with the local AWS emulator was a useful real debugging session in itself.
