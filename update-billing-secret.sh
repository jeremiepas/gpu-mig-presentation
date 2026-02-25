#!/bin/bash

# Extract credentials from credentials.env
export $(grep -v '^#' credentials.env | xargs)

# Create or update the Kubernetes secret
kubectl create secret generic scaleway-credentials \
  --namespace=monitoring \
  --from-literal=access-key="$SCW_ACCESS_KEY" \
  --from-literal=secret-key="$SCW_SECRET_KEY" \
  --from-literal=project-id="$SCW_PROJECT_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Scaleway credentials secret updated successfully!"