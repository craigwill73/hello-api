#!/usr/bin/env bash
set -euo pipefail

# Create the Azure Storage backend for Terraform remote state if it does not exist.
# Uses bootstrap/ with local state (safe: main terraform/ consumes the remote backend once created).

TFSTATE_RG="${TFSTATE_RG:-rg-hello-api-tfstate}"
TFSTATE_STORAGE="${TFSTATE_STORAGE:-sthelloapicw73}"
TFSTATE_CONTAINER="${TFSTATE_CONTAINER:-tfstate}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-${ARM_SUBSCRIPTION_ID:-}}"

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "AZURE_SUBSCRIPTION_ID or ARM_SUBSCRIPTION_ID must be set"
  exit 1
fi

if az storage account show --name "$TFSTATE_STORAGE" --resource-group "$TFSTATE_RG" >/dev/null 2>&1; then
  echo "Remote state storage already exists: ${TFSTATE_STORAGE} (resource group ${TFSTATE_RG})"
  exit 0
fi

echo "Remote state backend not found — bootstrapping ${TFSTATE_RG}/${TFSTATE_STORAGE}..."

az group create \
  --name "$TFSTATE_RG" \
  --location "${AZURE_LOCATION:-westeurope}" \
  --tags project=hello-api purpose=terraform-state \
  -o none

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}/bootstrap"

terraform init -input=false
terraform apply -auto-approve -input=false \
  -var="subscription_id=${SUBSCRIPTION_ID}" \
  -var="resource_group_name=${TFSTATE_RG}" \
  -var="storage_account_name=${TFSTATE_STORAGE}"

echo "Remote state backend ready: ${TFSTATE_CONTAINER}@${TFSTATE_STORAGE}"
