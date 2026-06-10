# hello-api

Public REST API on Azure AKS — `GET /hello` returns plain text `Hello World`.

**Live base URL:** http://20.86.183.22

## API endpoint

| URL | Description |
|---|---|
| [http://20.86.183.22/hello](http://20.86.183.22/hello) | `GET /hello` → `Hello World` |

```bash
curl http://20.86.183.22/hello
# Hello World
```

## Operations (uptime & contract)

Not required by API clients — used for health checks, versioning, and documentation.

| URL | Description |
|---|---|
| [http://20.86.183.22/health](http://20.86.183.22/health) | Liveness probe |
| [http://20.86.183.22/ready](http://20.86.183.22/ready) | Readiness probe |
| [http://20.86.183.22/v1/hello](http://20.86.183.22/v1/hello) | Versioned path (same response) |
| [http://20.86.183.22/docs](http://20.86.183.22/docs) | OpenAPI (Swagger UI) |
| [http://20.86.183.22/openapi.json](http://20.86.183.22/openapi.json) | OpenAPI spec |

## Stack

Python (FastAPI) · Docker · Azure AKS · Terraform · GitHub Actions

Deployed to **westeurope** on a 2-node AKS cluster (2 replicas, spread across nodes).

## Design

| Area | Choice |
|---|---|
| Region | `westeurope` |
| Compute | 2 × `Standard_B2s_v2` nodes, 2 pod replicas |
| Availability | Topology spread (one pod per node), `PodDisruptionBudget` (`minAvailable: 1`) |
| Exposure | Azure LoadBalancer with static public IP |
| API contract | OpenAPI at `/docs`; versioned paths under `/v1/` |
| Delivery | GitHub Actions — test, image push, Terraform plan/apply (image tag = git SHA) |

## TLS (not enabled)

The API is served over **HTTP** on a static IP. Trusted HTTPS requires a **DNS hostname** — certificates are not issued for bare IPs.

With a hostname (e.g. `api.example.com` → `20.86.183.22`):

1. Point an **A record** at the static IP
2. Terminate TLS at **ingress + cert-manager** (Let's Encrypt) or **Azure Front Door**
3. Redirect HTTP → HTTPS at the edge

## WAF and rate limiting (not enabled)

Edge protection is defined in `terraform/frontdoor_waf.tf` but disabled (`enable_frontdoor_waf = false`).

| Capability | This deployment | With paid subscription |
|---|---|---|
| Azure Front Door WAF | Not available on Free Trial | `enable_frontdoor_waf = true` |
| Per-IP rate limiting | — | Front Door Standard |
| OWASP managed rules | — | Front Door Premium |

Free Trial accounts cannot create Front Door resources. Alternatives: ingress-level rate limiting or an API gateway in front of the service.

```text
Current:    HTTP → LoadBalancer → pod
Production: HTTPS → WAF → Ingress/Gateway → pod
```
