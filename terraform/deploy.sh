#!/bin/bash
set -e

echo "=========================================================="
echo " Starting Spring PetClinic AWS Sandbox Deployment"
echo "=========================================================="

if [ -f ".env" ]; then
    echo "Loading AWS credentials from .env..."
    export $(grep -v '^#' .env | xargs)
fi

if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
fi

echo "Initializing Terraform..."
terraform init

echo "Validating Terraform configuration..."
terraform validate

echo "Applying Terraform infrastructure plan..."
terraform apply -auto-approve

echo ""
echo "=========================================================="
echo " Infrastructure Provisioned Successfully!"
echo "=========================================================="
terraform output
