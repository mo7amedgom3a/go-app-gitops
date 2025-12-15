# GitOps Pipeline with ArgoCD (Go App + Kubernetes)

This repository documents a **complete GitOps workflow** using **ArgoCD**, **Helm**, **GitHub Actions**, and **Kubernetes (K3s)**.

The goal is to:

* Build and push a Go application image using CI
* Store Kubernetes desired state in Git (GitOps repo)
* Use **ArgoCD** to continuously reconcile cluster state
* Trigger ArgoCD sync **via GitHub webhook instead of polling**

---

## 1. What Is GitOps?

**GitOps** is an operational model where:

* Git is the **single source of truth**
* Desired state is declared in Git
* A controller (ArgoCD) continuously reconciles the cluster

Key principles:

* Declarative configuration
* Pull-based deployment
* Versioned & auditable changes
* Automatic drift detection and self-healing

---

## 2. Architecture Overview

```
Developer
   ↓
App Repository (Go code)
   ↓ GitHub Actions (CI)
Build Docker Image → Push to Docker Hub
   ↓
GitOps Repository (Helm values.yaml)
   ↓ (push)
GitHub Webhook
   ↓
ArgoCD
   ↓ (pull)
Kubernetes Cluster (K3s)
```

Important separation:

* **CI**: builds artifacts (Docker images)
* **CD**: ArgoCD pulls from Git and deploys

---

## 3. Repositories

### 3.1 Application Repository

Contains:

* Go application source code
* Dockerfile
* GitHub Actions CI pipeline

Responsibilities:

* Build image
* Push image to Docker Hub
* Update GitOps repo (image tag only)

---

### 3.2 GitOps Repository

Contains:

* Helm chart
* Kubernetes manifests
* ArgoCD Application definition

Responsibilities:

* Declare desired cluster state
* No application source code
* No kubectl commands

---

## 4. Helm Chart Structure (GitOps Repo)

```
go-app-gitops/
└── charts/
    └── go-app/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            └── _helpers.tpl
```

### Why Helm?

* No hard-coded image values
* Image repository and tag are configurable
* CI updates `values.yaml` only

---

## 5. ArgoCD Application (GitOps Definition)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: go-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/mo7amedgom3a/go-app-gitops
    targetRevision: main
    path: charts/go-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Key Points

* Git is the source of truth
* Helm is used as a rendering engine
* Auto-sync enabled
* Drift is automatically corrected

---

## 6. Installing ArgoCD on the Cluster

### 6.1 Create Namespace

```bash
kubectl create namespace argocd
```

### 6.2 Install ArgoCD

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Verify:

```bash
kubectl get pods -n argocd
```

---

## 7. Accessing ArgoCD Dashboard

### Option A: NodePort (Simple Setup)

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort"}}'
```

Access:

```
http://<NODE_IP>:<NODE_PORT>
```

### Get Admin Password

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" | base64 -d
```

Username:

```
admin
```

---

## 8. CI Pipeline Responsibilities (App Repo)

The CI pipeline:

1. Builds Docker image
2. Pushes image to Docker Hub
3. Clones GitOps repository
4. Updates `values.yaml` with new image tag
5. Commits and pushes changes

CI **never accesses the Kubernetes cluster**.

---

## 9. Default ArgoCD Behavior (Polling)

By default:

* ArgoCD polls Git repositories every few minutes
* Detects changes
* Syncs automatically (if enabled)

This is safe but not instant.

---

## 10. Using GitHub Webhook Instead of Polling

ArgoCD **remains pull-based**, but GitHub webhooks can be used to:

* Notify ArgoCD immediately
* Trigger an instant refresh

### Important

> Webhooks do NOT push manifests to ArgoCD. They only notify it to pull.

---

## 11. Configure ArgoCD for Webhooks

### 11.1 Expose ArgoCD API

ArgoCD must be reachable from GitHub.

Example (NodePort):

```
http://<NODE_IP>:<NODE_PORT>
```

Webhook endpoint:

```
/api/webhook
```

---

### 11.2 Create GitHub Webhook

GitHub Repo → Settings → Webhooks → Add Webhook

* Payload URL:

```
http://<NODE_IP>:<NODE_PORT>/api/webhook
```

* Content-Type: `application/json`
* Events: Push
* Secret: (recommended)

---

### 11.3 Configure Webhook Secret in ArgoCD

```bash
kubectl -n argocd create secret generic argocd-webhook-secret \
  --from-literal=github=<WEBHOOK_SECRET>
```

Restart ArgoCD server if needed.

---

## 12. End-to-End Flow (With Webhook)

1. Developer pushes code
2. CI builds & pushes Docker image
3. CI updates GitOps repo
4. GitHub sends webhook to ArgoCD
5. ArgoCD pulls Git immediately
6. Helm renders manifests
7. Cluster state is reconciled

---

## 13. Security Best Practices

* CI has no cluster credentials
* ArgoCD pulls from Git only
* Use webhook secrets
* Use HTTPS + Ingress in production
* Enable RBAC and disable admin user later

---

## 14. Summary

This setup demonstrates a **production-grade GitOps workflow**:

* Clear separation of CI and CD
* Declarative Kubernetes configuration
* Automatic synchronization and self-healing
* Fast deployments using GitHub webhooks

Git remains the single source of truth for the cluster state.
