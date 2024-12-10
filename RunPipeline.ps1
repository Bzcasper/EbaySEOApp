# RunPipeline.ps1
param(
    [switch]$Debug,
    [string]$ConfigPath = ".env",
    [string]$LogLevel = "info"
)

# Import environment variables
if (Test-Path $ConfigPath) {
    Get-Content $ConfigPath | ForEach-Object {
        if ($_ -match '^([^#].+)=(.+)$') {
            $name = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($name, $value)
        }
    }
}

# Set up logging
$LogFile = "ebay_scraper.log"
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -Append $LogFile
}

# Check Docker installation
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Log "Error: Docker is not installed or not in PATH"
    exit 1
}

# Build the Docker image
Write-Log "Building Docker image..."
docker build -t ebayseoapp:latest .

if ($LASTEXITCODE -ne 0) {
    Write-Log "Error: Docker build failed"
    exit 1
}

# Create network if it doesn't exist
docker network inspect ebayseo-network 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Log "Creating Docker network..."
    docker network create ebayseo-network
}

# Run the container
Write-Log "Starting EbaySEOApp container..."
docker run -d `
    --name ebayseoapp `
    --network ebayseo-network `
    -p 7860:7860 `
    -p 9090:9090 `
    -v ${PWD}/data:/app/data `
    -v ${PWD}/logs:/app/logs `
    -v ${PWD}/backup:/app/backup `
    --env-file $ConfigPath `
    ebayseoapp:latest

if ($LASTEXITCODE -ne 0) {
    Write-Log "Error: Failed to start container"
    exit 1
}

# Wait for the application to start
Start-Sleep -Seconds 5

# Check container health
$health = docker inspect --format='{{.State.Health.Status}}' ebayseoapp
if ($health -ne "healthy") {
    Write-Log "Warning: Container health check failed. Status: $health"
}

Write-Log "Application started successfully!"
Write-Log "Access the dashboard at http://localhost:7860"
Write-Log "Monitor metrics at http://localhost:9090"