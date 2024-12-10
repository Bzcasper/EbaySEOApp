[CmdletBinding()]
param(
    [string]$InputPath = ".\data\raw",
    [string]$OutputPath = ".\data\processed",
    [ValidateSet("json", "csv")]
    [string]$Format = "json",
    [int]$BatchSize = 100,
    [switch]$IncludeImages
)

# Set up error handling
$ErrorActionPreference = "Stop"

# Set up logging
$LogFile = "dataset_creation.log"
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$Level] - $Message" | Tee-Object -Append $LogFile
}

try {
    # Verify Python installation
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        throw "Python is not installed or not in PATH"
    }

    # Build arguments for Python script
    $pythonArgs = @(
        "create_datasets.py",
        "--input-path", $InputPath,
        "--output-path", $OutputPath,
        "--format", $Format,
        "--batch-size", $BatchSize
    )

    if ($IncludeImages) {
        $pythonArgs += "--include-images"
    }

    # Run Python script
    Write-Log "Starting dataset creation process"
    & python $pythonArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Python script execution failed"
    }

    Write-Log "Dataset creation completed successfully"
}
catch {
    Write-Log $_.Exception.Message -Level "ERROR"
    throw
}