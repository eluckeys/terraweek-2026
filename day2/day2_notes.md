# Day 2 — HCL Deep Dive: Variables, Types & Expressions

## Task 1: Master HCL Syntax

**Anatomy of a block:** `block_type "label_one" "label_two" { argument = value }`

Example from our code:
```hcl
resource "docker_container" "web" {
  name  = var.container_name
  image = docker_image.nginx.image_id
}
```
Here `resource` is the block type, `"docker_container"` is label_one (the resource type), `"web"` is label_two (the local name we refer to it by). Inside the `{}`, `name = var.container_name` is an argument.

**Argument vs Block:**
An **argument** is a single `key = value` assignment (e.g. `name = "tws-web"`). A **block** is a nested structure with its own `{}` that can itself contain more arguments or blocks — like the `ports { }` block inside `docker_container`, which groups `internal`, `external`, `protocol` together instead of them being flat arguments on the resource.

**Expressions:**
- **String interpolation** — embedding a value inside a string: `"${upper(var.environment)}-${join("-", var.tags)}"` (used in our `name_prefix` local).
- **References** — pointing to another resource/variable's value: `docker_image.nginx.image_id` reads the `image_id` attribute off the `docker_image` resource once it's created.
- **Operators** — e.g. the conditional `var.environment == "prod" ? "large" : "small"` used in `instance_size`.

## Task 2: Variables, Types & Validation

Created `variables.tf` covering every major type:

- **Primitives:** `string` (`container_name`), `number` (`external_port`), `bool` (`enable_container`)
- **Collections:** `list(string)` (`tags`), `map(string)` (`labels`), `set(string)` (`unique_names`)
- **Structural:** `object({...})` (`container_spec`), `tuple([...])` (`sample_tuple`)

Special requirements:
```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "api_key" {
  description = "Dummy sensitive value for demo purposes"
  type        = string
  default     = "dummy-not-real"
  sensitive   = true
}
```
- `environment` has a default + a validation block restricting allowed values.
- `api_key` uses `sensitive = true` so its value is hidden in plan/apply output.

## Task 3: Locals, Outputs & Functions

`locals` block computes derived values:
```hcl
locals {
  name_prefix   = "${upper(var.environment)}-${join("-", var.tags)}"
  upper_tags    = [for t in var.tags : upper(t)]
  instance_size = var.environment == "prod" ? "large" : "small"
}
```

Explored functions live in `terraform console`:
```
> upper("terraweek")
"TERRAWEEK"

> merge({a=1}, {b=2})
{
  "a" = 1
  "b" = 2
}

> join("-", ["tws", "terraweek", "2026"])
"tws-terraweek-2026"
```

Outputs exposed:
```hcl
output "container_url"  { value = "http://localhost:${var.external_port}" }
output "name_prefix"    { value = local.name_prefix }
output "upper_tags"     { value = local.upper_tags }
output "instance_size"  { value = local.instance_size }
```

Result after apply:
```
container_url = "http://localhost:8080"
instance_size = "small"
name_prefix   = "DEV-tws-terraweek"
upper_tags    = ["TWS", "TERRAWEEK"]
```

## Task 4: Build Something Real (Docker provider)

Used `kreuzwerker/docker` provider to pull nginx and run a container, fully variable-driven.

**Run 1 — using `-var` flags:**
```
$ terraform plan  -var 'container_name=tws-web' -var 'external_port=8080'
Plan: 2 to add, 0 to change, 0 to destroy.

$ terraform apply -auto-approve -var 'container_name=tws-web' -var 'external_port=8080'
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Ran into a port conflict on first attempt — port 8080 was already held by an existing `zabbix-web` container from my homelab monitoring stack (`docker: Bind for 0.0.0.0:8080 failed: port is already allocated`). Confirmed with `docker ps`, temporarily stopped `zabbix-web`, re-applied successfully, and restarted it afterward with `docker start zabbix-web` once done — a good real example of why port conflicts matter when running local providers on a machine already running other services.

Also accidentally interrupted an apply mid-pull with Ctrl+C — Terraform handled it gracefully ("Gracefully shutting down... Stopping operation...") instead of leaving state corrupted, then a clean re-run finished fine.

```
$ curl -s localhost:8080 | head -5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
```

```
$ terraform destroy -auto-approve -var 'container_name=tws-web' -var 'external_port=8080'
Destroy complete! Resources: 2 destroyed.
```

**Run 2 — using `terraform.tfvars` instead of `-var` flags:**
```bash
cp terraform.tfvars.example terraform.tfvars
terraform apply -auto-approve   # no -var flags needed at all
```
Same result — container created, nginx reachable on localhost:8080 — but without typing any `-var` flags, because Terraform auto-loads `terraform.tfvars` from the working directory.

```
terraform destroy -auto-approve
```

**Difference noted:**
- `-var` flags are one-off / explicit — good for CI pipelines or quick manual overrides.
- `terraform.tfvars` is auto-loaded every run — good for persistent, per-environment defaults so you don't retype flags each time.
- Precedence (highest wins): `-var` / `-var-file` ▶ `*.auto.tfvars` ▶ `terraform.tfvars` ▶ `TF_VAR_` env vars ▶ `default`.
- `terraform.tfvars` is gitignored in this repo (only `terraform.tfvars.example` is committed) since it can hold environment-specific or sensitive values.

## Bonus (Brownie Points)

- Used a `for` expression to transform a list: `[for t in var.tags : upper(t)]` → `upper_tags` output.
- Used a conditional expression: `var.environment == "prod" ? "large" : "small"` → `instance_size` output.

## Takeaway
Variables + locals + functions made the same config reusable across environments without editing the `.tf` files themselves — just swap the `tfvars` or flags. The port-conflict incident was a useful real-world reminder that local providers (Docker) still interact with the host machine's existing state, unlike the fully isolated Day 1 example.
