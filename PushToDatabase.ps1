[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$CloudService = '',
    
    [Parameter(Mandatory=$false)]
    [string]$AwsAccessKey = '',
    
    [Parameter(Mandatory=$false)]
    [string]$AwsSecretKey = '',
    
    [Parameter(Mandatory=$false)]
    [string]$AwsRegion = ''
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Export environment variables
$env:CLOUD_SERVICE = $CloudService
$env:AWS_ACCESS_KEY = $AwsAccessKey
$env:AWS_SECRET_KEY = $AwsSecretKey
$env:AWS_REGION = $AwsRegion

# Navigate to project directory
Set-Location -Path "C:\Users\Bobby\D\EbaySEOApp"

# Run Docker container with specific command
$dockerCommand = @(
    "docker"
    "run"
    "--rm"
    "-e", "CLOUD_SERVICE=$CloudService"
    "-e", "AWS_ACCESS_KEY=$AwsAccessKey"
    "-e", "AWS_SECRET_KEY=$AwsSecretKey"
    "-e", "AWS_REGION=$AwsRegion"
    "-v", "C:\Users\Bobby\D\EbaySEOApp\images\input:/app/images/input"
    "-v", "C:\Users\Bobby\D\EbaySEOApp\data:/app/data"
    "ebay_seo_pipeline_image"
    "lua-scripts/push_to_database.lua"
)

try {
    & $dockerCommand[0] $dockerCommand[1..($dockerCommand.Length-1)]
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Error "Failed to execute Docker command: $_"
    exit 1
}