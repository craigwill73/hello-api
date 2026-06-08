# hello-api

REST API for the Bestseller Data Platform practical assignment.

- **Endpoint:** `GET /hello` → `Hello World`
- **Stack:** Python (FastAPI) · Docker · Azure AKS · Terraform · GitHub Actions (OIDC → ACR)

## Repository layout

```text
app/                  FastAPI application
tests/                pytest suite
docker/Dockerfile     Container image
bootstrap/            One-time Terraform state backend
terraform/            AKS, ACR, Kubernetes resources
.github/workflows/    CI test + ACR push
```

## Prerequisites

- Azure CLI (`az login`) on trial subscription
- Terraform >= 1.6
- Docker
- Python 3.12+

## 1. Bootstrap Terraform remote state (one time)

Pick a **globally unique** storage account name (letters/numbers only, 3–24 chars).
Default in examples: `sthelloapicw73` — change if taken.

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars if needed

terraform init
terraform apply
```

Update `terraform/versions.tf` backend block if you changed the storage account name.

## 2. Deploy Azure infrastructure

```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# edit acr_name if acrhelloapicw73 is taken (must match .github/workflows/ci.yml)

terraform init
terraform apply
```

This creates:

- Resource group `rg-hello-api`
- ACR `acrhelloapicw73`
- AKS cluster `aks-hello-api`
- Static public IP + LoadBalancer Service

Note the outputs:

```bash
terraform output hello_url
terraform output public_ip
```

If you already created `rg-hello-api` during OIDC setup:

```bash
terraform import azurerm_resource_group.main rg-hello-api
terraform apply
```

## 3. Build and push the first image

GitHub Actions pushes on every push to `main`, but the **first image** must exist before the pod can start.

**Option A — let CI push (after step 2):**

Push to `main` and wait for the Actions workflow to complete.

**Option B — push locally:**

```bash
az acr login --name acrhelloapicw73
docker build -f docker/Dockerfile -t acrhelloapicw73.azurecr.io/hello-api:latest .
docker push acrhelloapicw73.azurecr.io/hello-api:latest
```

## 4. Restart deployment (pick up new image)

```bash
az aks get-credentials --resource-group rg-hello-api --name aks-hello-api --overwrite-existing
kubectl rollout restart deployment/hello-api
kubectl get pods -w
```

Or re-run:

```bash
cd terraform && terraform apply
```

## 5. Verify

```bash
curl "$(terraform -chdir=terraform output -raw hello_url)"
# Hello World
```

Add the URL to your submission email to `dataplatform@bestseller.com`.

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload
curl http://localhost:8000/hello
pytest -v
```

## GitHub ↔ Azure (OIDC)

Already configured:

- App registration: `github-hello-api`
- Federated credential: `repo:craigwill73/hello-api:ref:refs/heads/main`
- Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

Workflow pushes `:latest` and `:$GITHUB_SHA` tags on every push to `main`.

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
| CI | Test + push to ACR (OIDC) |
| Deploy | Local `terraform apply` |
| TF state | Azure Storage backend |

Production would add HTTPS ingress, AKS hardening, and remote CD — scoped down for the assignment.
