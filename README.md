# hello-api

REST API technical assessment — single `/hello` endpoint deployed to Azure AKS with Terraform.

- **Endpoint:** `GET /hello` → `Hello World`
- **Stack:** Python (FastAPI) · Docker · Azure AKS · Terraform · GitHub Actions (OIDC)

## Repository layout

```text
app/                       FastAPI application
tests/                     pytest suite
docker/Dockerfile          Container image
bootstrap/                 One-time Terraform state backend
terraform/                 AKS, ACR, Kubernetes resources
.github/workflows/ci.yml   Test + build/push image to ACR
.github/workflows/terraform.yml  Plan on PR, apply on merge
```

## Prerequisites

- Azure CLI (`az login`) on trial subscription
- Terraform >= 1.5
- Docker (local builds only — CI builds in GitHub)
- Python 3.12+

## CI/CD (Backbase-style, simplified)

| Event | Workflow | Action |
|---|---|---|
| PR changing `terraform/**` | `terraform.yml` | `terraform plan` + comment on PR |
| Merge to `main` (terraform paths) | `terraform.yml` | `terraform apply` |
| Push/PR to `main` | `ci.yml` | pytest + build/push `linux/amd64` image to ACR |

Manual apply is still supported locally from `terraform/`.

### GitHub setup

**Secrets** (Settings → Secrets and variables → Actions):

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | OIDC app registration |
| `AZURE_TENANT_ID` | Azure AD tenant |
| `AZURE_SUBSCRIPTION_ID` | Trial subscription |

**Environment** (optional): create `production` under Settings → Environments if you want an approval gate before `terraform apply`.

**OIDC role:** the service principal needs **Contributor** on `rg-hello-api` (and access to read AKS for kubeconfig).

### First-time bootstrap (local, once)

Remote state must exist before CI can run Terraform:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

First AKS creation is easiest locally (two-phase apply below). After that, use PRs + merge for Terraform changes.

## Local deploy (alternative to CI)

### 1. Bootstrap Terraform remote state (one time)

Pick a **globally unique** storage account name (letters/numbers only, 3–24 chars).
Default in examples: `sthelloapicw73` — change if taken.

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Update `terraform/versions.tf` backend block if you changed the storage account name.

### 2. Deploy Azure infrastructure

Deploy in **two phases** — the Kubernetes provider needs a kubeconfig from AKS before it can create workloads.

```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
```

If you already created `rg-hello-api` during OIDC setup:

```bash
terraform import azurerm_resource_group.main \
  /subscriptions/<subscription-id>/resourceGroups/rg-hello-api
```

**Phase A — Azure resources only (~10–15 min):**

```bash
terraform apply \
  -target=azurerm_resource_group.main \
  -target=azurerm_container_registry.main \
  -target=azurerm_kubernetes_cluster.main \
  -target=azurerm_role_assignment.aks_acr_pull \
  -target=azurerm_public_ip.hello
```

**Phase B — Kubernetes app (after kubeconfig exists):**

```bash
az aks get-credentials --resource-group rg-hello-api --name aks-hello-api --overwrite-existing
terraform apply
```

Run from **`~/Documents/GitHub/hello-api/terraform`**.

### 3. Image in ACR

CI pushes on every push to `main`. Local alternative:

```bash
docker build --platform linux/amd64 -f docker/Dockerfile -t acrhelloapicw73.azurecr.io/hello-api:latest .
docker push acrhelloapicw73.azurecr.io/hello-api:latest
kubectl rollout restart deployment/hello-api
```

### 4. Verify

```bash
curl "$(terraform -chdir=terraform output -raw hello_url)"
# Hello World
```

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload
curl http://localhost:8000/hello
pytest -v
```

## Tear down (save credits)

```bash
cd terraform && terraform destroy
cd ../bootstrap && terraform destroy
```

## Design decisions

| Decision | Choice |
|---|---|
| Region | westeurope |
| Node size | Standard_B2s_v2 |
| Exposure | LoadBalancer + static public IP |
| CI | pytest + ACR push (OIDC, linux/amd64) |
| CD | Terraform plan on PR, apply on merge |
| TF state | Azure Storage backend |

Production would add HTTPS ingress, separate infra/app stacks, and approval gates — scoped down for this exercise.
