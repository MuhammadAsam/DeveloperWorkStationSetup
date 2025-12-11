# =====================================================================
# Setup-DevEnvironment.ps1
# Version: 2025.02.15.02
# Author: Viridians
#
# Purpose:
#   Complete developer workstation setup for Azure, Terraform, Data
#   Engineering, Python, SQL, C#, Docker, and DevOps tooling.
#
# Includes:
#   - Azure CLI, Azure Dev Tools
#   - Terraform, Terraform LS, TFLint (+ optional security tools)
#   - Python + SQLFluff (v3+ compatible)
#   - SSMS, Azure Data Studio
#   - VS Code + recommended extensions
#   - Cascadia Code font (install + enable)
#   - Prettier as the default formatter
#
# Parameters:
#   -IncludeAzureTools
#   -IncludeSQLTools
#   -IncludeDocker
#   -IncludePowerBI
#   -IncludeSecurityTools
#
# NOTE:
#   This script is fully standalone and requires WinGet.
# =====================================================================

param(
    [switch]$IncludeAzureTools,
    [switch]$IncludeSQLTools,
    [switch]$IncludeDocker,
    [switch]$IncludePowerBI,
    [switch]$IncludeSecurityTools
)

# ---------------------------------------------------------------------
# Elevate to Administrator
# ---------------------------------------------------------------------
$curr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $curr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting PowerShell as Administrator..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "powershell"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $($args -join ' ')"
    $psi.Verb      = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ---------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------
function Install-App($id,$name){
    Write-Host "Installing $name ($id)..."
    winget install --id $id --accept-package-agreements --accept-source-agreements -h
}

function Retry-Command([ScriptBlock]$cmd,[int]$n=3,[int]$delay=5){
    for ($i=1; $i -le $n; $i++){
        try { & $cmd; return }
        catch {
            Write-Warning "Attempt $i failed. Retrying in $delay seconds..."
            Start-Sleep -Seconds $delay
        }
    }
    Write-Warning "Command failed after $n attempts."
}

function Ensure-Path {
    $paths = @(
        "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin",
        "$env:ProgramFiles\Git\cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin",
        "$env:ProgramFiles\HashiCorp\Terraform",
        "$env:ProgramFiles\Terraform Language Server",
        "$env:ProgramFiles\tflint",
        "$env:ProgramFiles\tfsec",
        "$env:ProgramFiles\terrascan"
    )

    foreach ($p in $paths){
        if (Test-Path $p -and ($env:PATH -notmatch [regex]::Escape($p))){
            $env:PATH += ";$p"
            Write-Host "Added to PATH: $p"
        }
    }

    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($pythonExe){
        $scripts = Join-Path (Split-Path $pythonExe) "Scripts"
        if (Test-Path $scripts -and ($env:PATH -notmatch [regex]::Escape($scripts))){
            $env:PATH += ";$scripts"
            Write-Host "Added Python Scripts path: $scripts"
        }
    }
}

# ---------------------------------------------------------------------
# INSTALL
# ---------------------------------------------------------------------
Start-Transcript -Path "$env:USERPROFILE\Documents\DataEngSetup.log" -Append
$start = Get-Date

Retry-Command { winget source update }

Install-App "Python.Python.3.12"                   "Python"
Install-App "Git.Git"                              "Git"
Install-App "Microsoft.VisualStudioCode"            "VS Code"
Install-App "Microsoft.AzureCLI"                   "Azure CLI"
Install-App "Microsoft.AzureDataStudio"            "Azure Data Studio"
Install-App "Microsoft.SQLServerManagementStudio"  "SSMS"
Install-App "Microsoft.CascadiaCode"               "Cascadia Code Font"

if ($IncludeDocker)  { Install-App "Docker.DockerDesktop"  "Docker Desktop" }
if ($IncludePowerBI) { Install-App "Microsoft.PowerBI"     "Power BI Desktop" }

# Terraform components
Install-App "HashiCorp.Terraform"                  "Terraform CLI"
Install-App "HashiCorp.TerraformLanguageServer"    "Terraform LS"
Install-App "TerraformLinters.tflint"              "TFLint"

if ($IncludeSecurityTools){
    Install-App "AquaSecurity.tfsec" "tfsec"
    Install-App "Accurics.Terrascan" "Terrascan"
}

# ---------------------------------------------------------------------
# Python & SQLFluff Setup
# ---------------------------------------------------------------------
Retry-Command { python -m ensurepip }
Retry-Command { python -m pip install --upgrade pip wheel setuptools }
Retry-Command {
    python -m pip install `
        pandas `
        pyodbc `
        sqlalchemy `
        azure-identity `
        azure-storage-blob `
        sqlfluff
}

# SQLFluff v3 config
try {
    $sqlfluffCfg = "$env:USERPROFILE\.sqlfluff"
    if (-not (Test-Path $sqlfluffCfg)) {
        "[sqlfluff]`ndialect = tsql" | Set-Content $sqlfluffCfg
        Write-Host "Created SQLFluff config with dialect=tsql"
    }
} catch {
    Write-Warning "SQLFluff config skipped: $($_.Exception.Message)"
}

# Suppress Azure CLI update warnings
$env:AZURE_CORE_SUPPRESS_UPDATE_WARNING = "1"
try { az config set core.check_for_updates false } catch {}

# ---------------------------------------------------------------------
# VS Code Extensions
# ---------------------------------------------------------------------
$codeCmdObj = Get-Command code.cmd -ErrorAction SilentlyContinue
if (-not $codeCmdObj){
    Start-Sleep 10
    $codeCmdObj = Get-Command code.cmd -ErrorAction SilentlyContinue
}

if ($codeCmdObj){
    $codeCmd = $codeCmdObj.Source

    Write-Host "Installing VS Code extensions..."

    # Core Extensions (Option A)
    $coreExt = @(
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "humao.rest-client",
        "dorzey.vscode-sqlfluff",
        "ms-vscode.vs-keybindings",
        "ms-edgedevtools.vscode-edge-devtools",
        "esbenp.prettier-vscode",
        "ms-azuretools.vscode-docker",
        "docker.docker"
    )

    # SQL Extensions
    $sqlExt = @(
        "ms-mssql.mssql",
        "mtxr.sqltools",
        "sqltools-driver.sqlserver",
        "MEngRBatinov.mssql-scripts"
    )

    # Azure Extensions (deprecated ones removed)
    $azureExt = @(
        "ms-azuretools.vscode-azureresourcegroups",
        "ms-azuretools.vscode-azureresources",
        "ms-azuretools.vscode-azurefunctions",
        "ms-azuretools.vscode-logicapps",
        "ms-azuretools.vscode-bicep",
        "ms-azuretools.vscode-azureappservice"
    )

    # Docker extensions (docker.docker already included in core)
    $dockerExt = @("ms-azuretools.vscode-docker")

    # Terraform Extensions (corrected IDs)
    $terraformExt = @(
        "HashiCorp.terraform",
        "ms-azuretools.vscode-azureterraform",
        "run-at-scale.terraform-doc-snippets",
        "mindginative.terraform-snippets",
        "NandovdK.tflint-vscode"
    )

    $exts = $coreExt
    if ($IncludeSQLTools)  { $exts += $sqlExt }
    if ($IncludeAzureTools){ $exts += $azureExt }
    if ($IncludeDocker)    { $exts += $dockerExt }
    $exts += $terraformExt

    $installed = & $codeCmd --list-extensions

    foreach ($e in $exts){
        if ($installed -notcontains $e){
            try { Retry-Command { & $codeCmd --install-extension $e --force } }
            catch { Write-Warning "Failed to install extension: $e" }
        }
    }
} else {
    Write-Warning "VS Code CLI unavailable. Extensions skipped."
}

# ---------------------------------------------------------------------
# Cascadia Code VS Code Integration + Prettier Defaults
# ---------------------------------------------------------------------
$vsSettings = "$env:APPDATA\Code\User\settings.json"
if (-not (Test-Path $vsSettings)) {
    @{} | ConvertTo-Json | Out-File $vsSettings
}

$json = Get-Content $vsSettings -Raw | ConvertFrom-Json

# Font settings
$json."editor.fontFamily"    = "Cascadia Code, Consolas, 'Courier New', monospace"
$json."editor.fontLigatures" = $true

# Prettier as default formatter
$json."editor.defaultFormatter" = "esbenp.prettier-vscode"
$json."editor.formatOnSave"     = $true

# Set language-specific defaults
$json."[json]"."editor.defaultFormatter"       = "esbenp.prettier-vscode"
$json."[yaml]"."editor.defaultFormatter"       = "esbenp.prettier-vscode"
$json."[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode"
$json."[javascript]"."editor.defaultFormatter" = "esbenp.prettier-vscode"
$json."[markdown]"."editor.defaultFormatter"   = "esbenp.prettier-vscode"

$json | ConvertTo-Json -Depth 10 | Set-Content $vsSettings -Encoding UTF8

Write-Host "Cascadia Code enabled + Prettier set as default."

# ---------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------
Ensure-Path

$tests=@(
    @{Name="Python"      ;Cmd="python --version"},
    @{Name="Git"         ;Cmd="git --version"},
    @{Name="AzureCLI"    ;Cmd="az --version"},
    @{Name="Terraform"   ;Cmd="terraform version"},
    @{Name="Terraform-LS";Cmd="terraform-ls --version"},
    @{Name="TFLint"      ;Cmd="tflint --version"},
    @{Name="SQLFluff"    ;Cmd="sqlfluff --version"}
)

foreach ($t in $tests){
    Write-Host "`n$($t.Name):"
    try { Invoke-Expression "$($t.Cmd) 2>&1" }
    catch { Write-Warning "$($t.Name) failed: $($_.Exception.Message)" }
}

$elapsed = (Get-Date) - $start
Stop-Transcript

Write-Host "`n=============================================================="
Write-Host "Developer Environment Ready! (Version 2025.02.15.02)"
Write-Host "Duration: $($elapsed.ToString('hh\:mm\:ss'))"
Write-Host "=============================================================="
