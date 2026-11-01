# Requirements: Kubernetes NetworkPolicy Mega Hands-on Lab

| Field | Value |
| --- | --- |
| **Title** | Kubernetes NetworkPolicy – Production E-Commerce Scenario |
| **Level** | Intermediate to Advanced |
| **Target cluster** | Existing 3-node kubeadm cluster, Kubernetes **1.33** |
| **Enforcement** | CNI must support Kubernetes NetworkPolicy (not API-only YAML) |

---

## 1. Purpose

Deliver a hands-on lab that simulates a production e-commerce stack on Kubernetes. Participants deploy frontend, backend API, database, and monitoring workloads, then implement **zero-trust** network isolation using `NetworkPolicy` resources so only authorized pod-to-pod (and required DNS) traffic is permitted.

The lab must make enforcement behavior observable: communication works before policies, fails after default-deny, and recovers incrementally as allow policies are applied.

---

## 2. Scope

### In scope

- Namespace creation (`ecommerce`, `monitoring`).
- Application deployments and ClusterIP services with fixed ports.
- Default-deny ingress and egress for both namespaces.
- Explicit allow policies for business traffic and DNS.
- Scripted/manual connectivity tests with expected pass/fail outcomes.
- CNI capability verification before lab work.
- Cleanup by deleting lab namespaces.

### Out of scope

- Installing or upgrading the CNI plugin.
- Production-grade Prometheus, ingress controllers, TLS, or secrets management.
- Persistent volume strategy beyond what the sample Postgres image needs for the exercise.
- Multi-cluster or service mesh policy (Istio/Cilium NetworkPolicy extensions beyond standard Kubernetes API).

---

## 3. Prerequisites

| ID | Requirement |
| --- | --- |
| P1 | `kubectl` configured against the kubeadm cluster control plane. |
| P2 | Cluster has **three worker-ready nodes** (or equivalent lab topology) and core DNS running in `kube-system`. |
| P3 | Participant can run commands on the master (or any node with cluster admin `kubectl` access). |
| P4 | CNI plugin **supports** Kubernetes NetworkPolicy enforcement (e.g. Calico, Cilium). **Flannel alone does not enforce standard NetworkPolicies**—lab isolation will not work without a supporting CNI. |
| P5 | Ability to pull public images: `nginx:1.27`, `hashicorp/http-echo:1.0.0`, `postgres:16-alpine`, `nicolaka/netshoot`. |

### P4 verification (mandatory gate)

Before any policy work, identify the CNI:

```bash
kubectl get pods -n kube-system
kubectl get nodes -o wide
kubectl get ds -n kube-system
```

**Gate:** If NetworkPolicy is not enforced by the CNI, stop and resolve CNI support before claiming lab success.

---

## 4. Business context

An e-commerce application runs in Kubernetes with four logical components:

| Component | Namespace | Role | Listening / service ports (lab) |
| --- | --- | --- | --- |
| **Frontend** | `ecommerce` | User-facing HTTP | Container **80** (Service port 80) |
| **Backend API** | `ecommerce` | API; metrics sidecar | API **8080**, metrics **9090** |
| **PostgreSQL** | `ecommerce` | Data store | **5432** |
| **Monitoring** | `monitoring` | Scrape backend metrics | Client only; target backend **9090** |

Monitoring uses a **netshoot stand-in** pod labeled `app=prometheus`—not a full Prometheus server.

---

## 5. Security and functional requirements

Requirements are numbered for traceability to policies and tests.

| ID | Requirement | Implementation expectation |
| --- | --- | --- |
| **R1** | Create `ecommerce` and `monitoring` namespaces. | Artifact `01-namespaces.yaml`; both namespaces labeled `name: <namespace>`. |
| **R2** | Frontend accepts **ingress TCP 80** from any source (external or in-cluster probes simulating users). | `frontend-ingress` policy on pods `app=frontend`. |
| **R3** | Backend accepts **ingress TCP 8080** only from frontend pods (`app=frontend` in `ecommerce`). | `backend-ingress` first ingress rule; frontend **egress** to backend:8080 must also allow (bidirectional enforcement). |
| **R4** | Database accepts **ingress TCP 5432** only from backend pods (`app=backend` in `ecommerce`). | `database-ingress`; backend **egress** to database:5432 must also allow. |
| **R5** | Monitoring may reach backend **metrics on TCP 9090** only. | Cross-namespace: source `monitoring` namespace + `app=prometheus`; backend ingress on 9090; monitoring egress to backend:9090. |
| **R6** | Frontend must **not** reach the database directly (e.g. TCP 5432). | No frontend egress to database; database ingress limited to backend—verified by negative test. |
| **R7** | Pods must **not** communicate freely with arbitrary pods. | **Default deny** all ingress and egress in `ecommerce` and `monitoring` via empty `podSelector: {}`; only explicit allows permit traffic. |
| **R8** | Allow **DNS** (UDP/TCP **53**) to cluster DNS (typically `kube-dns` in `kube-system`). | `allow-dns` egress policies; selectors adjusted if NodeLocal DNSCache or different labels are used. |
| **R9** | Demonstrate that **unauthorized** communication is blocked. | Negative tests: frontend→database, unauthorized pod→backend, monitoring→backend API port 8080. |

### Policy model constraints (non-negotiable)

1. NetworkPolicy is an **allow-list**; there are no explicit “deny” rules—deny comes from default-deny plus missing allows.
2. For pod-to-pod traffic, **both** source egress and destination ingress must permit the flow.
3. Enforcement is performed by the **CNI**, not the Kubernetes API server.

### Selector semantics (documentation requirement)

When `namespaceSelector` and `podSelector` appear **in the same** `from` or `to` list entry, they combine with **AND**. Separate list entries combine with **OR**. Lab materials must call this out for monitoring→backend rules.

---

## 6. Deliverables (implementation artifacts)

| Order | File | Must achieve |
| --- | --- | --- |
| 1 | `01-namespaces.yaml` | R1 |
| 2 | `02-applications.yaml` | Deploy frontend (2 replicas), backend (2 replicas, API + metrics containers), database (1 replica), prometheus stand-in; ClusterIP services as specified |
| 3 | `03-default-deny.yaml` | R7 in both namespaces |
| 4 | `04-allow-dns.yaml` | R8 in both namespaces |
| 5 | `05-application-policies.yaml` | R2–R6, R5 cross-namespace rules |

### Application specification (`02-applications.yaml`)

| Workload | Namespace | Labels | Image / notes |
| --- | --- | --- | --- |
| frontend | ecommerce | `app=frontend` | `nginx:1.27`, port 80 |
| backend | ecommerce | `app=backend` | `http-echo` API `:8080`, metrics `:9090` |
| database | ecommerce | `app=database` | `postgres:16-alpine`, env `POSTGRES_PASSWORD=labpassword`, `POSTGRES_DB=ecommerce`, port 5432 |
| prometheus (test) | monitoring | `app=prometheus` | `nicolaka/netshoot`, `sleep infinity` |

Services: `frontend:80`, `backend:8080` (api) + `9090` (metrics), `database:5432`.

---

## 7. Recommended lab flow (learning requirement)

Participants **should not** only apply all YAML at once. Required pedagogical sequence:

1. Deploy applications **without** NetworkPolicies and confirm broad pod-to-pod connectivity.
2. Apply **default-deny** and observe failures.
3. Add **DNS** allow, then **application** policies one group at a time, observing which paths recover.

This sequence is part of the lab’s success criteria for understanding, not optional fluff.

---

## 8. Verification and acceptance criteria

### 8.1 Readiness checks

After each apply stage:

```bash
kubectl get pods -n ecommerce
kubectl get pods -n monitoring
kubectl get svc -A
kubectl get networkpolicy -A
```

DNS pod labels in `kube-system` must be validated before finalizing `04-allow-dns.yaml`:

```bash
kubectl get pods -n kube-system --show-labels
```

### 8.2 Test harness

Create temporary debug pods:

- `frontend-test` — labels `app=frontend`
- `backend-test` — labels `app=backend`
- `unauthorized-test` — labels `app=unauthorized`

All use image `nicolaka/netshoot`, namespace `ecommerce`, command `sleep infinity`.

### 8.3 Acceptance matrix (R9)

| # | Source | Destination | Port / protocol | Expected |
| --- | --- | --- | --- | --- |
| T1 | frontend-test | backend Service | TCP 8080 (HTTP) | **Allow** — response contains `Backend API OK` |
| T2 | frontend-test | database Service | TCP 5432 | **Deny** |
| T3 | backend-test | database Service | TCP 5432 | **Allow** |
| T4 | unauthorized-test | backend Service | TCP 8080 | **Deny** |
| T5 | prometheus (monitoring) | `backend.ecommerce.svc.cluster.local` | TCP 9090 | **Allow** — metrics text OK |
| T6 | prometheus (monitoring) | `backend.ecommerce.svc.cluster.local` | TCP 8080 | **Deny** |
| T7 | frontend-test | DNS | UDP/TCP 53 (`nslookup backend.ecommerce.svc.cluster.local`) | **Allow** |

Example probes:

```bash
kubectl exec -it frontend-test -n ecommerce -- curl --connect-timeout 3 http://backend:8080
kubectl exec -it frontend-test -n ecommerce -- nc -zvw3 database 5432
kubectl exec -it backend-test -n ecommerce -- nc -zvw3 database 5432
kubectl exec -it unauthorized-test -n ecommerce -- curl --connect-timeout 3 http://backend:8080
kubectl exec -it prometheus -n monitoring -- curl --connect-timeout 3 http://backend.ecommerce.svc.cluster.local:9090
kubectl exec -it prometheus -n monitoring -- curl --connect-timeout 3 http://backend.ecommerce.svc.cluster.local:8080
kubectl exec -it frontend-test -n ecommerce -- nslookup backend.ecommerce.svc.cluster.local
```

**Lab passes** when all rows match expectations on a NetworkPolicy-capable CNI.

---

## 9. Optional advanced requirements (post-lab)

These are **not** required for baseline acceptance; they extend interview-level practice:

1. Frontend egress to external HTTPS (**TCP 443** only), not blanket egress.
2. Database ingress restricted to a **specific namespace** label (beyond pod labels).
3. Backend talks to **Redis :6379** instead of direct database (redesign policies).
4. Frontend→backend allowed but **replica count** constrained (policy or deployment coupling).
5. Default-deny **ingress only**, egress left open (contrast with zero-trust baseline).
6. Backend egress limited to **database + DNS** only.
7. Ingress from a specific **CIDR** via `ipBlock`.
8. Written explanation: two NetworkPolicies selecting the same pod → allowed traffic is **union** of policies.

---

## 10. Cleanup

```bash
kubectl delete namespace ecommerce monitoring
```

Removes workloads, services, and all namespaced NetworkPolicies.

---

## 11. References

- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- CNI vendor docs for policy support (Calico, Cilium, etc.)

---

## 12. Requirements traceability summary

| Requirement | Primary artifacts | Verified by |
| --- | --- | --- |
| R1 | `01-namespaces.yaml` | `kubectl get ns` |
| R2–R6, R5 | `05-application-policies.yaml` | T1–T6 |
| R7 | `03-default-deny.yaml` | Behavior before allows; T2, T4, T6 |
| R8 | `04-allow-dns.yaml` | T7 |
| R9 | Full policy set + test pods | T1–T7 matrix |
| P4 | Pre-lab CNI check | Documented CNI name; policies affect traffic |
