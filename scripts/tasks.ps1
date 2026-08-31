param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("validate", "package", "clean")]
    [string]$Task
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$TocName = "Eds Custom Addon.toc"
$DistDir = "dist"
$StageDir = Join-Path $DistDir "stage"
$ZipPath = Join-Path $DistDir "EdsCustomAddon.zip"
$AddonFolderName = "Eds Custom Addon"

function Get-TocLuaFiles {
    if (-not (Test-Path -LiteralPath $TocName)) {
        throw "Missing TOC: $TocName"
    }
    Get-Content -LiteralPath $TocName |
        Where-Object { $_ -match '\.lua\s*$' } |
        ForEach-Object { $_.Trim() }
}

function Invoke-Validate {
    $files = @(Get-TocLuaFiles)
    if ($files.Count -eq 0) {
        throw "TOC lists no Lua files"
    }
    $missing = @()
    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath $file)) {
            $missing += $file
        }
    }
    if ($missing.Count -gt 0) {
        throw "Missing Lua files listed in TOC: $($missing -join ', ')"
    }
    Write-Host "OK: $TocName ($($files.Count) lua files)"
}

function Invoke-Package {
    Invoke-Validate
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
    if (Test-Path -LiteralPath $StageDir) {
        Remove-Item -LiteralPath $StageDir -Recurse -Force
    }
    $addonStage = Join-Path $StageDir $AddonFolderName
    New-Item -ItemType Directory -Force -Path $addonStage | Out-Null
    Copy-Item -LiteralPath $TocName -Destination $addonStage
    Copy-Item -LiteralPath "Core" -Destination (Join-Path $addonStage "Core") -Recurse
    Copy-Item -LiteralPath "Modules" -Destination (Join-Path $addonStage "Modules") -Recurse
    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
    Compress-Archive -Path $addonStage -DestinationPath $ZipPath
    Write-Host "OK: $ZipPath"
}

function Invoke-Clean {
    if (Test-Path -LiteralPath $DistDir) {
        Remove-Item -LiteralPath $DistDir -Recurse -Force
    }
    Write-Host "OK: cleaned $DistDir"
}

switch ($Task) {
    "validate" { Invoke-Validate }
    "package" { Invoke-Package }
    "clean" { Invoke-Clean }
}
