# Day 4 — Terraform State & Remote Backends (Native Locking)

## Task 1: Why State Matters
`terraform.tfstate` is Terraform's record of every resource it manages — real IDs, IPs, ARNs, and all attributes mapped back to the resource addresses in the config. It should never be hand-edited or committed to Git because it can contain sensitive data in plaintext (e.g. secrets, private IPs, generated passwords) and manual edits can desync it from real infrastructure, causing Terraform to make wrong decisions on the next apply.

**State drift** happens when real infrastructure changes outside of Terraform (someone manually edits a security group in the console, for example). `terraform plan`/`terraform refresh` compares the real infra against the state file and shows the difference — this is how Terraform detects drift.

## Task 2: Local State & `terraform state` commands
Practiced on a small local/random config:

```
$ terraform state list
local_file.greeting
random_pet.name

$ terraform state show random_pet.name
resource "random_pet" "name" {
    id        = "talented-tiger"
    length    = 2
    separator = "-"
}

$ terraform state mv random_pet.name random_pet.pet_name
Successfully moved 1 object(s).

$ terraform state rm local_file.greeting
Removed local_file.greeting
Successfully removed 1 resource instance(s).
```

Confirmed `state rm` does **not** delete real infrastructure — after removing `local_file.greeting` from state, `greeting.txt` still existed on disk (`cat greeting.txt` still worked). It just makes Terraform stop tracking that resource.

```
$ terraform show
resource "random_pet" "pet_name" {
    id        = "talented-tiger"
    ...
}
```

| Command | What it does | When to use it |
|---|---|---|
| `state list` | Lists every resource address currently tracked | Quick inventory check before making changes |
| `state show <addr>` | Shows full current attributes of one resource | Debugging, or checking a real ID/IP without going to the console |
| `state mv <src> <dst>` | Renames/moves a resource within state without destroying/recreating it | Refactoring code (renaming a resource block) without any real-world impact |
| `state rm <addr>` | Stops Terraform from managing a resource, but leaves the real thing alone | Handing a resource off to be managed manually or by another tool |
| `terraform show` | Human-readable dump of the whole state file | Quick full-state review |

## Task 3: Bootstrap the Backend Infrastructure
Created the S3 bucket that will hold remote state — using **local** state for this one-time bootstrap step, since the bucket can't reference a backend that doesn't exist yet.

```hcl
resource "aws_s3_bucket" "state" {
  bucket = "saurabh-terraweek-state-${random_id.suffix.hex}"
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
```

```
$ terraform apply -auto-approve
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
bucket_name = "saurabh-terraweek-state-97848a0b"
```

## Task 4: Configure the Remote Backend with Native Locking
Reused Day 3's VPC+EC2 config and pointed it at the new S3 bucket using the modern (2026) native locking approach — no DynamoDB table needed:

```hcl
terraform {
  required_version = ">= 1.15"
  backend "s3" {
    bucket       = "saurabh-terraweek-state-97848a0b"
    key          = "day04/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true   # native S3 state locking via conditional writes
  }
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
```

```
$ terraform init
Successfully configured the backend "s3"!

$ terraform apply -auto-approve
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
vpc_id = "vpc-087f209f348154148"
web_instance_ips = ["13.201.5.239"]
named_instance_ips = { api = "15.206.28.203", db = "13.201.12.23" }
```

Verified in the S3 console that `day04/terraform.tfstate` was uploaded to the bucket after apply.

Cleaned up immediately to avoid ongoing AWS cost:
```
$ terraform destroy -auto-approve
Destroy complete! Resources: 9 destroyed.
```

## What changed vs the old TerraWeek approach
Previously S3 + DynamoDB was the standard pattern for state locking. As of Terraform 1.10 (experimental) / 1.11 (GA), the S3 backend supports **native locking** via `use_lockfile = true`, using S3 conditional writes — no DynamoDB table required at all. DynamoDB-based locking is now deprecated. This is simpler to set up (one less resource to manage) and was used throughout this setup.

## Takeaway
Local state is fine solo, but the moment more than one person (or one person from more than one machine) touches the same infra, remote state + locking becomes essential — it's what prevents two people running `apply` at the same moment from corrupting each other's changes. `state mv`/`state rm` are safety valves for refactoring without real-world side effects, which matters a lot once you're not just tearing everything down and starting fresh each time.
