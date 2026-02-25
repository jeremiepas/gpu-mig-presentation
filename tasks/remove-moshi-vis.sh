#!/bin/bash

# Remove MoshiVis from the Kubernetes cluster
# This script removes the MoshiVis service from your existing GPU infrastructure

set -e

echo "Removing MoshiVis service..."

# Delete the MoshiVis deployment
echo "Removing MoshiVis application..."
kubectl delete -f k8s/08-moshi-vis.yaml

echo "MoshiVis removal completed!"
echo "To verify cleanup, you can check:"
echo "kubectl get pods -n moshi-vis"
echo "kubectl get namespaces | grep moshi-vis"

echo ""
echo "Note: The ingress controller is still running."
echo "To remove the ingress controller, run:"
echo "kubectl delete -f k8s/09-ingress-controller.yaml"