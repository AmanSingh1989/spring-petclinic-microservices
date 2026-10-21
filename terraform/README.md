# Spring PetClinic AWS Infrastructure (Terraform)

This directory contains the complete Infrastructure-as-Code (IaC) to deploy the distributed **Spring PetClinic Microservices** application onto AWS using native AWS managed services.

It is specifically optimized for **Pluralsight Sandbox** and **AWS Free Tier** environments.

---

## 🏛️ Architecture Overview

* **Container Orchestration**: Amazon ECS Cluster (EC2 Launch Type) running across a dedicated pool of **4 `t3.micro` EC2 instances**.
* **Ingress & Load Balancing**: AWS Application Load Balancer (ALB) on port 80 routing to Spring Cloud API Gateway.
* **Internal Service Discovery**: AWS Cloud Map (`petclinic.internal` private DNS namespace) integrated with Spring Cloud Eureka.
* **Database**: Amazon RDS MySQL (`db.t3.micro`) deployed in private subnets, completely shielded from the internet.
* **Container Registry**: Amazon ECR repositories with automatic vulnerability scanning and image expiration policies.
* **Logging & Observability**: AWS CloudWatch (`awslogs` driver with 7-day retention) capturing all microservice standard outputs.
* **CI/CD Pipeline**: GitHub Actions (`.github/workflows/aws-ecs-deploy.yml`) building Maven JARs, Docker images, pushing to ECR, and performing rolling deployments.

---

## 📁 File Structure

| File | Description |
| :--- | :--- |
| `main.tf` | AWS provider configuration and global resource tagging. |
| `variables.tf` | Configurable parameters (region, cluster sizing, DB credentials, GenAI toggle). |
| `vpc.tf` | Multi-AZ VPC with 2 public subnets (ALB & EC2) and 2 private subnets (RDS). |
| `security_groups.tf` | Strict security groups adhering to the Principle of Least Privilege. |
| `rds.tf` | Free-Tier eligible MySQL `db.t3.micro` database with sandbox instant-teardown flags. |
| `iam.tf` | EC2 instance roles and ECS task execution roles for ECR and CloudWatch access. |
| `ecs_cluster.tf` | ECS cluster, direct 4 `t3.micro` EC2 instances, and 4GB swap space configuration. |
| `alb.tf` | Application Load Balancer, listeners, and target groups routing to the API Gateway. |
| `service_discovery.tf` | Route 53 private DNS hosted zone (`petclinic.internal`) for inter-container communication. |
| `cloudwatch.tf` | CloudWatch log groups for centralized logging. |
| `ecr.tf` | Amazon ECR repositories for all microservices with lifecycle cleanup rules. |
| `ecs_services.tf` | Task definitions & ECS services with JVM container limits and the GenAI toggle. |
| `outputs.tf` | Public ALB URL, DB endpoint, and ECR repository URLs. |
| `deploy.sh` & `destroy.sh` | One-command spin-up and tear-down helper scripts. |

---

## 🚀 How to Deploy in Pluralsight / AWS Sandbox

### 1. Prerequisites
Open a terminal (or AWS CloudShell) in your sandbox environment. Ensure `terraform` and `git` are available.

### 2. Configure Variables
Copy the template and inspect settings:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Key variables in `terraform.tfvars`:
* `enable_genai`: set to `false` (default) to skip the Spring AI chatbot and save memory, or `true` if you wish to test the AI service.
* `ec2_instance_count`: set to `4` (default).
* `db_password`: **Zero hardcoded passwords required**. Left commented out by default; Terraform dynamically generates a secure 16-character password and stores it in encrypted AWS Systems Manager (SSM) Parameter Store (`/petclinic/database/password`).

### 3. Deploy
Run the automated deployment script:
```bash
chmod +x deploy.sh destroy.sh
./deploy.sh
```
*Or manually:*
```bash
terraform init
terraform apply -auto-approve
```

At the end of the run, Terraform will output your public application URL:
```text
Outputs:
application_url = "http://petclinic-alb-123456789.us-east-1.elb.amazonaws.com"
```

---

## 🔄 Setting up GitHub Actions CI/CD

To automate builds and deployments when pushing code to GitHub:

1. In your GitHub repository, navigate to **Settings** > **Secrets and variables** > **Actions**.
2. Add the following repository secrets provided by your Pluralsight sandbox:
   * `AWS_ACCESS_KEY_ID`: Your sandbox AWS access key.
   * `AWS_SECRET_ACCESS_KEY`: Your sandbox secret key.
   * `AWS_SESSION_TOKEN`: Your sandbox session token (required in temporary AWS sandboxes).
3. Trigger the workflow:
   * Navigate to the **Actions** tab in GitHub.
   * Select **Build and Deploy to AWS ECS**.
   * Click **Run workflow** (choose whether to enable `enable_genai`).

The workflow will:
1. Build all Spring Boot modules using Java 17 and Maven.
2. Build layered Docker containers via `docker/Dockerfile`.
3. Authenticate to Amazon ECR and push the images.
4. Issue a rolling update to the Amazon ECS services.

---

## 🧹 Teardown (Zero Lingering Cost)

When your learning session is complete:
```bash
./destroy.sh
```
*Or manually:*
```bash
terraform destroy -auto-approve
```
All VPCs, subnets, EC2 nodes, ALB, and RDS databases will be terminated immediately.
