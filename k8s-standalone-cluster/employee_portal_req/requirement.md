# Kubernetes Mega Lab: Employee Portal

## Environment

- Cluster: 1 control plane + 2 worker nodes on AWS (kubeadm, not EKS).
- Namespace: `k8s-mega-lab`. Delete this namespace to remove the lab.
- Ingress controller: ingress-nginx, HTTP NodePort `30867`.
- `type: LoadBalancer` stays `<pending>`. There is no AWS cloud controller.
- Dynamic volumes need a default StorageClass. If none exists, the StatefulSet cannot provision a volume.
- Do not open lab ports to `0.0.0.0/0`. Allow only your IP.

## Scenario

Users open an Employee Portal in a browser. An Ingress or NodePort reaches the frontend. The frontend uses an internal Service to reach an API. The API stores data in a database with persistent storage. Configuration comes from a ConfigMap. Credentials come from a Secret. A Job initializes the app. A CronJob simulates backups. A DaemonSet collects a sample log on each node.

The manifests may use nginx and PostgreSQL images. This is a learning lab, not a production application.

## Business requirements

1. Run a standalone diagnostic Pod for troubleshooting.
2. Deploy the frontend with a Deployment of 3 replicas and a rolling update.
3. Create a ReplicationController and a ReplicaSet to compare legacy and current replica controllers.
4. Store files on a PersistentVolume and mount them with a PersistentVolumeClaim.
5. Use hostPath for a node-level storage demonstration.
6. Run a DaemonSet so one log Pod runs on every eligible node.
7. Run a one-time Job for initialization and a CronJob for a scheduled backup demonstration.
8. Deploy the database as a StatefulSet with a stable Pod name and persistent storage.
9. Store application settings in a ConfigMap and credentials in a Secret.
10. Expose the app with ClusterIP, NodePort, Ingress, and an `externalIPs` Service example.

## Deliverables

| File | Resource |
|---|---|
| `00-namespace.yaml` | Namespace `k8s-mega-lab` |
| `01-pod.yaml` | Pod `debug-pod` |
| `02-deployment.yaml` | Deployment `frontend`, 3 replicas |
| `02b-frontend-config.yaml` | Frontend updated with ConfigMap env and mounted `index.html` |
| `03-replicationcontroller.yaml` | ReplicationController `legacy-web` |
| `04-replicaset.yaml` | ReplicaSet `standalone-rs` |
| `05-storage.yaml` | PV `lab-local-pv` and PVC `lab-local-pvc` |
| `06-hostpath-pod.yaml` | Pod `storage-test` using the PVC |
| `07-daemonset.yaml` | DaemonSet `node-log-agent` |
| `08-job.yaml` | Job `employee-init` |
| `09-cronjob.yaml` | CronJob `employee-backup-demo` |
| `10-statefulset.yaml` | Headless Service `postgres-headless` and StatefulSet `postgres` |
| `11-config.yaml` | ConfigMap `app-config` and Secret `db-secret` |
| `12-services.yaml` | `frontend-service`, `frontend-nodeport`, `postgres-service` |
| `13-ingress.yaml` | Ingress `employee-portal` |
| `14-external-ip.yaml` | Service `frontend-external-ip` |

Apply in that order. Create the ConfigMap and Secret before the frontend update and the database. Replace the worker hostname in the PV before applying storage.

## Component requirements

### Pod

- Name `debug-pod`, image `busybox:1.36`, command `sleep 36000`.
- Requests: 50m CPU, 32Mi memory. Limits: 200m CPU, 64Mi memory.
- Deleting this Pod must not recreate it.

### Deployment

- Name `frontend`, image `nginx:1.28`, container port 80, 3 replicas.
- Strategy `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`.
- Requests: 50m CPU, 32Mi. Limits: 250m CPU, 128Mi.
- You must be able to scale to 5, change the image to `nginx:1.29`, watch the rollout, read rollout history, and undo the rollout.

### ReplicationController and ReplicaSet

- ReplicationController `legacy-web`: 2 replicas, label `app: legacy-web`, image `nginx:1.28`.
- ReplicaSet `standalone-rs`: 2 replicas, label `app: standalone-rs`, image `nginx:1.28`.
- Deleting a Pod from either controller must cause a replacement Pod.

### Storage

- On one worker, create `/data/k8s-lab` before applying the PV.
- PV `lab-local-pv`: 1Gi, `ReadWriteOnce`, `Filesystem`, reclaim `Retain`, storage class `manual`, hostPath `/data/k8s-lab` of type `Directory`.
- Pin the PV to that worker with `nodeAffinity` on `kubernetes.io/hostname`.
- PVC `lab-local-pvc`: same size, access mode, and storage class.
- Pod `storage-test` appends the date to `/data/timestamps.txt` every 10 seconds through the PVC.
- After the Pod is deleted and created again, the old timestamps must still be present.
- `Retain` means deleting the PVC does not delete the files. Cleanup is manual.

### ConfigMap and Secret

- ConfigMap `app-config` keys: `APP_ENV=development`, `LOG_LEVEL=debug`, `API_URL=http://api-service:8080`, and an `index.html` page titled `Kubernetes Employee Portal`.
- Secret `db-secret` with `stringData`: `POSTGRES_USER=labuser`, `POSTGRES_PASSWORD=ChangeMe-For-Lab-123`, `POSTGRES_DB=employeedb`.
- Mount `index.html` onto the frontend at `/usr/share/nginx/html/index.html` using `subPath`.
- Load the ConfigMap into the frontend environment with `envFrom`.
- `printenv APP_ENV` inside the frontend must print `development`.
- Changing a ConfigMap key is not always visible in a running process. Record which change needs a restart.

### StatefulSet

- Headless Service `postgres-headless`, selector `app: postgres`, port 5432, `clusterIP: None`.
- StatefulSet `postgres`, 1 replica, image `postgres:16`, port 5432.
- Environment from Secret `db-secret`.
- Volume claim template `database-data`: `ReadWriteOnce`, 2Gi, mounted at `/var/lib/postgresql/data`.
- Requests: 100m CPU, 128Mi. Limits: 500m CPU, 512Mi.
- Create table `employees` (`id`, `name`, `role`), insert one row, delete `postgres-0`, and confirm the row still exists.
- One replica is not a highly available database.

### Job and CronJob

- Job `employee-init`: `restartPolicy: Never`, `backoffLimit: 2`. It prints a start line, sleeps 10 seconds, and prints completion.
- CronJob `employee-backup-demo`: schedule `*/5 * * * *`, `concurrencyPolicy: Forbid`, history limits 2.
- The CronJob only prints a backup message and the date. It does not dump PostgreSQL.
- You must be able to suspend it, confirm no new Job appears, and start one manually with `kubectl create job --from=cronjob/employee-backup-demo`.

### DaemonSet

- Name `node-log-agent`, image `busybox:1.36`.
- Mount the node directory `/var/log` read-only at `/host-logs`.
- Every 30 seconds, print the last 5 lines of `/host-logs/demo.log` when that file exists.
- Include a toleration for `node-role.kubernetes.io/control-plane` with effect `NoSchedule`.
- Expect one Pod per eligible node. With the toleration, the control plane can receive one too.

### Services

- `frontend-service`: ClusterIP, selector `app: frontend`, port 80 to target port 80.
- `frontend-nodeport`: NodePort, same selector and ports, `nodePort: 30080`.
- `postgres-service`: ClusterIP, selector `app: postgres`, port 5432.
- From a temporary curl Pod, `curl http://frontend-service` must return the portal page.
- `http://<worker-public-ip>:30080` must return the same page when the security group allows TCP 30080.

### Ingress

- Name `employee-portal`, class `nginx`, host `employee.lab.local`, path `/` to `frontend-service` port 80.
- Apply it only after `kubectl get ingressclass` shows `nginx`.
- Test with `curl -H "Host: employee.lab.local" http://<node-public-ip>:30867/`.
- An Ingress object does not create an AWS load balancer.

### External IP example

- Service `frontend-external-ip`: ClusterIP, selector `app: frontend`, `externalIPs: [192.0.2.10]`, Service port 8080, target port 80.
- `192.0.2.10` is a documentation address. Do not expect it to answer from a browser.
- `externalIPs` does not allocate an AWS address or create a route.

## Acceptance checks

- `kubectl get all -n k8s-mega-lab` shows the frontend, legacy controller, ReplicaSet, database, Job, CronJob, and DaemonSet.
- Frontend has 3 ready Pods. Scaling to 5 makes 5 ready Pods.
- `kubectl rollout history deployment/frontend -n k8s-mega-lab` shows the image update and the undo.
- `lab-local-pv` and `lab-local-pvc` are `Bound`. Timestamps survive a Pod delete.
- `postgres-0` returns with the same name, and the `employees` row survives a Pod delete.
- `employee-init` completes. The CronJob creates a Job on its schedule.
- DaemonSet Pods are placed on the eligible nodes.
- `frontend-service` has endpoints. NodePort 30080 returns the portal HTML.
- Ingress `employee-portal` has the nginx class and answers on NodePort 30867 with the host header.
- `kubectl describe secret db-secret -n k8s-mega-lab` does not print the password.

## Interview checks

1. Why does a deleted frontend Pod come back?
2. How do you scale the frontend from 3 to 5?
3. Which label or selector mistake makes a Service have no endpoints?
4. Why does PVC data survive a Pod delete, and what breaks if that Pod is scheduled onto the other worker?
5. Why does the StatefulSet Pod keep the name `postgres-0`?
6. What is the difference between a Job and a CronJob?
7. Why can a DaemonSet skip the control plane?
8. Why is a ClusterIP Service unreachable from the public internet?
9. Why does an Ingress not create an AWS load balancer on this cluster?
10. Why does `externalIPs` not allocate a public IP?
11. What is the difference between a ConfigMap and a Secret?