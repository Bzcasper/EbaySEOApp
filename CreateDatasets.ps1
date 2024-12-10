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
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] - $Message"
    Write-Output $logMessage
    
    $logPath = "dataset_creation.log"
    Add-Content -Path $logPath -Value $logMessage
}

# Initialize directories
function Initialize-DirectoryStructure {
    param(
        [string[]]$Paths
    )

    foreach ($path in $Paths) {
        if (-not (Test-Path -Path $path)) {
            Write-Log -Message "Creating directory: $path"
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

# Process images
function Convert-Images {
    param(
        [string]$ImagePath
    )

    Write-Log -Message "Processing images from: $ImagePath"
    $images = Get-ChildItem -Path $ImagePath -Filter "*.jpg" -Recurse

    foreach ($image in $images) {
        try {
            Write-Log -Message "Processing image: $($image.Name)"
            # Add image processing logic here
            # Example: Convert-Image -Path $image.FullName -Destination $OutputPath
        }
        catch {
            Write-Log -Message "Error processing image $($image.Name): $_" -Level "ERROR"
        }
    }
}

# Create dataset
function New-ProcessedDataset {
    param(
        [string]$InputFile,
        [string]$OutputFile
    )

    try {
        Write-Log -Message "Creating dataset from: $InputFile"

        # Read input data
        $data = Get-Content -Path $InputFile -Raw | ConvertFrom-Json

        # Process data in batches
        $processedData = @()
        $totalItems = $data.Count
        $batchCount = [math]::Ceiling($totalItems / $BatchSize)

        for ($i = 0; $i -lt $totalItems; $i += $BatchSize) {
            $batchNumber = [math]::Floor($i / $BatchSize) + 1
            Write-Progress -Activity "Processing Data" -Status "Batch $batchNumber of $batchCount" -PercentComplete (($i / $totalItems) * 100)

            $batch = $data[$i..([Math]::Min($i + $BatchSize - 1, $totalItems - 1))]

            foreach ($item in $batch) {
                $processedItem = @{
                    id = $item.id
                    title = $item.title
                    price = $item.price
                    description = $item.description
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $processedData += $processedItem
            }
        }

        # Save dataset in specified format
        Write-Log -Message "Saving dataset in $Format format"
        switch ($Format.ToLower()) {
            "json" {
                $processedData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile
            }
            "csv" {
                $processedData | Export-Csv -Path $OutputFile -NoTypeInformation
            }
        }

        Write-Log -Message "Dataset created successfully: $OutputFile"
    }
    catch {
        Write-Log -Message "Error creating dataset: $_" -Level "ERROR"
        throw
    }
}

# Main execution
try {
    Write-Log -Message "Starting dataset creation process"

    # Initialize directories
    Initialize-DirectoryStructure -Paths @($InputPath, $OutputPath)

    # Process images if requested
    if ($IncludeImages) {
        Convert-Images -ImagePath $InputPath
    }

    # Create output filename with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputFile = Join-Path -Path $OutputPath -ChildPath "dataset_${timestamp}.$Format"

    # Create input data path
    $inputDataFile = Join-Path -Path $InputPath -ChildPath "data.json"
    if (-not (Test-Path -Path $inputDataFile)) {
        throw "Input data file not found: $inputDataFile"
    }

    # Create dataset
    New-ProcessedDataset -InputFile $inputDataFile -OutputFile $outputFile

    Write-Log -Message "Dataset creation completed successfully"
}
catch {
    Write-Log -Message "Dataset creation failed: $_" -Level "ERROR"
    throw
}