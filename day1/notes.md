# Day 1 — IaC & Terraform Basics

## Task 1: Understand IaC & Terraform

**What is Infrastructure as Code, and what problems does it solve compared to clicking around a cloud console?**
Infrastructure as Code (IaC) means defining infrastructure in config files instead of manually clicking through a cloud console. As a Linux admin I've felt the console problem firsthand — you make a change on Monday, forget what you clicked, and by Friday nobody knows why a security group rule exists. IaC fixes that: the config file itself is the source of truth, it's version-controlled in Git, and it can be reviewed/rolled back like any code change.

**What is Terraform, and why is it so popular?**
Terraform is an infrastructure as a code tool which helps to provision (create) the infrastructure.
Terraform is declarative + stateful — it maintains a `.tfstate` file tracking what it created, so it knows what to change/destroy on the next apply.
It's also popular because it's:
- **Provider-agnostic** — same workflow across AWS, Azure, GCP, Docker, etc.
- **Huge ecosystem** — thousands of community providers/modules on the Registry, so most infra patterns are already written for you.

**Terraform vs alternatives**
- **OpenTofu** — open-source fork of Terraform after the license change, near-identical syntax, community-governed.
- **Pulumi** — lets you write infra in real programming languages (Python/TypeScript) instead of HCL.
- **CloudFormation** — AWS-only, JSON/YAML based, tightly integrated with AWS but no multi-cloud support.
- **Ansible** — better for configuration management (setting things up inside a running server); Terraform is better for provisioning the infrastructure itself.

## Task 2: Install Terraform

```
$ terraform version
Terraform v1.15.x
```

Installed via the official HashiCorp install guide. Also added the HashiCorp Terraform VS Code extension for syntax highlighting/autocomplete.

## Task 3: 6 Crucial Terraform Terminologies

- **Provider** — a plugin that lets Terraform talk to a platform (e.g. `random`, `local`, `aws`). Example: the `random` provider gave us `random_pet`.
- **Resource** — a piece of infrastructure you want to create. Example: `local_file.greeting`.
- **State** — Terraform's record of what it manages, stored in `terraform.tfstate`. It's how Terraform knows what already exists.
- **Plan** — a preview of what will change before you commit to it (`terraform plan`).
- **HCL** — HashiCorp Configuration Language, the syntax used in `.tf` files.
- **Module** — a reusable, packaged group of Terraform configuration you can call from multiple places.

## Task 4: First Terraform Config (local + random providers)

Config used `random_pet` and `local_file` — no cloud account, no cost.

```
$ terraform init
Installed hashicorp/random v3.9.0
Installed hashicorp/local v2.9.0
Terraform has been successfully initialized!

$ terraform fmt
(no changes — already formatted)

$ terraform validate
Success! The configuration is valid.

$ terraform plan
Plan: 2 to add, 0 to change, 0 to destroy.

$ terraform apply
random_pet.name: Creation complete after 0s [id=equal-squirrel]
local_file.greeting: Creation complete after 0s
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

$ cat greeting.txt
Hello Terraform! Pet name: equal-squirrel

$ terraform destroy
Destroy complete! Resources: 2 destroyed.
```

## Core Workflow

```
Write ──▶ Init ──▶ Plan ──▶ Apply ──▶ Destroy
(.tf)     (init)   (preview) (create)  (clean up)
```

## Takeaway
Ran the full Terraform lifecycle end-to-end with zero cloud cost. `init` downloads providers, `plan` shows a diff before anything actually happens (which is the opposite of how I'm used to working on a live Linux box — no dry-run there), and `destroy` cleans up completely, leaving no trace.
