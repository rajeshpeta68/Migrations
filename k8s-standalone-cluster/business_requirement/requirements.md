# Employee Portal — Kubernetes Advanced Lab

## 1. Purpose

Build an Employee Portal platform on the existing 3-node AWS Kubernetes cluster. One exercise must cover all eight topics together:

- StorageClass
- Horizontal Pod Autoscaler (HPA)
- Pod Disruption Budget (PDB)
- Resource requests and limits
- Quality of Service (QoS)
- Taints and tolerations
- Node affinity
- Pod affinity

## 2. Environment

| Item | Requirement |
| --- | --- |
| Cluster | Existing 3-node AWS Kubernetes cluster: 1 control plane, 2 workers |
| Namespace | `advanced-lab` |
| Active context | Current kubectl context set to `advanced-lab` |
| Metrics | A working Metrics Server, required for HPA and `kubectl top` |
| Storage | An existing default StorageClass, or the AWS EBS CSI driver with IAM permission to provision volumes |

With only two workers, the frontend is intentionally pinned to one node. That is for learning placement rules. It is not a highly available layout. Extra worker capacity is required before practicing production-style spreading and node maintenance.

## 3. Business requirements

The application must scale during peak traffic, keep a minimum number of replicas available during maintenance, use persistent storage, and run on the correct nodes.

| Topic | Requirement |
| --- | --- |
| StorageClass | Dynamically provision persistent storage for application data |
| HPA | Scale the frontend from 2 to 6 replicas when CPU utilization exceeds 60% |
| PDB | Keep at least 2 frontend Pods available during voluntary disruptions |
| Requests and limits | Set CPU and memory requests and limits on each container |
| QoS | Run Guaranteed, Burstable, and BestEffort Pods and show the class Kubernetes assigns |
| Taints and tolerations | Reserve one worker for special workloads |
| Node affinity | Schedule the frontend only on the application worker |
| Pod affinity | Schedule the API on the same worker as the frontend when possible |

## 4. Node preparation

Identify real node names with `kubectl get nodes -o wide`. Replace the placeholders below with those names.

| Node | Label | Taint |
| --- | --- | --- |
| Worker 1 | `workload=app` | None |
| Worker 2 | `workload=special` | `dedicated=special:NoSchedule` |

Expected placement:

- Frontend Pods run only on the application worker.
- A Pod that tolerates `dedicated=special:NoSchedule` may run on the special worker.
- Ordinary Pods must not be scheduled onto the tainted worker.

## 5. Functional requirements

### 5.1 Storage

Provide dynamic persistent storage for application data.

| Item | Requirement |
| --- | --- |
| StorageClass | Use the cluster default if it can provision volumes. Otherwise create `advanced-gp3` with provisioner `ebs.csi.aws.com`, volume type `gp3`, `volumeBindingMode: WaitForFirstConsumer`, and `allowVolumeExpansion: true` |
| PVC | Name `employee-data` in `advanced-lab`. Access mode `ReadWriteOnce`. Request `2Gi`. Storage class `advanced-gp3` when that class is created |
| Consumer | Pod `storage-check` mounts the PVC at `/data` and appends the current date to `/data/test.txt` every 10 seconds |
| Binding | With `WaitForFirstConsumer`, the PVC may stay `Pending` until `storage-check` is scheduled |

Acceptance:

- The StorageClass exists and a PV is provisioned dynamically.
- `employee-data` becomes `Bound`.
- Data written to `/data/test.txt` is still present after `storage-check` is deleted and recreated on the same PVC.

### 5.2 Frontend, HPA, and PDB

The frontend is the main workload. HPA scales it on CPU. The PDB protects it during voluntary disruption.

| Item | Requirement |
| --- | --- |
| Workload | Deployment `frontend`, label `app=frontend`, initial replicas `2` |
| Image | `registry.k8s.io/hpa-example`, container port `80` |
| Service | ClusterIP `frontend`, port `80`, target port `80` |
| Node affinity | Required. Node label `workload` In `app` |
| CPU | Request `200m`, limit `500m` |
| Memory | Request `128Mi`, limit `256Mi` |
| HPA | `frontend-hpa`. Target Deployment `frontend`. Minimum `2`, maximum `6`. CPU average utilization `60%` |
| PDB | `frontend-pdb`. Selector `app=frontend`. `minAvailable: 2` |

Behavior to demonstrate:

- Requests are the scheduling and HPA baseline. HPA utilization is measured against the CPU request.
- The CPU limit throttles the container. A memory limit can end the container with an OOM kill.
- HPA adds replicas when average CPU utilization stays above 60%, and removes replicas when utilization falls and the scale-down policy allows it.
- The PDB blocks voluntary eviction that would leave fewer than 2 frontend Pods available. It does not stop all Pod failures, and it does not block a Deployment rollout the way an eviction does.

Load test: run a Pod that continuously requests `http://frontend.advanced-lab.svc.cluster.local`, watch `frontend-hpa` and the Deployment, then delete the generator. Scaling is not required to reach 6 replicas. The result depends on measured CPU, free capacity on the application worker, and metric scrape interval.

### 5.3 QoS classes

Run three Pods and show the QoS class Kubernetes derives from requests and limits.

| Pod | Requests | Limits | Expected QoS |
| --- | --- | --- | --- |
| `qos-guaranteed` | CPU `200m`, memory `128Mi` | CPU `200m`, memory `128Mi` | Guaranteed |
| `qos-burstable` | CPU `100m`, memory `64Mi` | CPU `500m`, memory `256Mi` | Burstable |
| `qos-besteffort` | None | None | BestEffort |

All three use `busybox:1.36` and sleep so they stay running. Guaranteed requires every container to set CPU and memory requests and limits, with each request equal to its limit.

Optional check: set the Guaranteed Pod CPU request to `100m` and leave its CPU limit at `200m`. After reapply, its class must change to Burstable.

### 5.4 Taints and tolerations

Worker 2 carries `dedicated=special:NoSchedule`.

| Item | Requirement |
| --- | --- |
| Pod | `special-worker-pod` |
| Toleration | Key `dedicated`, operator `Equal`, value `special`, effect `NoSchedule` |
| Resources | CPU request `50m`, memory request `32Mi` |

A toleration allows scheduling onto the tainted node. It does not force the Pod there. To require Worker 2, add required node affinity for `workload=special` as well as the toleration.

### 5.5 Pod affinity

The API must run on the same worker as the frontend whenever the rule is required.

| Item | Requirement |
| --- | --- |
| Workload | Deployment `api`, label `app=api`, replicas `1` |
| Image | `nginx:1.28`, container port `80` |
| Service | Name `api`, port `8080`, target port `80` |
| Affinity | Required pod affinity. Match Pods labeled `app=frontend`. Topology key `kubernetes.io/hostname` |
| CPU | Request `100m`, limit `300m` |
| Memory | Request `64Mi`, limit `128Mi` |

Acceptance: the API Pod and the frontend Pods show the same node name.

Optional check: change the rule to `preferredDuringSchedulingIgnoredDuringExecution`. The scheduler should prefer the frontend node and may place the API elsewhere if that node cannot take it.

## 6. Deliverables

| File | Contents |
| --- | --- |
| `01-storage.yaml` | StorageClass, if needed, plus `employee-data` and `storage-check` |
| `02-frontend.yaml` | Frontend Deployment, Service, HPA, and PDB |
| `03-qos.yaml` | Guaranteed, Burstable, and BestEffort Pods |
| `04-special-pod.yaml` | Pod with the special-worker toleration |
| `05-api-affinity.yaml` | API Deployment, Service, and pod affinity |

## 7. Definition of done

The lab is complete when all of the following are true:

- A StorageClass dynamically provisions `employee-data`, and data survives Pod recreation.
- Under CPU load, HPA scales `frontend` above 2 and never above 6.
- `frontend-pdb` keeps at least 2 frontend Pods available during a voluntary eviction.
- Frontend and API containers have CPU and memory requests and limits, and those requests affect scheduling and HPA.
- `qos-guaranteed`, `qos-burstable`, and `qos-besteffort` report Guaranteed, Burstable, and BestEffort.
- Pods without the special toleration stay off Worker 2, and `special-worker-pod` is allowed onto it.
- Frontend Pods run only on the node labeled `workload=app`.
- The API Pod is colocated with the frontend when required pod affinity is set.

## 8. Constraints

- Do not treat this layout as highly available. Frontend capacity and disruption behavior are limited to one worker.
- HPA cannot be demonstrated until Metrics Server returns node and Pod metrics.
- If a PVC stays `Pending`, check the EBS CSI driver, its IAM role, PVC events, and free capacity in the worker subnet and Availability Zone.
- After the lab, add a third worker or relax the taint and affinity rules before practicing HPA and PDB during multi-node maintenance.
