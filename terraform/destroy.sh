#!/bin/bash
set -e

echo "=========================================================="
echo " Tearing down Spring PetClinic AWS Sandbox Environment"
echo "=========================================================="

terraform destroy -auto-approve

echo ""
echo "=========================================================="
echo " All AWS resources destroyed cleanly. Zero lingering costs."
echo "=========================================================="
