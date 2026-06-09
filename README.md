# hello-api

Public REST API on Azure AKS — `GET /hello` returns plain text `Hello World`.

**Live base URL:** http://20.86.183.22

## Endpoints

| URL | Description |
|---|---|
| [http://20.86.183.22/hello](http://20.86.183.22/hello) | Assignment endpoint |
| [http://20.86.183.22/v1/hello](http://20.86.183.22/v1/hello) | Versioned API path |
| [http://20.86.183.22/health](http://20.86.183.22/health) | Liveness probe |
| [http://20.86.183.22/ready](http://20.86.183.22/ready) | Readiness probe |
| [http://20.86.183.22/docs](http://20.86.183.22/docs) | OpenAPI (Swagger UI) |
| [http://20.86.183.22/openapi.json](http://20.86.183.22/openapi.json) | OpenAPI spec |

```bash
curl http://20.86.183.22/hello
# Hello World
```

## Stack

Python (FastAPI) · Docker · Azure AKS · Terraform · GitHub Actions

Deployed to **westeurope** on a 2-node AKS cluster (2 replicas, spread across nodes).

## Prerequisites

To run or develop locally:

- Python 3.12+
- Docker (optional — images are built in CI)
- Azure CLI and Terraform >= 1.5 (only if inspecting infrastructure)

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload
pytest -v
```

## Design

| Area | Choice |
|---|---|
| Region | `westeurope` |
| Compute | 2 × `Standard_B2s_v2` nodes, 2 pod replicas |
| Availability | Topology spread (one pod per node), `PodDisruptionBudget` (`minAvailable: 1`) |
| Exposure | Azure LoadBalancer with static public IP |
| API contract | OpenAPI at `/docs`; versioned paths under `/v1/` |
| Delivery | GitHub Actions — test, image push, Terraform plan/apply |

## TLS (not enabled)

The API is served over **HTTP** on a static IP. Trusted HTTPS requires a **DNS hostname** — certificates are not issued for bare IPs.

With a hostname (e.g. `api.example.com` → `20.86.183.22`):

1. Point an **A record** at the static IP
2. Terminate TLS at **ingress + cert-manager** (Let's Encrypt), **Application Gateway**, or **Azure Front Door**
3. Redirect HTTP → HTTPS at the edge

## WAF and rate limiting (not enabled)

Edge protection is defined in `terraform/frontdoor_waf.tf` but disabled (`enable_frontdoor_waf = false`).

| Capability | This deployment | With paid subscription |
|---|---|---|
| Azure Front Door WAF | Not available on Free Trial | `enable_frontdoor_waf = true` |
| Per-IP rate limiting | — | Front Door Standard |
| OWASP managed rules | — | Front Door Premium |

Free Trial accounts cannot create Front Door resources. Alternatives: Application Gateway WAF, or rate limiting at ingress / API gateway.

```text
Current:    HTTP → LoadBalancer → pod
Production: HTTPS → WAF → Ingress/Gateway → pod
```
