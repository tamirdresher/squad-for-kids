<#
.SYNOPSIS
    Upload podcast audio files to OneDrive or Azure Blob Storage

.DESCRIPTION
    This script uploads MP3/WAV podcast files to cloud storage and returns a shareable link.
    Three methods are supported (in order of preference):
    1. OneDrive Sync Folder - Simplest, works immediately if OneDrive is synced
    2. Microsoft Graph API - Proper API integration (requires auth setup)
    3. Azure Blob Storage - For Azure-native workflows (requires Azure CLI)

.PARAMETER FilePath
    Path to the audio file (MP3 or WAV) to upload

.PARAMETER Method
    Upload method: 'OneDriveSync', 'GraphAPI', or 'AzureBlob'. Default: 'OneDriveSync'

.PARAMETER OneDrivePath
    Relative path within OneDrive sync folder. Default: 'Squad/Podcasts'

.PARAMETER StorageAccount
    Azure Storage Account name (for AzureBlob method)

.PARAMETER Container
    Azure Blob container name (for AzureBlob method). Default: 'podcasts'

.EXAMPLE
    .\upload-podcast.ps1 -FilePath "RESEARCH_REPORT-audio.mp3"
    
.EXAMPLE
    .\upload-podcast.ps1 -FilePath "EXECUTIVE_SUMMARY-audio.mp3" -Method GraphAPI

.EXAMPLE
    .\upload-podcast.ps1 -FilePath "audio.mp3" -Method AzureBlob -StorageAccount "mystorage" -Container "podcasts"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('OneDriveSync', 'GraphAPI', 'AzureBlob')]
    [string]$Method = 'OneDriveSync',
    
    [Parameter(Mandatory=$false)]
    [string]$OneDrivePath = 'Squad/Podcasts',
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccount,
    
    [Parameter(Mandatory=$false)]
    [string]$Container = 'podcasts'
)

function Upload-ToOneDriveSync {
    param([string]$File, [string]$RelativePath)
    
    Write-Host "📁 Using OneDrive Sync Folder method..." -ForegroundColor Cyan
    
    # Find OneDrive folder
    $oneDriveRoot = $null
    $possiblePaths = @(
        $env:OneDrive,
        $env:OneDriveCommercial,
        "$env:USERPROFILE\OneDrive",
        "$env:USERPROFILE\OneDrive - Microsoft"
    )
    
    foreach ($path in $possiblePaths) {
        if ($path -and (Test-Path $path)) {
            $oneDriveRoot = $path
            break
        }
    }
    
    if (-not $oneDriveRoot) {
        throw "OneDrive folder not found. Please ensure OneDrive is installed and syncing."
    }
    
    Write-Host "✓ Found OneDrive folder: $oneDriveRoot" -ForegroundColor Green
    
    # Create destination folder
    $destFolder = Join-Path $oneDriveRoot $RelativePath
    if (-not (Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        Write-Host "✓ Created folder: $destFolder" -ForegroundColor Green
    }
    
    # Copy file
    $destFile = Join-Path $destFolder (Split-Path $File -Leaf)
    Copy-Item -Path $File -Destination $destFile -Force
    Write-Host "✓ Copied to: $destFile" -ForegroundColor Green
    
    # Wait for OneDrive to sync (basic heuristic)
    Write-Host "⏳ Waiting for OneDrive sync (3 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    # Return local path (OneDrive will sync it)
    return @{
        Success = $true
        LocalPath = $destFile
        Message = "File copied to OneDrive sync folder. Share link: Right-click file in OneDrive → Share"
        ShareInstructions = "To get shareable link: Open OneDrive folder, right-click '$destFile', select 'Share', and copy the link."
    }
}

function Upload-ToGraphAPI {
    param([string]$File)
    
    Write-Host "🔐 Using Microsoft Graph API method..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠️  SETUP REQUIRED:" -ForegroundColor Yellow
    Write-Host "   1. Register Azure AD app: https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade" -ForegroundColor Yellow
    Write-Host "   2. Add API permission: Files.ReadWrite (delegated or application)" -ForegroundColor Yellow
    Write-Host "   3. Set environment variables:" -ForegroundColor Yellow
    Write-Host "      - GRAPH_CLIENT_ID=<your-client-id>" -ForegroundColor Yellow
    Write-Host "      - GRAPH_CLIENT_SECRET=<your-client-secret>" -ForegroundColor Yellow
    Write-Host "      - GRAPH_TENANT_ID=<your-tenant-id>" -ForegroundColor Yellow
    Write-Host ""
    
    $clientId = $env:GRAPH_CLIENT_ID
    $clientSecret = $env:GRAPH_CLIENT_SECRET
    $tenantId = $env:GRAPH_TENANT_ID
    
    if (-not ($clientId -and $clientSecret -and $tenantId)) {
        throw "Graph API credentials not configured. Please set GRAPH_CLIENT_ID, GRAPH_CLIENT_SECRET, and GRAPH_TENANT_ID environment variables."
    }
    
    # Get access token
    Write-Host "🔑 Obtaining access token..." -ForegroundColor Cyan
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $tokenBody = @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }
    
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    $accessToken = $tokenResponse.access_token
    
    # Upload file
    $fileName = Split-Path $File -Leaf
    $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/root:/$OneDrivePath/$fileName:/content"
    
    Write-Host "📤 Uploading $fileName..." -ForegroundColor Cyan
    $headers = @{
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/octet-stream"
    }
    
    $fileBytes = [System.IO.File]::ReadAllBytes($File)
    $uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method Put -Headers $headers -Body $fileBytes
    
    # Create sharing link
    Write-Host "🔗 Creating sharing link..." -ForegroundColor Cyan
    $itemId = $uploadResponse.id
    $shareUrl = "https://graph.microsoft.com/v1.0/me/drive/items/$itemId/createLink"
    $shareBody = @{
        type = "view"
        scope = "anonymous"
    } | ConvertTo-Json
    
    $shareHeaders = @{
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }
    
    $shareResponse = Invoke-RestMethod -Uri $shareUrl -Method Post -Headers $shareHeaders -Body $shareBody
    
    return @{
        Success = $true
        ShareLink = $shareResponse.link.webUrl
        DownloadUrl = $uploadResponse.'@microsoft.graph.downloadUrl'
        Message = "File uploaded successfully via Graph API"
    }
}

function Upload-ToAzureBlob {
    param([string]$File, [string]$Account, [string]$ContainerName)
    
    Write-Host "☁️  Using Azure Blob Storage method..." -ForegroundColor Cyan
    
    if (-not $Account) {
        throw "Storage account name is required for Azure Blob method. Use -StorageAccount parameter."
    }
    
    # Check if Azure CLI is installed
    $azCmd = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azCmd) {
        throw "Azure CLI (az) not found. Install from: https://aka.ms/installazurecliwindows"
    }
    
    # Check if logged in
    Write-Host "🔐 Checking Azure CLI login..." -ForegroundColor Cyan
    $accountInfo = az account show 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged into Azure CLI. Run 'az login' first."
    }
    
    Write-Host "✓ Logged in as: $($accountInfo.user.name)" -ForegroundColor Green
    
    # Upload blob
    $blobName = Split-Path $File -Leaf
    Write-Host "📤 Uploading to $Account/$ContainerName/$blobName..." -ForegroundColor Cyan
    
    az storage blob upload `
        --account-name $Account `
        --container-name $ContainerName `
        --name $blobName `
        --file $File `
        --overwrite `
        --auth-mode login | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload blob. Check storage account permissions."
    }
    
    # Generate SAS URL (valid for 90 days)
    Write-Host "🔗 Generating SAS URL..." -ForegroundColor Cyan
    $expiryDate = (Get-Date).AddDays(90).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $sasUrl = az storage blob generate-sas `
        --account-name $Account `
        --container-name $ContainerName `
        --name $blobName `
        --permissions r `
        --expiry $expiryDate `
        --https-only `
        --full-uri `
        --auth-mode login `
        --output tsv
    
    return @{
        Success = $true
        ShareLink = $sasUrl
        BlobUrl = "https://$Account.blob.core.windows.net/$ContainerName/$blobName"
        Message = "File uploaded to Azure Blob Storage (SAS valid for 90 days)"
    }
}

# Main execution
try {
    # Validate file exists
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $fileInfo = Get-Item $FilePath
    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    
    Write-Host ""
    Write-Host "🎙️  Podcast Upload Tool" -ForegroundColor Magenta
    Write-Host "========================" -ForegroundColor Magenta
    Write-Host "File: $($fileInfo.Name) ($fileSizeMB MB)" -ForegroundColor White
    Write-Host "Method: $Method" -ForegroundColor White
    Write-Host ""
    
    # Execute upload
    $result = switch ($Method) {
        'OneDriveSync' { Upload-ToOneDriveSync -File $FilePath -RelativePath $OneDrivePath }
        'GraphAPI'     { Upload-ToGraphAPI -File $FilePath }
        'AzureBlob'    { Upload-ToAzureBlob -File $FilePath -Account $StorageAccount -ContainerName $Container }
    }
    
    # Output results
    Write-Host ""
    Write-Host "✅ SUCCESS" -ForegroundColor Green
    Write-Host "==========" -ForegroundColor Green
    Write-Host $result.Message -ForegroundColor White
    
    if ($result.ShareLink) {
        Write-Host ""
        Write-Host "🔗 Share Link:" -ForegroundColor Cyan
        Write-Host $result.ShareLink -ForegroundColor Yellow
    }
    
    if ($result.LocalPath) {
        Write-Host ""
        Write-Host "📁 Local Path:" -ForegroundColor Cyan
        Write-Host $result.LocalPath -ForegroundColor Yellow
    }
    
    if ($result.ShareInstructions) {
        Write-Host ""
        Write-Host "ℹ️  Next Steps:" -ForegroundColor Cyan
        Write-Host $result.ShareInstructions -ForegroundColor White
    }
    
    Write-Host ""
    
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR" -ForegroundColor Red
    Write-Host "========" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    
    # Provide helpful guidance
    if ($Method -eq 'OneDriveSync') {
        Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   - Ensure OneDrive is installed and syncing" -ForegroundColor Yellow
        Write-Host "   - Try: Get-Item `$env:OneDrive" -ForegroundColor Yellow
    } elseif ($Method -eq 'GraphAPI') {
        Write-Host "💡 Try OneDrive Sync method instead:" -ForegroundColor Yellow
        Write-Host "   .\upload-podcast.ps1 -FilePath '$FilePath' -Method OneDriveSync" -ForegroundColor Yellow
    } elseif ($Method -eq 'AzureBlob') {
        Write-Host "💡 Try OneDrive Sync method instead:" -ForegroundColor Yellow
        Write-Host "   .\upload-podcast.ps1 -FilePath '$FilePath' -Method OneDriveSync" -ForegroundColor Yellow
    }
    
    Write-Host ""
    exit 1
}
