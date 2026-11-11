# Terraform Interview Questions (Senior DevOps)

**Audience:** ~13 years DevOps experience — senior-level guide, not definition-only cramming.

**How to use:** Answers are short enough to speak aloud. Code and commands support practical follow-ups. Prioritize **state**, **modules**, **CI/CD**, **troubleshooting**, and **AWS architecture**.

---

## Table of contents

1. [Fundamentals and architecture](#1-terraform-fundamentals-and-architecture)
2. [Providers, variables, outputs](#2-providers-resources-variables-and-outputs)
3. [State management](#3-terraform-state-management-must-master)
4. [Modules](#4-terraform-modules-must-master)
5. [Advanced concepts and meta-arguments](#5-advanced-terraform-concepts-and-meta-arguments)
6. [Workspaces and environments](#6-workspaces-and-environment-management)
7. [CI/CD and DevOps](#7-terraform-cicd-and-devops-integration)
8. [Security and secrets](#8-terraform-security-and-secrets-management)
9. [Troubleshooting and scenarios](#9-terraform-troubleshooting-and-real-time-scenarios)
10. [Practical AWS with solutions](#10-practical-aws-terraform-questions-with-solutions)
11. [Command reference](#11-important-terraform-commands)
12. [Lab assignments and capstone](#12-practical-assignments-and-capstone-project)
13. [Study roadmap](#13-terraform-preparation-roadmap)
14. [Knowledge check (answer key)](#14-terraform-knowledge-check-answer-key)

---

## 1. Terraform fundamentals and architecture

### 1. What is Terraform?

Terraform is HashiCorp’s **Infrastructure as Code (IaC)** tool. You declare desired infrastructure in configuration; Terraform provisions and manages it via provider APIs (EC2, VPC, S3, RDS, EKS, etc.).

### 2. What is Infrastructure as Code?

Managing infrastructure through **versioned code** instead of manual clicks.

| Benefit | Why it matters |
|--------|----------------|
| Automation & consistency | Same result every environment |
| Version control | Auditable changes |
| Repeatable deployments | Faster, less human error |

### 3. Explain Terraform architecture

```
Configuration (main.tf, variables.tf, outputs.tf)
        ↓
Terraform Core (graph, plan, apply)
        ↓
Provider plugins (AWS, Azure, GCP, Kubernetes, …)
        ↓
Real infrastructure APIs
```

Core reads config, builds the **dependency graph**, and drives providers. Providers call cloud APIs.

### 4. Main components

| Component | Role |
|-----------|------|
| Providers | Connect to platforms |
| Resources | Create/manage objects |
| Data sources | Read existing infra |
| Variables / Locals / Outputs | Input, reuse, expose values |
| Modules | Reusable config packages |
| State | Map config ↔ real resources |

### 5. What is a provider?

Plugin that talks to an external API.

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

### 6. What is a resource?

An object Terraform **owns** in its lifecycle.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-xxxxxxxx"
  instance_type = "t3.micro"
}
```

### 7. What is a data source?

Reads existing infra; **does not** create or manage it.

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

### 8. Resource vs data source

| | Resource | Data source |
|---|----------|-------------|
| Lifecycle | Managed by Terraform | Read-only |
| Use case | Create EC2 | Find latest AMI |

### 9. What is a dependency graph?

Directed graph of resources/data. Terraform uses it for **order** and **parallelism**.

### 10. Implicit vs explicit dependency

**Implicit** — reference in config:

```hcl
resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id
}
```

**Explicit** — no reference but order matters:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-xxxxxxxx"
  instance_type = "t3.micro"

  depends_on = [aws_iam_role_policy_attachment.example]
}
```

Use `depends_on` only when Terraform cannot infer the link from attributes.

### 11. What happens during `terraform init`?

- Backend initialization  
- Provider download  
- Module installation  
- `.terraform.lock.hcl` update  

### 12. Plan vs apply

| Command | Purpose |
|---------|---------|
| `terraform plan` | Preview changes |
| `terraform apply` | Execute changes |

### 13. What is `terraform validate`?

Syntax and internal consistency only — **not** “will AWS accept this?”

### 14. Terraform vs Ansible

| | Terraform | Ansible |
|---|-----------|---------|
| Focus | Provisioning | CM / automation |
| Style | Declarative desired state | Task-oriented (declarative roles exist) |
| State | Yes | No Terraform-style state |

### 15. Declarative configuration

You specify **desired end state**; Terraform computes the diff.

---

## 2. Providers, resources, variables and outputs

### 16. Configure AWS provider

```hcl
terraform {
  required_version = ">= 1.10.0"

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

### 17. Multiple AWS regions — provider aliases

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

resource "aws_s3_bucket" "backup" {
  provider = aws.virginia
  bucket   = "my-backup-bucket-example"
}
```

### 18–21. Variables, locals, outputs

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

locals {
  environment = "dev"
  common_name = "app-${local.environment}"
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

| | Purpose |
|---|---------|
| Variables | Input from user/CI |
| Locals | Derived / reused values |
| Outputs | Values for humans or other stacks |

### 22. Variable types

`string`, `number`, `bool`, `list`, `set`, `map`, `object`, `tuple`.

```hcl
variable "instance_types" {
  type    = list(string)
  default = ["t3.micro", "t3.small"]
}
```

### 23. Variable validation

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be dev, qa or prod."
  }
}
```

### 24. `terraform.tfvars` vs `*.auto.tfvars`

Both auto-load. Other files: `terraform apply -var-file="dev.tfvars"`.

### 25. CLI variables

```bash
terraform apply -var="instance_type=t3.small"
terraform apply -var-file="dev.tfvars"
```

### 26. Sensitive variables

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

Redacts CLI output; **does not** remove secrets from **state** or saved plans.

### 27. Latest Amazon Linux AMI

Use `data "aws_ami"` (see Q7) — avoid hardcoded AMI IDs.

### 28. Avoid hardcoded AWS credentials

IAM roles, instance profiles, IAM Identity Center, **OIDC** from CI. Never commit keys.

### 29. Resources in multiple regions

Provider aliases on resources or modules.

### 30. Dependency lock file

`.terraform.lock.hcl` — pinned provider versions and checksums for reproducible `init`.

---

## 3. Terraform state management (must-master)

### 31. What is Terraform state?

JSON mapping **resource addresses** in code → **real IDs and attributes**. Default local: `terraform.tfstate`.

### 32. Why state is required

- Know what Terraform manages  
- Store IDs for updates  
- Compute plans and dependencies  
- Avoid blind recreate  

### 33. State file deleted — AWS still running?

Resources **keep running**. Terraform **forgets** them; the next plan may propose **duplicates**.

**Recovery:** S3 version restore, backup, or **import** + reconcile config.

### 34. Remote state (S3 example)

```hcl
terraform {
  backend "s3" {
    bucket       = "company-terraform-state"
    key          = "dev/network/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Bucket must exist; lock and IAM must be designed up front.

### 35. State locking

Prevents concurrent writes to the same state. S3 backend: `use_lockfile = true` (Terraform ≥ 1.10). Prefer current docs over legacy DynamoDB lock patterns unless your org standardizes otherwise.

### 36. S3 versioning on state bucket

Recover from corrupt or overwritten state objects.

### 37. Two engineers apply at once

With remote backend + locking: one holds the lock; the other waits or fails safely.

### 38. State drift

Live infra differs from config/state (manual changes, external automation).

### 39. Detect drift

```bash
terraform plan
terraform plan -refresh-only
```

### 40. Import existing EC2

```bash
terraform import aws_instance.web i-0123456789abcdef0
```

Import updates **state only** — you still write matching `resource` blocks.

### 41–44. State CLI essentials

```bash
terraform state list
terraform state show aws_instance.web
terraform state mv aws_instance.old aws_instance.new
terraform state rm aws_instance.web    # removes from state; does NOT delete AWS resource
```

### 45. State recovery (typical runbook)

1. Stop pipelines  
2. Backup current state  
3. Restore known-good S3 version  
4. Validate against live infra  
5. `terraform plan` — investigate every unexpected change  

### 46. No state backup

Import resources one by one, then `state list` + `plan` until clean.

### 47. Migrate local → S3

Configure backend → `terraform init -migrate-state` (backup local state first).

### 48. Is state encrypted?

Local: your disk risk. S3: SSE, bucket policy, IAM, versioning, audit.

### 49. Does `sensitive` encrypt state?

**No** — redaction in CLI; protect the backend.

### 50. `terraform force-unlock`

```bash
terraform force-unlock LOCK_ID
```

Only when the lock is **stale** and no apply is running.

---

## 4. Terraform modules (must-master)

### 51. What are modules?

Reusable bundles of `.tf` files (VPC, EKS wrapper, standard EC2, etc.).

### 52. Root vs child module

| | Root | Child |
|---|------|-------|
| Where | Directory where you run `terraform` | Called via `module "..."` |
| State | Single state for root + children | Same state unless separate root/backends |

### 53. Why modules?

Reusability, standards, less copy-paste, easier upgrades, team alignment.

### 54–56. Custom module pattern

**Layout:**

```text
terraform-project/
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

**Child `modules/ec2/main.tf`:**

```hcl
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags          = { Name = var.name }
}
```

**Root:**

```hcl
module "web_server" {
  source        = "./modules/ec2"
  ami_id        = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  name          = "web-server"
}

output "web_instance_id" {
  value = module.web_server.instance_id
}
```

### 57. Nested modules

Yes — platform module can call VPC + SG + EC2 modules.

### 58. Separate state per child module?

**No** by default — one state per **root**. Separate stacks = separate roots + backend keys.

### 59. Git module source

```hcl
module "vpc" {
  source = "git::https://github.com/company/terraform-modules.git//vpc?ref=v1.0.0"
}
```

Always pin `ref` (tag or commit).

### 60–63. Good module design

- Clear inputs/outputs, defaults, validation  
- Consistent tagging  
- README + examples  
- Version tags in Git or private registry  

**VPC module sketch:** inputs (CIDR, AZs, public/private subnets, tags); resources (VPC, IGW, NAT optional, routes); outputs (vpc_id, subnet_ids).

### 64. Module upgrade

New module code + existing state → plan may update/replace. **Always plan in lower env first.**

---

## 5. Advanced Terraform concepts and meta-arguments

### 65. `count`

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = var.ami_id
  instance_type = "t3.micro"
}
# aws_instance.web[0], [1], [2]
```

### 66. `for_each`

```hcl
resource "aws_s3_bucket" "app" {
  for_each = toset(["dev", "qa", "prod"])
  bucket   = "company-app-${each.key}"
}
```

### 67. `count` vs `for_each`

| | count | for_each |
|---|-------|----------|
| Key | Index `0..n-1` | Stable map/set key |
| Risk | Index shift on insert | Keys stable |
| Prefer | Homogeneous copies | Named / distinct instances |

### 68. `depends_on`

Explicit ordering when there is no attribute reference (see Q10).

### 69. Dynamic block

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = "tcp"
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```

### 70–73. Lifecycle

```hcl
lifecycle {
  create_before_destroy = true   # new then old (less downtime; needs capacity/names)
  prevent_destroy       = true   # block destroy (DB safeguard)
  ignore_changes        = [tags] # skip drift on listed attrs — use sparingly
}
```

### 74–75. Expressions

```hcl
instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

locals {
  upper_names = [for name in var.names : upper(name)]
}
```

### 76. Common functions

`length`, `upper`, `merge`, `lookup`, `concat`, `zipmap`, …

### 77. `templatefile()`

```hcl
locals {
  user_data = templatefile("${path.module}/userdata.tpl", {
    app_name = "myapp"
  })
}
```

### 78. `terraform console`

REPL for expressions: `upper("dev")` → `"DEV"`.

### 79. `terraform graph`

Dependency visualization (pipe to Graphviz).

### 80. `moved` blocks

Refactor addresses without destroy/recreate:

```hcl
moved {
  from = aws_instance.old
  to   = aws_instance.new
}
```

---

## 6. Workspaces and environment management

### 81–85. Workspaces

Multiple **state instances**, same config:

```bash
terraform workspace list
terraform workspace new dev
terraform workspace select dev
```

Default workspace: `default`.

### 86. Workspaces vs separate directories

| Workspaces | Separate `environments/{dev,qa,prod}/` |
|------------|------------------------------------------|
| Shared code, different state | Different code, backend, IAM, accounts |
| Light isolation | Stronger prod isolation |

### 87–88. Dev / QA / prod pattern

```text
terraform/
├── modules/{vpc,ec2,rds}
└── environments/{dev,qa,prod}/   # each: own backend key, tfvars, possibly account
```

**Senior take:** Do not rely on workspaces alone for production — separate accounts, roles, and state keys.

---

## 7. Terraform CI/CD and DevOps integration

### 89–90. Jenkins / pipeline flow

1. Git push  
2. `terraform fmt` + `validate`  
3. Security/policy (Checkov, TFLint, OPA)  
4. `init` + `plan -out=tfplan`  
5. Human or policy approval  
6. `apply tfplan`  
7. Smoke checks / outputs  

### 91. Example Jenkins stages

```groovy
stage('Init') {
  steps { sh 'terraform init -input=false' }
}
stage('Validate') {
  steps { sh 'terraform validate' }
}
stage('Plan') {
  steps { sh 'terraform plan -out=tfplan' }
}
stage('Apply') {
  steps {
    input 'Approve deployment?'
    sh 'terraform apply -input=false tfplan'
  }
}
```

Production: saved plan integrity, correct backend, least-privilege role for **apply**.

### 92. AWS credentials in Jenkins

EC2/instance role, **OIDC → AssumeRole**, or secrets store — not long-lived keys in Git.

### 93. Terraform on pull requests

Plan only on PR; no auto-apply with prod creds from forks.

### 94. Prevent accidental prod deploy

Separate accounts/roles, branch protection, manual approval, env-specific backends, deployment policies.

### 95. Failed pipeline runbook

Logs → which phase (init/plan/apply) → lock → IAM/quota → AWS vs state → fix → **new plan** → apply.

### 96. Concurrent Jenkins jobs

Remote locking + queue/singleton per state key.

### 97. Rollback

Not transactional. Revert Git, plan, apply corrective diff; for state incidents, restore versioned state.

### 98. Checkov + TFLint

CI stages before apply — misconfigurations and provider lint.

### 99. Multiple AWS accounts

Per-account role, backend key, and root (or wrapper) with `assume_role` on provider.

---

## 8. Terraform security and secrets management

### 100. Secrets in Terraform

Secrets Manager, SSM Parameter Store, Vault — **not** plaintext in Git. Treat **state and plan artifacts** as secret-bearing.

### 101. `sensitive = true`

CLI redaction only.

### 102. Secrets Manager data source

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/database"
}
```

Value may land in state — often better: app fetches at runtime.

### 103. Least privilege

Narrow IAM for plan vs apply; separate prod roles; SCPs/permissions boundaries.

### 104. Secure S3 state

Versioning, encryption, block public access, tight IAM, logging, locking, no public plan files.

### 105. Policy as Code

Enforce tags, encryption, no public S3, allowed instance types — Checkov, OPA/Conftest, Sentinel, etc.

---

## 9. Terraform troubleshooting and real-time scenarios

| # | Scenario | Senior response |
|---|----------|-----------------|
| 106 | Unexpected **replacement** (`-/+`) | Find triggering attribute (immutable/replace); provider/module bump; manual change — **do not apply blind** |
| 107 | Apply **failed mid-way** | Partial create possible — inspect AWS, state, error; fix; re-plan; apply remainder (no auto-rollback) |
| 108 | Manual EC2 change | `terraform plan` after refresh shows drift |
| 109 | Corrupt state | Stop writes; backup; restore S3 version; plan |
| 110 | Missing state, infra exists | Backup hunt → import + matching config |
| 111 | Two simultaneous applies | Remote lock + CI serialization |
| 112 | Wants **recreate** existing | `state show`, plan diff, address rename, provider schema |
| 113 | Resource exists, plan wants create | `terraform import` + reconcile |
| 114 | Destroy would hit prod DB | Block apply; `prevent_destroy`; restricted roles; policy |
| 115 | Provider upgrade breaks | Changelog; pin old version; fix deprecations; test plan in dev |
| 116 | Module upgrade surprise | Pin version; read release notes; plan in QA |
| 117 | Cannot reach S3 backend | Creds, IAM, bucket/region/key, policy, KMS, network |
| 118 | Cannot assume role | Trust policy, `sts:AssumeRole`, ARN, external ID, SCP |
| 119 | Endless noop-ish diffs | API normalization, computed fields, external taggers, bad `ignore_changes`, provider bug — diff exact attrs |
| 120 | Safe **rename** in code | `moved` block (or `state mv`) |
| 121 | Move between **states** | Supported migration workflows; backup both; never “rm + hope” |
| 122 | Accidental **destroy** | Recreate from code; restore data from backups; fix process |
| 123 | Long apply | Logs, throttling, timeouts, dependency wait — don’t kill without context |

---

## 10. Practical AWS Terraform questions with solutions

### EC2

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  tags          = { Name = "web-server" }
}
```

### VPC + subnet + IGW + SG

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "main-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### S3 versioning

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "company-demo-data-12345"
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

Add encryption, public access block, and bucket policy in real environments.

### ALB / ASG / RDS / IAM / EKS (interview talking points)

| Workload | Core resources |
|----------|----------------|
| ALB | `aws_lb`, target group, listener, attachments — **≥2 AZ** subnets |
| ASG | Launch template, ASG, scaling policies, health checks |
| RDS | Subnet group, `aws_db_instance`, private subnets, encryption, backups, SG |
| IAM | Role + policy + attachment; minimal trust + permissions |
| EKS | VPC, cluster IAM, node IAM, managed node groups, SGs, add-ons, private workers multi-AZ |

### Multi-AZ

Drive subnets with `for_each` over AZ + CIDR variables.

### Multi-account

Assume-role per account; separate state keys; CI selects role by environment.

---

## 11. Important Terraform commands

| Command | When to use |
|---------|-------------|
| `terraform init` | Backend, providers, modules |
| `terraform fmt` | Format HCL |
| `terraform validate` | Static validation |
| `terraform plan` / `apply` | Preview / execute |
| `terraform destroy` | Tear down managed resources |
| `terraform output` | Read outputs |
| `terraform state list/show/mv/rm` | Inspect and repair state |
| `terraform state pull/push` | Advanced state ops (**push**: extreme care) |
| `terraform import` | Adopt existing infra |
| `terraform show` | State or saved plan |
| `terraform console` | Test expressions |
| `terraform graph` | Dependency diagram |
| `terraform workspace *` | Workspace management |
| `terraform plan -refresh-only` | Drift / refresh review |
| `terraform force-unlock` | Stale lock only |

> Prefer `plan -refresh-only` over legacy `terraform refresh`.

---

## 12. Practical assignments and capstone project

### Lab checklist (12 exercises)

| # | Assignment | Demonstrates |
|---|------------|----------------|
| 1 | EC2 | Provider, variables, outputs |
| 2 | Dynamic AMI | Data sources |
| 3 | VPC + subnets | AWS networking |
| 4 | VPC module | Root/child modules |
| 5 | 3× EC2 with `for_each` | Meta-arguments |
| 6 | S3 remote backend | Remote state |
| 7 | Versioning + locking | State protection |
| 8 | Import EC2 | Import workflow |
| 9 | Simulate corrupt/missing state | Recovery |
| 10 | dev / qa / prod roots | Environments |
| 11 | Jenkins pipeline | CI/CD |
| 12 | Full stack from modules | Architecture interview story |

### Capstone architecture

```text
                 Jenkins CI/CD
                      |
                 Git Repository
                      |
                Terraform Code
                      |
               Terraform Modules
                      |
           +---------+---------+
           |         |         |
          DEV       QA       PROD
           |         |         |
          VPC       VPC       VPC
        Subnets   Subnets   Subnets
           |         |         |
          ALB       ALB       ALB
           |         |         |
          EC2       EC2       EC2
           |         |         |
          RDS       RDS       RDS

        S3 Remote State + Locking
```

**Suggested layout:**

```text
terraform-project/
├── modules/{vpc,security-group,ec2,alb,rds}
├── environments/{dev,qa,prod}
└── Jenkinsfile
```

**Be ready to explain:**

1. Why modules exist  
2. Per-environment config and backends  
3. Remote state and locking  
4. Preventing concurrent prod applies  
5. State recovery  
6. Jenkins integration and creds (OIDC/roles)  
7. Prod approval and plan review  

**Cost:** RDS, NAT, ALB, EKS accrue charges — destroy lab resources when done.

---

## 13. Terraform preparation roadmap

| Week | Topics | Outcome |
|------|--------|---------|
| 1 | Fundamentals, providers, variables, data sources | Write HCL independently |
| 2 | Modules, `count`/`for_each`, lifecycle, functions | Reusable stacks |
| 3 | State, S3, locking, import, drift, recovery | Production state incidents |
| 4 | CI/CD, security, multi-env, troubleshooting | Enterprise narrative |

**Focus for senior interviews:** state management, reusable modules, multi-environment design, Jenkins (or GitHub Actions) integration.

---

## 14. Terraform knowledge check (answer key)

| # | Question (short) | Answer |
|---|------------------|--------|
| 1 | State deleted, EC2 still running? | **Restore backup or import** — AWS does not auto-delete; Terraform does not auto-rebuild state |
| 2 | Unique names/configs per instance? | **`for_each`** |
| 3 | `sensitive = true` encrypts state? | **No** — mainly redacts CLI output |
| 4 | Prevents concurrent state writes? | **State locking** |
| 5 | Rename resource without recreate? | **`moved` block** (or `state mv`) |

---

*Document version: senior DevOps interview prep — Terraform with AWS emphasis.*
