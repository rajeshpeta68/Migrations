# Kubernetes RBAC — DevOps Access Control

## 1. Purpose

Implement production-like access control on the existing three-node AWS Kubernetes cluster. Three ServiceAccounts must receive only the permissions they need. Unauthorized actions must fail.

## 2. Environment

| Item | Requirement |
| --- | --- |
| Cluster | Existing 3-node AWS Kubernetes cluster |
| Namespace | `dev` |
| Identities | ServiceAccounts in `dev`. No human user accounts are required |
| Proof | `kubectl auth can-i` while impersonating each ServiceAccount |

RBAC grants permissions. It has no explicit deny rules. Anything not granted is denied.

## 3. Access policy

| Identity | Allowed | Denied |
| --- | --- | --- |
| `pod-viewer` | Get, list, and watch Pods in `dev` | Create or delete Pods. Read Secrets. Access any other namespace |
| `deployment-manager` | Get, list, watch, create, update, patch, and delete Deployments in `dev` | Read Secrets. Manage resources outside `dev` |
| `cluster-auditor` | Get, list, and watch Pods and Deployments in every namespace | Modify any resource. Read Secrets |

## 4. Permission model

| Question | Object |
| --- | --- |
| Who | ServiceAccount |
| What | Role or ClusterRole: API group, resource, and verbs |
| Where | RoleBinding limits a Role to one namespace. ClusterRoleBinding applies a ClusterRole across the cluster |

A RoleBinding may also reference a ClusterRole. That grants the ClusterRole only inside the binding's namespace.

| Field | Meaning |
| --- | --- |
| `apiGroups: [""]` | Core resources such as Pods, Secrets, and ConfigMaps |
| `apiGroups: ["apps"]` | Deployments and other apps resources |
| `resources` | Which objects the rule covers |
| `verbs` | Which actions are allowed |
| `subjects` | Who receives the permissions |
| `roleRef` | Which Role or ClusterRole is granted |

## 5. Required objects

Deliver these in `rbac-lab.yaml`.

| Object | Name | Scope | Rule |
| --- | --- | --- | --- |
| Namespace | `dev` | Cluster | Holds the ServiceAccounts and namespace Roles |
| ServiceAccount | `pod-viewer` | `dev` | Subject for Pod read access |
| ServiceAccount | `deployment-manager` | `dev` | Subject for Deployment management |
| ServiceAccount | `cluster-auditor` | `dev` | Subject for cluster-wide read access |
| Role | `pod-reader` | `dev` | Core `pods`: `get`, `list`, `watch` |
| RoleBinding | `pod-viewer-binding` | `dev` | Binds `pod-viewer` to `pod-reader` |
| Role | `deployment-manager-role` | `dev` | `apps/deployments`: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` |
| RoleBinding | `deployment-manager-binding` | `dev` | Binds `deployment-manager` to `deployment-manager-role` |
| ClusterRole | `cluster-auditor-role` | Cluster | Core `pods` and `apps/deployments`: `get`, `list`, `watch` |
| ClusterRoleBinding | `cluster-auditor-binding` | Cluster | Binds `dev/cluster-auditor` to `cluster-auditor-role` |

## 6. Acceptance tests

Impersonate each account as `system:serviceaccount:dev:<name>`. The result must match this table.

### pod-viewer

| Check | Namespace | Result |
| --- | --- | --- |
| List Pods | `dev` | yes |
| Get Pods | `dev` | yes |
| Create Pods | `dev` | no |
| Get Secrets | `dev` | no |
| List Pods | `testing` | no |

### deployment-manager

| Check | Namespace | Result |
| --- | --- | --- |
| Create Deployments | `dev` | yes |
| Delete Deployments | `dev` | yes |
| Get Secrets | `dev` | no |
| Create Deployments | `default` | no |

### cluster-auditor

| Check | Namespace | Result |
| --- | --- | --- |
| List Pods | `kube-system` | yes |
| List Deployments | `default` | yes |
| List Pods | `testing` | yes |
| Delete Pods | `dev` | no |
| Get Secrets | `dev` | no |

`testing` is an extra namespace used only to show scope. `pod-viewer` must fail there. `cluster-auditor` must succeed there.

## 7. Further practice

After the tests above pass:

1. Add a ServiceAccount that can get, list, and watch ConfigMaps in `dev` and cannot read Secrets.
2. Change `deployment-manager` so it can scale Deployments and cannot delete them.
3. Bind `cluster-auditor-role` with a RoleBinding to a new ServiceAccount so that account can audit only `dev`.
4. Remove `list` from `pod-reader`, confirm `pod-viewer` is denied, then restore `list`.

## 8. Definition of done

The lab is complete when all of the following are true:

- `dev` contains the three ServiceAccounts, both Roles, and both RoleBindings.
- `cluster-auditor-role` and `cluster-auditor-binding` exist at cluster scope.
- Every check in section 6 returns the listed yes or no.
- `pod-viewer` cannot leave `dev`, and `cluster-auditor` can read Pods in a namespace created after the binding.
- Secrets remain unreadable by all three accounts.
