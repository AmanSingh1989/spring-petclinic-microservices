# PowerShell script to build Spring PetClinic using Podman and push images to Amazon ECR
param (
    [string]$Engine = "podman"
)

$ErrorActionPreference = "Stop"

$ACCOUNT_ID = "432913248669"
$REGION = "us-east-1"
$REGISTRY = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
$PREFIX = "$REGISTRY/petclinic"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Using Container Engine: $Engine" -ForegroundColor Cyan
Write-Host " 1. Authenticating $Engine to Amazon ECR" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$token = (aws ecr get-login-password --region $REGION).Trim()
& $Engine login -u AWS -p $token $REGISTRY

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 2. Building Maven JARs and Layered OCI Images with Podman" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
cmd.exe /c "mvnw.cmd clean install -P buildDocker -DskipTests -Dcontainer.executable=$Engine -Ddocker.image.prefix=$PREFIX"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 3. Tagging and Pushing Images to Amazon ECR" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$services = @(
    @{ Src = "spring-petclinic-config-server";    Dst = "config-server" },
    @{ Src = "spring-petclinic-discovery-server"; Dst = "discovery-server" },
    @{ Src = "spring-petclinic-api-gateway";      Dst = "api-gateway" },
    @{ Src = "spring-petclinic-customers-service";Dst = "customers-service" },
    @{ Src = "spring-petclinic-visits-service";   Dst = "visits-service" },
    @{ Src = "spring-petclinic-vets-service";     Dst = "vets-service" },
    @{ Src = "spring-petclinic-admin-server";     Dst = "admin-server" }
)

foreach ($svc in $services) {
    $srcImg = "$PREFIX/$($svc.Src):latest"
    $dstImg = "$PREFIX/$($svc.Dst):latest"
    Write-Host "Tagging and pushing $dstImg..." -ForegroundColor Green
    & $Engine tag $srcImg $dstImg
    # Use --format v2s2 to ensure standard Docker v2 manifest compatibility with AWS ECR
    if ($Engine -eq "podman") {
        & $Engine push --format v2s2 $dstImg
    } else {
        & $Engine push $dstImg
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 4. Triggering Amazon ECS Rolling Deployments" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
foreach ($svc in $services) {
    Write-Host "Refreshing service: petclinic-$($svc.Dst)..."
    aws ecr describe-images --repository-name "petclinic/$($svc.Dst)" --region $REGION --query "imageDetails[0].imageDigest" --output text | Out-Null
    aws ecs update-service --cluster petclinic-cluster --service "petclinic-$($svc.Dst)" --force-new-deployment --region $REGION | Out-Null
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " All images built and published to ECR with Podman!" -ForegroundColor Green
Write-Host " ECS tasks are starting. In 1-2 minutes, open your app:" -ForegroundColor Green
Write-Host " http://petclinic-alb-2063145070.us-east-1.elb.amazonaws.com" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
