#!/bin/bash
set -e

echo "=========================================================="
echo " Tearing down Spring PetClinic AWS Sandbox Environment"
echo "=========================================================="

if [ -f ".env" ]; then
    echo "Loading AWS credentials from .env..."
    export $(grep -v '^#' .env | xargs)
fi

terraform destroy -auto-approve

echo ""
echo "=========================================================="
echo " All AWS resources destroyed cleanly. Zero lingering costs."
echo "=========================================================="
