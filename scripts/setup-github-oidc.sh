#!/usr/bin/env bash
set -euo pipefail

# Configure GitHub Actions OIDC for hello-api.
# Run after: az login (personal trial subscription)

REPO="craigwill73/hello-api"
APP_NAME="github-hello-api"
RG="rg-hello-api"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant:       $TENANT_ID"
echo ""
echo "Set these GitHub repository secrets:"
echo "  AZURE_CLIENT_ID=$APP_NAME (created below)"
echo "  AZURE_TENANT_ID=$TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo ""

az group create --name "$RG" --location westeurope \
  --tags project=hello-api environment=trial purpose=hello-api \
  -o none 2>/dev/null || true

APP_ID="$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)"
if [[ -z "$APP_ID" || "$APP_ID" == "null" ]]; then
  APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
  az ad sp create --id "$APP_ID" -o none
  echo "Created app registration: $APP_ID"
else
  az ad sp show --id "$APP_ID" >/dev/null 2>&1 || az ad sp create --id "$APP_ID" -o none
  echo "Using existing app registration: $APP_ID"
fi

SP_OBJECT_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

create_federated_credential() {
  local name="$1"
  local subject="$2"
  local existing
  existing="$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'].name" -o tsv 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"$name\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$subject\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" -o none
    echo "Created federated credential: $name"
  else
    echo "Federated credential already exists: $name"
  fi
}

create_federated_credential "github-main" "repo:${REPO}:ref:refs/heads/main"
create_federated_credential "github-production" "repo:${REPO}:environment:production"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG" \
  -o none 2>/dev/null || echo "Contributor role on $RG already assigned"

TFSTATE_RG="rg-hello-api-tfstate"
az group show --name "$TFSTATE_RG" >/dev/null 2>&1 && \
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TFSTATE_RG" \
  -o none 2>/dev/null || echo "Contributor role on $TFSTATE_RG already assigned"

AKS_NAME="aks-hello-api"
if az aks show --resource-group "$RG" --name "$AKS_NAME" >/dev/null 2>&1; then
  NODE_RG="$(az aks show --resource-group "$RG" --name "$AKS_NAME" --query nodeResourceGroup -o tsv)"
  az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$NODE_RG" \
    -o none 2>/dev/null || echo "Contributor role on $NODE_RG already assigned"
fi

echo ""
echo "=== GitHub secrets (delete & recreate if tenant was wrong) ==="
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo ""
echo "https://github.com/${REPO}/settings/secrets/actions"
