# AWS & Kubernetes — Interview Revision Sheet

**How to use this doc:** Revise from a **functional, architecture, and troubleshooting** angle—not definitions. For each topic, you should be able to explain **what it does**, **why we use it**, and **where it sits in production** (1–2 lines each).

**Your lab context:** You run a **3-node kubeadm cluster (K8s 1.33)**. On AWS, prioritise **EKS architecture, IAM integration, VPC networking, and managed node groups** over re-learning basic Kubernetes mechanics.

---

## Revision method (≈13 min per topic block)

| Step | Time | Do this |
|------|------|---------|
| **Concept** | 2 min | Explain what it is and why it exists—no notes. |
| **Architecture** | 3 min | Place it in a real AWS/EKS or on-prem K8s design. |
| **Troubleshooting** | 3 min | List what you’d check when it breaks in prod. |
| **Hands-on** | 5 min | Run one command or change one config in your lab. |

---

## Progress tracker

Tick when you can explain the section **without notes**:

- [ ] AWS IAM
- [ ] AWS Networking
- [ ] AWS Compute
- [ ] AWS Storage & Database
- [ ] AWS Security & Monitoring
- [ ] Kubernetes Architecture
- [ ] Kubernetes Workloads
- [ ] Kubernetes Scaling & Scheduling
- [ ] Kubernetes Security & Helm

**Priority (Senior DevOps / SRE / Platform Architect):**

1. AWS IAM + EKS security  
2. VPC networking + ALB/NLB troubleshooting  
3. Kubernetes architecture + scheduling  
4. Kubernetes storage + networking  
5. Helm + production deployment strategies  

---

# Phase 1 — AWS Deep Dive

## 1. IAM (Identity and Access Management)

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **Users vs Roles** | **What:** Users = long-lived identities; roles = temporary credentials via STS. **Why:** Roles avoid static keys on servers and enable federation. **Where:** Humans use IAM users/SSO; apps, Lambda, and EC2/EKS use roles. |
| **Policies** | **What:** JSON allow/deny for actions on resources. **Why:** Central, auditable permission model. **Where:** Attached to roles/users/groups; evaluated on every API call. |
| **Resource vs Identity Policies** | **What:** Identity policies on principals; resource policies on resources (e.g. S3 bucket policy). **Why:** Some services (S3, KMS, SQS) need resource-side trust. **Where:** Cross-account S3 access often combines role + bucket policy. |
| **AssumeRole** | **What:** Switch to another role’s permissions for a session. **Why:** Least privilege and cross-account without shared passwords. **Where:** CI/CD, cross-account admin, pod → AWS API via IRSA/Pod Identity. |
| **STS** | **What:** Issues temporary access keys, session tokens, and role credentials. **Why:** Short-lived creds reduce blast radius. **Where:** Behind every role assumption and federated login. |
| **Cross-account Access** | **What:** Account A assumes a role in account B via trust policy. **Why:** Shared services, logging, security tooling across accounts. **Where:** Central audit account, shared networking hub, multi-account landing zones. |
| **IAM Conditions** | **What:** Extra gates (IP, MFA, `aws:RequestedRegion`, tags). **Why:** Context-aware least privilege. **Where:** “Only from corporate IP”, “only in eu-west-1”, “only if resource tag matches”. |
| **Least Privilege** | **What:** Minimum permissions for the task. **Why:** Limits damage from compromise or misconfiguration. **Where:** Policy reviews, permission boundaries, scoped roles per workload. |
| **IRSA** | **What:** EKS maps K8s ServiceAccount → IAM role (OIDC trust). **Why:** Pods call AWS APIs without embedded access keys. **Where:** App reads S3, SQS, DynamoDB from pods on EKS. |
| **EKS Pod Identity** | **What:** AWS-managed association of ServiceAccount to IAM role (simpler than classic IRSA setup). **Why:** Same goal as IRSA with easier ops on newer EKS. **Where:** New EKS workloads needing AWS API access from pods. |

**Troubleshooting lens:** Access denied → policy simulator, explicit Deny, SCP, permission boundary, session policy, trust policy, wrong role ARN on SA annotation.

---

## 2. Networking

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **VPC** | **What:** Isolated virtual network (CIDR, subnets, routing). **Why:** Network segmentation and IP planning per env/account. **Where:** Every AWS deployment; EKS cluster lives in VPC subnets. |
| **Public Subnet** | **What:** Route to Internet Gateway (IGW). **Why:** Ingress from internet or NAT placement. **Where:** ALB/NLB faces, bastion, NAT Gateway (not app DBs). |
| **Private Subnet** | **What:** No direct IGW route; outbound via NAT or endpoints. **Why:** Hide workloads from inbound internet. **Where:** App tiers, EKS nodes, RDS, internal APIs. |
| **Route Tables** | **What:** Per-subnet routing (local, IGW, NAT, TGW, endpoints). **Why:** Controls which traffic leaves the subnet and how. **Where:** Wrong route = no internet or no private AWS API access. |
| **Internet Gateway (IGW)** | **What:** VPC ↔ public internet for resources with public IPs. **Why:** Public-facing and NAT upstream path. **Where:** Edge of VPC; paired with public subnets. |
| **NAT Gateway** | **What:** Outbound-only internet from private subnets. **Why:** Patch, pull images, external APIs without public IPs on apps. **Where:** HA: NAT per AZ in public subnet; cost/transfer watch item. |
| **NACL** | **What:** Stateless subnet firewall (allow/deny lists). **Why:** Optional extra layer; coarse blocking. **Where:** Less common than SGs; can block unexpected CIDRs at subnet edge. |
| **Security Groups** | **What:** Stateful ENI/instance firewall. **Why:** Default “who can talk to my app port”. **Where:** ALB → app SG, app → DB SG, EKS node SG, 502/debug often SG mismatch. |
| **VPC Endpoints** | **What:** Private path to AWS APIs (Gateway e.g. S3/DynamoDB; Interface e.g. ECR, STS). **Why:** No internet/NAT for AWS traffic; tighter compliance. **Where:** Private EKS pulling from ECR, EC2 → S3 without public route. |
| **Transit Gateway** | **What:** Hub connecting VPCs and on-prem VPN/DX. **Why:** Scale beyond VPC peering mesh. **Where:** Multi-VPC enterprises, shared services VPC. |
| **DNS (Route 53)** | **What:** Authoritative DNS, health checks, routing policies. **Why:** User-friendly names, failover, geo routing. **Where:** Customer domain → ALB/CloudFront; internal zones for service discovery. |
| **ALB** | **What:** L7 HTTP/HTTPS routing (host/path, rules, WAF integration). **Why:** Web apps, TLS termination, path-based microservices. **Where:** Internet → EKS Ingress (AWS LB Controller) or EC2 target groups. |
| **NLB** | **What:** L4 TCP/UDP, high performance, static IPs. **Why:** Non-HTTP, extreme throughput, preserve client IP. **Where:** Gaming, TLS passthrough, legacy TCP services. |

**Troubleshooting lens:** Connectivity → route table, SG, NACL, DNS resolution, endpoint policy, target group health, wrong subnet tier.

---

## 3. Compute

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **EC2** | **What:** Virtual machines in AWS. **Why:** Full control of OS, licensing, legacy stacks. **Where:** Bastion, custom middleware, non-containerised workloads. |
| **Auto Scaling Group (ASG)** | **What:** Maintains desired capacity with health checks and policies. **Why:** HA and cost vs fixed fleet. **Where:** Web tier behind ALB; replaces unhealthy instances. |
| **AMI** | **What:** Bootable image snapshot. **Why:** Repeatable, hardened golden images. **Where:** ASG launch template source; patch pipeline builds new AMIs. |
| **Launch Template** | **What:** Versioned EC2 launch config (AMI, type, SG, userdata). **Why:** Safe rollouts and rollback of launch params. **Where:** ASG, mixed instance policies, Spot + On-Demand. |
| **Spot Instances** | **What:** Discount capacity with interruption notice. **Why:** Cost for fault-tolerant/batch work. **Where:** CI workers, render farms—not sole DB node without design. |
| **ECS** | **What:** AWS container orchestration (tasks/services on EC2 or Fargate). **Why:** Simpler than K8s when AWS-native ops suffice. **Where:** Microservices on Fargate, AWS-centric teams. |
| **EKS** | **What:** Managed Kubernetes control plane on AWS. **Why:** Standard K8s API with AWS integration (LB, IAM, EBS CSI). **Where:** Platform teams, multi-cloud skill reuse; compare to your kubeadm lab (you manage control plane). |

**EKS focus vs your kubeadm lab:** Control plane ownership, IRSA/Pod Identity, AWS Load Balancer Controller, managed node groups/Fargate, VPC CNI, and cluster endpoint access (public/private).

---

## 4. Storage

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **S3** | **What:** Object storage (durability, versioning, lifecycle). **Why:** Cheap durable blobs, static assets, backups, data lake. **Where:** Artifacts, logs archive, static site, ML datasets. |
| **EBS** | **What:** Block volumes attached to EC2 (or PV via CSI on EKS). **Why:** Persistent disk for OS and databases on a single instance. **Where:** RDS alternative on EC2; EKS `gp3` volumes for StatefulSets. |
| **EFS** | **What:** Shared NFS file system. **Why:** Multiple instances/pods need same files. **Where:** Content sharing, legacy apps needing RWX on K8s (EFS CSI). |

---

## 5. Database

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **RDS** | **What:** Managed RDBMS (MySQL, Postgres, etc.) with backups, Multi-AZ. **Why:** Ops offload for relational data. **Where:** Standard OLTP behind private subnets; app SG → DB SG only. |
| **Aurora** | **What:** AWS-optimised distributed storage, MySQL/Postgres compatible. **Why:** Higher scale/HA than single-instance RDS for many workloads. **Where:** High-traffic SaaS core database. |
| **DynamoDB** | **What:** Managed NoSQL key-value/document, on-demand scaling. **Why:** Predictable latency at scale without shard ops. **Where:** Session store, gaming leaderboards, event sourcing at huge scale. |

---

## 6. Security

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **KMS** | **What:** Customer-managed keys for encrypt/decrypt across AWS. **Why:** Central key policy and audit for encryption at rest. **Where:** EBS, S3 SSE-KMS, Secrets Manager, EKS secrets encryption. |
| **Secrets Manager** | **What:** Store and rotate secrets (DB passwords, API keys). **Why:** No secrets in git or plain Parameter Store for creds. **Where:** App bootstraps via IAM role; rotation Lambda. |
| **Parameter Store** | **What:** Hierarchical config (plain or SecureString). **Why:** Non-secret and simple secret config with IAM. **Where:** Feature flags, paths per env; cheaper than Secrets Manager for some cases. |
| **CloudTrail** | **What:** Logs AWS API calls (who, what, when, source). **Why:** Audit, forensics, compliance. **Where:** Org trail to central S3; investigate “who deleted that SG rule”. |

---

## 7. Monitoring

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **CloudWatch** | **What:** Metrics, logs, alarms, dashboards. **Why:** Operational health and automated response. **Where:** CPU/latency alarms, log insights on app logs, EKS Container Insights. |
| **CloudTrail** | *(See Security)* | **Interview distinction:** CloudTrail = **who did what API**; not performance metrics. |
| **VPC Flow Logs** | **What:** Metadata of accepted/rejected IP flows (not packet payload). **Why:** Network forensics and “why can’t A reach B”. **Where:** After SG looks correct but traffic still blocked or asymmetric routing suspected. |

| Signal | Answers |
|--------|---------|
| **CloudWatch** | How are resources/apps **performing**? |
| **CloudTrail** | What **API actions** were performed? |
| **VPC Flow Logs** | What **network traffic** flowed (allow/reject)? |

---

## AWS — Functional interview scenarios

| Question | Cover in your answer |
|----------|------------------------|
| **Design a highly available application on AWS** | Multi-AZ VPC, public ALB, app in private subnets (ASG or EKS), Multi-AZ RDS/Aurora, Route 53 health/failover, backups, autoscaling. |
| **How would you secure an EKS cluster?** | Private API endpoint (or restricted public), RBAC, IRSA/Pod Identity, Network Policies, encrypt secrets (KMS), least-privilege node/instance roles, SGs, audit (CloudTrail/control plane logs). |
| **How does a pod access S3 without AWS credentials?** | ServiceAccount → IAM role (IRSA or Pod Identity) → STS temporary creds injected; no keys in image/env. |
| **How would you design cross-account AWS access?** | Role in target account, trust policy for source principal, least-privilege policy on role, AssumeRole from CI or hub account. |
| **ALB returns 502 — troubleshoot?** | Target health (unhealthy), wrong port/path, app crash, timeout, SG (ALB → target), TLS/http mismatch, idle timeout. |
| **EC2 cannot access S3 — check?** | IAM role/policy, bucket policy, Block Public Access (if relevant), VPC endpoint + endpoint policy, route to gateway endpoint, DNS, proxy. |
| **Private subnet EC2 needs internet** | Private subnet → route `0.0.0.0/0` → NAT GW in **public** subnet → IGW; or use VPC endpoints for AWS APIs only. |
| **Reduce AWS cost** | Rightsize, Spot where safe, Savings Plans/RI, S3 lifecycle, scale down idle, delete unused EIPs/NAT/LBs, optimise cross-AZ/data transfer. |

---

# Phase 2 — Kubernetes

## 1. Architecture (control plane & node)

| Component | What / why / where (production) |
|-----------|----------------------------------|
| **API Server** | **What:** Front door for all cluster changes and reads. **Why:** Authn/authz, validation, persistence to etcd. **Where:** Every `kubectl`, controller, scheduler call; protect with RBAC and network. |
| **Scheduler** | **What:** Binds pods to nodes. **Why:** Respect resources, affinity, taints, priorities. **Where:** Pending pods → check events “failed scheduling”. |
| **Controller Manager** | **What:** Reconciliation loops (Deployment, Node, etc.). **Why:** Actual state matches desired YAML. **Where:** Replica mismatch, Node NotReady handling. |
| **etcd** | **What:** Consistent store of cluster state. **Why:** Source of truth for K8s objects. **Where:** Backup/restore DR; latency affects API; kubeadm: you care about etcd on control plane. |
| **kubelet** | **What:** Node agent: runs pods, reports status, mounts volumes. **Why:** Bridge API intent to container runtime. **Where:** CrashLoop, image pull, volume mount errors on node. |
| **Container Runtime** | **What:** containerd/CRI-O runs containers. **Why:** Images and cgroup/network namespace for pods. **Where:** ImagePullBackOff, OOM at runtime level. |
| **kube-proxy** | **What:** Programs Service iptables/IPVS rules to endpoints. **Why:** ClusterIP/NodePort reach pod IPs. **Where:** Service works but no endpoints → selector mismatch. |

---

## 2. Application traffic flow (typical on AWS EKS)

```
Route 53  →  DNS
    ↓
ALB       →  External L7 load balancing (often via AWS Load Balancer Controller)
    ↓
Ingress   →  Host/path rules to Services
    ↓
Service   →  Stable ClusterIP/DNS + load balance to pods
    ↓
Pods      →  Workloads (your ecommerce frontend, etc.)
    ↓
Containers → Processes (nginx, app server)
```

**Production note:** Ingress needs an **Ingress Controller**; on AWS, ALB is commonly provisioned by **AWS Load Balancer Controller**. Your lab may use **NodePort** (e.g. `:30080`) without Ingress—same pod/Service ideas, different edge.

---

## 3. Workloads and resources

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **Pod** | **What:** One or more containers sharing network/volumes. **Why:** Atomic schedulable unit. **Where:** Always debug at pod/events/logs level. |
| **Deployment** | **What:** Declarative stateless app + rolling updates. **Why:** Safe releases and rollbacks. **Where:** Web APIs, frontends (your Helm `replicaCount: 3`). |
| **ReplicaSet** | **What:** Keeps N pod replicas; owned by Deployment. **Why:** Separation of scaling from rollout strategy. **Where:** Rarely created directly. |
| **StatefulSet** | **What:** Stable network ID + ordered rollout + PVCs. **Why:** Databases, Kafka, clustered software needing identity. **Where:** Postgres in K8s (with ops caution) vs managed RDS. |
| **DaemonSet** | **What:** One pod per (matching) node. **Why:** Node-level agents. **Where:** CNI, node exporter, log collectors (Fluent Bit). |
| **Job / CronJob** | **What:** Run-to-completion / scheduled jobs. **Why:** Batch, backups, reports. **Where:** DB dump Job, nightly CronJob. |
| **Service** | **What:** Stable VIP/DNS to dynamic pod IPs. **Why:** Decouple clients from pod churn. **Where:** ClusterIP internal; NodePort/LB external (your NodePort 30080). |
| **Ingress** | **What:** HTTP routing rules to Services. **Why:** Single entry, TLS, path-based routing. **Where:** Public web apps on EKS with ALB. |
| **ConfigMap / Secret** | **What:** Non-sensitive vs sensitive config outside image. **Why:** Same image across envs; Secret base64 at rest (encrypt at rest in prod). **Where:** App config, TLS certs, DB URLs. |
| **PVC / PV / StorageClass** | **What:** Claim → bound volume → provisioner class. **Why:** Persistent data survives pod restart. **Where:** EBS CSI `gp3`, EFS for RWX; check binding and CSI driver. |

---

## 4. Scaling and resource management

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **HPA** | **What:** Scales Deployment replicas on metrics. **Why:** Match load without manual replica edits. **Where:** CPU/memory/custom metrics; needs metrics-server or Prometheus adapter. |
| **PDB** | **What:** Min available / max unavailable during evictions. **Why:** Avoid draining all replicas during node upgrade. **Where:** Required for HA apps during cluster maintenance. |
| **Requests / Limits** | **What:** Scheduler uses requests; limits cap usage (CPU throttle, OOM kill). **Why:** Noisy neighbour protection and fair scheduling. **Where:** Your Helm chart `resources`; missing requests → poor scheduling/QoS. |
| **QoS** | **What:** Guaranteed / Burstable / BestEffort from requests/limits. **Why:** Eviction order under node pressure. **Where:** Prod critical pods → Guaranteed where possible. |

---

## 5. Scheduling

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **Taints / Tolerations** | **What:** Taint repels pods unless tolerated. **Why:** Dedicated nodes (GPU, system, ingress). **Where:** Pod pending → check taints on node vs tolerations on pod. |
| **Node Affinity** | **What:** Prefer/require nodes with labels. **Why:** Place workloads on correct hardware/zone pool. **Where:** “Only on `workload=compute` nodes”. |
| **Pod Affinity / Anti-Affinity** | **What:** Co-locate or spread pods relative to other pods. **Why:** Locality vs blast-radius reduction. **Where:** Anti-affinity spreads replicas across nodes/AZs. |
| **Topology Spread** | **What:** Even distribution across domains (zone, node). **Why:** AZ failure doesn’t wipe all replicas. **Where:** `topology.kubernetes.io/zone` spread constraints on Deployments. |

---

## 6. Security and networking

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **RBAC** | **What:** Roles/ClusterRoles bound to users/SAs/groups. **Why:** Least privilege in multi-team clusters. **Where:** CI deploy SA, read-only dev, break-glass cluster-admin audit. |
| **NetworkPolicy** | **What:** Pod-level allow/deny rules (ingress/egress). **Why:** Default-allow K8s networking is too open for zero-trust. **Where:** Your **ecommerce lab**: frontend → backend only; CNI must enforce (Calico/Cilium—not all CNIs). |
| **ServiceAccount** | **What:** Identity for pod → API or cloud IAM binding. **Why:** Per-app credentials; IRSA/Pod Identity on EKS. **Where:** Helm `serviceAccount.create`; missing values → `helm lint` nil pointer (fixed in your chart). |

---

## 7. Helm

| Concept | What / why / where (production) |
|---------|----------------------------------|
| **Helm** | **What:** Package manager for K8s apps (charts + releases). **Why:** Parameterise and version deployments. **Where:** CI `helm upgrade --install` per env values file. |
| **Chart / Release** | **What:** Template bundle vs installed instance in a namespace. **Why:** Same chart, many envs (dev/stage/prod releases). **Where:** `ecommerce` chart → release name `ecommerce` in `ecommerce` ns. |
| **values.yaml** | **What:** Default config (replicas, image, ports, resources). **Why:** Avoid editing templates per environment. **Where:** Override with `-f prod.yaml` or `--set`. |
| **templates/** | **What:** Manifests with Go templating. **Why:** DRY labels, names, optional resources (SA, Ingress). **Where:** Ensure all `.Values.*` keys exist or use `default` to pass `helm lint`. |
| **Chart.yaml** | **What:** Chart metadata and version. **Why:** Dependency and versioning discipline. **Where:** Semver chart version vs `appVersion` (container/app version). |
| **install / upgrade / rollback / history** | **What:** Lifecycle commands. **Why:** Safe change and revert. **Where:** Bad deploy → `helm history` + `helm rollback`; compare revision diff. |

**Lab tie-in:** `helm lint ./ecommerce` → fix missing `serviceAccount` in values → `helm install` → `kubectl get pods,svc -n ecommerce` → NodePort **30080**.

---

## Kubernetes — Functional interview scenarios

| Question | Cover in your answer |
|----------|------------------------|
| **Pod stuck Pending** | Resources, node selector/affinity, taints, PVC unbound, quota, scheduler events. |
| **CrashLoopBackOff** | `kubectl logs`, probes too aggressive, missing config/Secret, wrong command. |
| **Service has no endpoints** | Selector labels mismatch pod labels; pods not Ready. |
| **Ingress not working** | Controller installed?, correct class annotation, backend Service port, DNS/TLS cert. |
| **NetworkPolicy blocking traffic** | Policy selectors, namespace labels, egress to DNS/kube-system, CNI support. |
| **HPA not scaling** | metrics-server, requests set on pods, target metrics available, HPA object status. |
| **Helm deploy failed** | `helm lint`, template render errors, hooks, RBAC for release SA, `--dry-run`. |

---

## Quick command cheat sheet (hands-on revision)

```bash
# AWS-ish mental model on lab
kubectl get nodes,pods,svc,ingress,networkpolicies -A
kubectl describe pod <name> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl get events -n <ns> --sort-by='.lastTimestamp'

# Helm
helm lint ./ecommerce
helm install ecommerce ./ecommerce -n ecommerce --create-namespace --dry-run
helm upgrade --install ecommerce ./ecommerce -n ecommerce -f values-prod.yaml
helm history ecommerce -n ecommerce
helm rollback ecommerce <rev> -n ecommerce
```

---

*Last updated for interview revision — connect every row to one story from your kubeadm cluster or a past production incident.*
