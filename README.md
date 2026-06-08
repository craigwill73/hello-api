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
terraform/                 AKS, ACR, Kubernetes, optional Front Door WAF
scripts/                   OIDC setup helper
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

**One-time OIDC setup** (creates app registration + federated credentials):

```bash
az login
az account set --subscription <your-subscription-id>
chmod +x scripts/setup-github-oidc.sh
./scripts/setup-github-oidc.sh
```

The script prints three values. **Delete and recreate** these repository secrets (avoids typos):

| Secret | Example / notes |
|---|---|
| `AZURE_CLIENT_ID` | From script output |
| `AZURE_TENANT_ID` | From script output (must match `az account show --query tenantId -o tsv`) |
| `AZURE_SUBSCRIPTION_ID` | From script output |

Settings: https://github.com/craigwill73/hello-api/settings/secrets/actions

**Federated credentials created:**

| Name | Subject | Used by |
|---|---|---|
| `github-main` | `repo:craigwill73/hello-api:ref:refs/heads/main` | `ci.yml` (ACR push) |
| `github-production` | `repo:craigwill73/hello-api:environment:production` | `terraform.yml` apply |

**Environment:** create `production` under Settings → Environments (optional approval gate before `terraform apply`).

**OIDC role:** Contributor on `rg-hello-api`.

If CI fails with `Tenant not found`, the `AZURE_TENANT_ID` secret is wrong — re-run the setup script and recreate secrets.

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
| WAF | Azure Front Door (OWASP + per-IP rate limit) |
| TF state | Azure Storage backend |

Production would add HTTPS ingress, separate infra/app stacks, and approval gates — scoped down for this exercise.

## WAF (Azure Front Door)

Traffic can be routed through **Azure Front Door WAF** in front of the AKS LoadBalancer IP:

```text
Client → Front Door WAF → LoadBalancer IP → hello-api pod
```

Managed in `terraform/frontdoor_waf.tf` (enabled by default):

- **Microsoft Default Rule Set** 2.1 (OWASP-style protections)
- **Bot Manager** rule set
- **Custom rate limit** — 100 requests / IP / minute (tune via `waf_rate_limit_threshold`)

```bash
az provider register --namespace Microsoft.Cdn --wait
cd terraform && terraform apply
terraform output hello_url          # Front Door URL (WAF-protected)
terraform output hello_url_direct   # Direct IP (bypasses WAF)
```

Disable WAF and use direct IP only:

```hcl
# terraform.tfvars
enable_frontdoor_waf = false
```

**Note:** Backbase uses Application Gateway WAF + Istio at platform scale. Front Door is the lighter Azure WAF pattern for a public IP origin without re-architecting AKS.
