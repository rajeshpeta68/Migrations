# Phase 3 — Terraform (Weeks 7–8)

**Audience:** Senior DevOps Engineer / Cloud Architect (~13 years experience). You already know Terraform basics—this phase prepares you to **design**, **operate**, and **defend** production AWS infrastructure in interviews, not to learn syntax from scratch.

**Prerequisite:** AWS and Kubernetes preparation complete. Use your **3-node kubeadm lab** for K8s only; for these two weeks, focus on **provisioning and managing the AWS layer** (VPC, compute, IAM, state, CI/CD) with Terraform.

---

## Final outcomes

By the end of Week 8, you should be able to:

- Design **reusable Terraform modules** for multi-project organizations
- Provision **AWS infrastructure** with clear dependency graphs and lifecycle control
- Manage **remote state**, locking, and **concurrent** applies safely
- **Troubleshoot** state corruption, drift, failed applies, and manual changes
- Explain a **production Terraform CI/CD** architecture (plan/apply separation, gates, rollback)

---

## Time commitment

| Activity | Daily |
|----------|------:|
| Conceptual learning | 40 min |
| AWS hands-on | 60 min |
| Interview questions | 30 min |
| Revision | 20 min |
| **Total** | **~2.5 h** |

**Study loop (every topic):**

1. Understand the concept  
2. Implement on AWS (`ap-south-1` unless noted)  
3. Walk through one **production scenario**  
4. Write a **concise interview answer** (60–90 seconds spoken)

---

## Progress tracker

### Week 1 — Core + architecture

- [ ] Day 1 — Architecture and core components  
- [ ] Day 2 — Modules (highest priority)  
- [ ] Day 3 — State and remote backend  
- [ ] Day 4 — Expressions and resource management  
- [ ] Day 5 — State migration and troubleshooting  

### Week 2 — Production + interviews

- [ ] Day 6 — Environments and workspaces  
- [ ] Day 7 — Security and secrets  
- [ ] Day 8 — CI/CD pipeline  
- [ ] Day 9 — Production troubleshooting scenarios  
- [ ] Day 10 — End-to-end AWS project  

### Interview readiness (no notes)

- [ ] Top 10 questions (see below)  
- [ ] Five repo deliverables committed  

---

## Roadmap at a glance

| Week | Focus |
|------|--------|
| **Week 1** | State, modules, expressions, resource lifecycle |
| **Week 2** | AWS implementation, CI/CD, security, troubleshooting |

---

# Week 1 — Terraform fundamentals and architecture

## Day 1 — Architecture and core components

| Topic | What you should understand |
|-------|----------------------------|
| **Providers** | AWS provider config, aliases, version constraints |
| **Resources** | Lifecycle and dependency ordering |
| **Variables** | Types, defaults, validation |
| **Locals** | Reusable expressions and computed values |
| **Outputs** | Exposing attributes to callers and other modules |
| **Data sources** | Reading existing AWS infrastructure (e.g. AMI) |
| **Dependency graph** | Implicit vs explicit (`depends_on`) dependencies |

**Hands-on (AWS):**

- Configure AWS provider in **ap-south-1**
- EC2 instance + security group
- Variables, locals, outputs
- AMI via **data source**

**Interview:** How does Terraform turn HCL into an execution graph and provision AWS resources?

---

## Day 2 — Modules (highest priority)

**Concepts:**

- Root vs child modules; inputs/outputs; versioning and pinning  
- Reusability, composition, and dependencies  
- Structuring **large** infrastructure repos  

**Target architecture:**

```text
ROOT MODULE          Main orchestration
├── VPC Module       Networking, subnets, routes
├── EKS Module       Kubernetes cluster (optional in lab; design matters for interviews)
├── RDS Module       Database
└── IAM Module       Roles and policies
```

Each module: own `variables`, `resources`, `outputs`.

**Hands-on:**

Build a **reusable VPC module** (VPC, public/private subnets, IGW, NAT, route tables, baseline SGs), then consume it from a **root** configuration.

**Interview:** How would you design Terraform modules for an org with many AWS accounts/projects?

---

## Day 3 — State management and remote backend

| Topic | Master this |
|-------|-------------|
| **Why state** | Mapping config ↔ real resources |
| **Local state** | Limits for teams and CI |
| **Remote state** | S3 backend |
| **Locking** | Prevent concurrent writes (**S3 native lockfile**, Terraform ≥ 1.10) |
| **Encryption** | State at rest (S3/KMS) |
| **Backup** | S3 versioning and recovery |
| **Commands** | `state list`, `show`, `mv`, `rm`, `pull`, `push` |

**Hands-on:**

1. S3 bucket for state — versioning + encryption  
2. S3 remote backend configured  
3. Verify persistence after apply  
4. Simulate **two engineers** applying at once (locking behaviour)

**Interview:** What happens when two people run `terraform apply` at the same time?

> **Note:** Prefer **`use_lockfile = true`** on the S3 backend. DynamoDB table locking is deprecated—know the history, use the modern approach.

---

## Day 4 — Expressions and resource management

**Master:**

- `count`, `for_each`, `dynamic` blocks  
- `depends_on`, `lifecycle` (`create_before_destroy`, `prevent_destroy`, `ignore_changes`)  
- Conditionals and `for` expressions  

**Hands-on:**

- Three EC2 instances with `count`  
- SG rules with `for_each` + dynamic ingress  
- Explicit dependencies + lifecycle protection on a “production” resource  

**Interview:** `for_each` vs `count`? What happens when an item is **removed** from a list?

---

## Day 5 — State migration and troubleshooting

**Master:**

- `terraform import`, import blocks, `moved` blocks  
- Drift detection, state recovery, replacement  
- `taint` / `-replace`, refresh vs plan  
- Sensitive variables and outputs (display vs state storage)

**Hands-on:**

- Create EC2 manually → import  
- Change resource in console → detect drift with `plan`  
- Rename with `moved` block  
- Restore a previous state version from S3  

**Interview:** How do you recover if state is corrupted or deleted?

---

# Week 2 — Production Terraform on AWS

## Day 6 — Multiple environments and workspaces

**Understand:**

- Dev / QA / staging / prod separation  
- Workspaces vs **separate roots**, state files, and accounts  
- Environment `.tfvars`, provider aliases, cross-account `AssumeRole`  

**Recommended layout:**

```text
terraform-project/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── rds/
│   └── iam/
├── environments/
│   ├── dev/       main.tf, variables.tf, terraform.tfvars
│   ├── staging/
│   └── prod/
└── README.md
```

**Hands-on:** Deploy the same VPC module to **dev** and **staging** with different CIDRs and **separate state**.

**Interview:** How do you manage Terraform across dev, staging, and production?

> **Production isolation:** Workspaces alone are weak for prod—prefer separate config, state, and ideally AWS accounts.

---

## Day 7 — Security and secrets

**Master:**

- Sensitive variables/outputs (they **limit display**, not automatic exclusion from state)  
- Secrets Manager, SSM Parameter Store  
- IAM least privilege for Terraform runners  
- KMS, encrypted remote state  
- Secret leakage via plan files, logs, and VCS  

**Hands-on:**

- IAM role for Terraform  
- Read secret from Secrets Manager  
- Encrypted S3 backend; no credentials in Git  

**Interview:** Does `sensitive = true` remove values from state? **No**—it mainly controls CLI/UI redaction; treat state as confidential.

---

## Day 8 — Terraform CI/CD

**Pipeline flow:**

```text
Commit → PR / review → fmt + validate → plan → scan (Checkov/tfsec)
      → manual approval → apply (saved plan)
```

**Commands to own:**

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

**Also understand:** Plan/apply separation, approval gates, plan artifacts, CI IAM roles, state locking in pipelines, failure and rollback.

**Interview:** Design a **production-grade** Terraform pipeline for AWS.

---

## Day 9 — Production troubleshooting scenarios

| Scenario | What you should explain |
|----------|-------------------------|
| State file corrupted | Restore S3 version; validate before apply |
| Resource deleted manually | Drift in plan; import or recreate |
| Apply failed halfway | Compare state vs AWS; targeted fix |
| Two engineers applying | Locking; never force without analysis |
| Resource renamed | `moved` block / state `mv` |
| Resource created manually | Import + align config |
| Module upgrade | Version pin; dev → staging → prod |
| Accidental deletion | `prevent_destroy`; backups |
| Secret in Git | Rotate, purge history, fix pipeline |
| Big replacement | Plan review; lifecycle and dependencies |

**Hands-on:** Deliberately break config/state and recover end-to-end.

---

## Day 10 — Final end-to-end project

**Target architecture:**

| Component | Terraform |
|-----------|-----------|
| VPC | VPC module |
| Networking | Public/private subnets, IGW, NAT |
| Security | Security groups |
| Compute | EC2 |
| Load balancing | Application Load Balancer |
| Database | RDS module (optional—cost control) |
| IAM | Roles and policies |
| State | S3 remote backend |
| Locking | S3 native lockfile |
| Pipeline | Jenkins or GitHub Actions |

**Goal:** Same design in **two environments** using **reusable modules**.

---

# Repository deliverables

Aim for these **five** artifacts in Git by end of Week 8:

| # | Repository / folder | Purpose |
|---|---------------------|---------|
| 1 | `terraform-aws-vpc` | Reusable networking module |
| 2 | `terraform-aws-compute` | EC2 and security groups |
| 3 | `terraform-aws-infrastructure` | Root module composing components |
| 4 | `terraform-environments` | Dev/staging configs + separate state |
| 5 | `terraform-cicd` | Plan, scan, approval, apply pipeline |

---

# Top 10 interview questions

| # | Question | Priority |
|---|----------|----------|
| 1 | How does Terraform state work? | Critical |
| 2 | How do you manage remote state in AWS? | Critical |
| 3 | What happens when two engineers run apply simultaneously? | Critical |
| 4 | How do you design reusable Terraform modules? | Critical |
| 5 | How do you manage multiple environments? | Critical |
| 6 | How do you handle secrets in Terraform? | Critical |
| 7 | How do you detect and resolve infrastructure drift? | High |
| 8 | What is the difference between `count` and `for_each`? | High |
| 9 | How do you import existing AWS infrastructure? | High |
| 10 | How do you upgrade Terraform modules safely in production? | High |

---

# Production safety checklist

1. **Locking:** S3 backend with `use_lockfile = true` (Terraform 1.10+).  
2. **Recovery:** S3 versioning; know `state pull` / `state push`.  
3. **Environments:** Separate roots/state/accounts—not workspaces alone for prod.  
4. **Failed apply:** Inspect plan, state, and AWS **before** re-applying blindly.  
5. **Modules:** Pin versions; promote dev → prod only after plan review.

---

# Official resources

- [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform modules](https://developer.hashicorp.com/terraform/language/modules)
- [State management](https://developer.hashicorp.com/terraform/language/state)
- [S3 backend and locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS provider best practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/)

---

# How to proceed

Do **not** finish all topics in theory before touching AWS.

For each day: **concept → hands-on → production story → interview answer**.

**Success criterion:** You can independently explain and design an AWS deployment using **modules**, **remote state**, **environment separation**, and **CI/CD**—without a command cheat sheet.
