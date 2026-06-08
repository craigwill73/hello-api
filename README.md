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

The script prints values for GitHub. **Only one secret is required in CI:**

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | OIDC app registration client ID |

Tenant and subscription IDs are set in the workflow `env` block (not secrets — they identify this trial subscription).

Optional: delete old `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` secrets to avoid confusion.

**Federated credentials created:**

| Name | Subject | Used by |
|---|---|---|
| `github-main` | `repo:craigwill73/hello-api:ref:refs/heads/main` | `ci.yml` (ACR push) |
| `github-production` | `repo:craigwill73/hello-api:environment:production` | `terraform.yml` apply |

**Environment:** create `production` under Settings → Environments (optional approval gate before `terraform apply`).

**OIDC role:** Contributor on:

- `rg-hello-api`
- `rg-hello-api-tfstate` (Terraform remote state)
- `MC_rg-hello-api_*` (AKS node resource group — created after AKS exists)

If CI fails with `Tenant not found`, re-run `./scripts/setup-github-oidc.sh` and update `AZURE_CLIENT_ID`.

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
| WAF | Not enabled — Azure Front Door blocked on Free Trial (see below) |
| TLS | Not enabled — requires a hostname (see below) |
| TF state | Azure Storage backend |

## Production hardening (not enabled on this deployment)

This assignment uses a **public HTTP endpoint** on a **Free Trial** subscription. The following are documented in Terraform but **not active** in the default configuration — enable them when moving to a paid subscription and/or when a hostname is available.

### TLS (HTTPS)

Trusted TLS needs a **DNS hostname** pointing at the LoadBalancer IP. Let's Encrypt and managed Azure certificates are not issued for bare IP addresses.

| Requirement | Status on trial deployment |
|---|---|
| Hostname (e.g. `api.example.com` → static IP) | Not configured |
| TLS termination (ingress + cert-manager, or App Gateway) | Not enabled |
| Current endpoint | `http://<static-ip>/hello` |

**To enable when a hostname is available:**

1. Create an **A record** from your domain to `terraform output -raw public_ip`
2. Add **cert-manager** + **Let's Encrypt** ClusterIssuer on AKS, or terminate TLS at **Application Gateway** (Backbase-style)
3. Switch from direct LoadBalancer exposure to **ingress with TLS**, or mount the certificate into the pod

```hcl
# Example: enable once hostname + paid subscription are in place
# (ingress / cert-manager resources not included in this assignment scope)
```

### WAF and rate limiting

Edge WAF and rate limiting are implemented in `terraform/frontdoor_waf.tf` but **disabled by default** (`enable_frontdoor_waf = false`).

| Capability | Free Trial | Paid subscription |
|---|---|---|
| Azure Front Door WAF | **Not available** | Set `enable_frontdoor_waf = true` |
| Custom rate limit (per IP) | — | Standard Front Door SKU |
| OWASP managed rules | — | Requires Premium Front Door SKU |
| Application Gateway WAF | Available (heavier setup) | Backbase platform pattern |

> **Free Trial error:** `Free Trial and Student account is forbidden for Azure Frontdoor resources.`

**To enable on a paid subscription:**

```hcl
# terraform.tfvars
enable_frontdoor_waf = true
waf_rate_limit_threshold = 100   # requests per IP per minute
```

```bash
az provider register --namespace Microsoft.Cdn --wait
cd terraform && terraform apply
terraform output hello_url         # Front Door URL (WAF-protected)
terraform output hello_url_direct  # Direct LoadBalancer IP
```

**Alternative on trial (not implemented here):** application-layer rate limiting in FastAPI, or NGINX Ingress rate-limit annotations.

### Summary

```text
Trial deployment:     HTTP → LoadBalancer → pod
Production target:    HTTPS → WAF → LoadBalancer/Ingress → pod
```

Backbase production uses **Application Gateway WAF + Istio** in front of AKS — a heavier but similar defence-in-depth model.
