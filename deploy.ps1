<#
.SYNOPSIS
    Deploys the Ember AI infrastructure to a local or remote K3s cluster.

.DESCRIPTION
    This script applies all Kubernetes manifests located in the k8s directory.
    It ensures that the correct namespace is created before deploying secrets,
    databases, cache, and application services (n8n, LiteLLM, OpenZiti).

.EXAMPLE
    .\deploy.ps1
#>

$ErrorActionPreference = "Stop"
$manifestsDir = Join-Path -Path $PSScriptRoot -ChildPath "k8s"

Write-Host "====================================="
Write-Host " Starting Ember AI K3s Deployment"
Write-Host "====================================="

# Check if wsl is available
if (-not (Get-Command "wsl" -ErrorAction SilentlyContinue)) {
    Write-Error "wsl is not installed or not in the PATH."
}

# Ensure K3s is responsive in Ubuntu
try {
    wsl -d Ubuntu k3s kubectl version --short > $null 2>&1
}
catch {
    Write-Warning "K3s might not be running in WSL Ubuntu."
}

# Ensure the k8s directory exists
if (-not (Test-Path -Path $manifestsDir)) {
    Write-Error "Manifests directory '$manifestsDir' not found."
}

# The ordered list of manifests to apply to ensure dependencies are met
$manifests = @(
    "00-namespace-and-secrets.yaml",
    "01-pgvector.yaml",
    "02-valkey.yaml",
    "06-external-secrets-operator.yaml",
    "07-bitwarden-eso-clusterstore.yaml",
    "08-litellm-config.yaml",
    "03-litellm.yaml",
    "04-n8n.yaml",
    "05-openziti.yaml"
)

foreach ($manifest in $manifests) {
    $filePath = Join-Path -Path $manifestsDir -ChildPath $manifest
    
    if (Test-Path -Path $filePath) {
        Write-Host "-> Applying $manifest..." -ForegroundColor Cyan
        
        # Translate Windows path to WSL path 
        $wslPath = $filePath -replace '^C:\\', '/mnt/c/' -replace '\\', '/'
        
        try {
            # Execute kubectl inside WSL
            $output = wsl -d Ubuntu k3s kubectl apply -f $wslPath 2>&1
            Write-Host $output -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to apply $manifest. Error: $_"
        }
    }
    else {
        Write-Warning "File '$manifest' not found in $manifestsDir. Skipping..."
    }
}

Write-Host "====================================="
Write-Host " Deployment script finished targeting K3s in WSL!"
Write-Host " Run 'wsl -d Ubuntu k3s kubectl get pods -n ember-ai' to check status."
Write-Host " Note: If External Secrets failed due to missing CRDs, please install it first."
Write-Host "====================================="
