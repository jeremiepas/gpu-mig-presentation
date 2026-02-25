#!/bin/bash

# Deploy MoshiVis to the Kubernetes cluster
# This script deploys the MoshiVis service to your existing GPU infrastructure

set -e

echo "Deploying MoshiVis service..."

# Apply the ingress controller first
echo "Deploying ingress controller..."
kubectl apply -f k8s/09-ingress-controller.yaml

# Wait a moment for the ingress controller to start
sleep 10

# Apply the MoshiVis deployment
echo "Deploying MoshiVis application..."
kubectl apply -f k8s/08-moshi-vis.yaml

echo "Waiting for MoshiVis to be ready..."
kubectl rollout status deployment/moshi-vis -n moshi-vis --timeout=300s

echo "MoshiVis deployment completed!"
echo "To access MoshiVis, go to:"
echo "http://YOUR_INSTANCE_IP/moshi-vis"
echo ""
echo "To get your instance IP, run:"
echo "terraform -chdir=terraform output instance_ip"