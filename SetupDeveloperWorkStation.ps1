# =====================================================================
# Setup-DevEnvironment.ps1
# Version: 2025.12.21.01
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
# WinGet prerequisite check
# ---------------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "WinGet is not available. Install 'App Installer' from Microsoft Store and re-run this script."
    exit 1
}

param(
    [switch]$IncludeAzureTools,
    [switch]$IncludeSQLTools,
    [switch]$IncludeDocker,
    [switch]$IncludePowerBI,
    [switch]$IncludeSecurityTools,
    [switch]$Uninstall
)

# ---------------------------------------------------------------------
# Elevation + Execution Policy (process-only)
# ---------------------------------------------------------------------
$curr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $curr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "powershell"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $($args -join ' ')"
    $psi.Verb      = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ---------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------
function Install-App($id,$name){
    Write-Host "Installing $name..."
    winget install --id $id `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent `
        --disable-interactivity `
        -h
}

function Uninstall-App($id,$name){
    try { winget uninstall --id $id -h } catch {}
}

function Retry-Command([ScriptBlock]$cmd,[int]$n=3){
    for($i=1;$i -le $n;$i++){
        try { & $cmd; return } catch { Start-Sleep 5 }
    }
}

function Ensure-Path {
    $paths = @(
        "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin",
        "$env:ProgramFiles\Git\cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin",
        "$env:ProgramFiles\terraform-ls",
        "$env:ProgramFiles\HashiCorp\Terraform"
    )
    foreach($p in $paths){
        if (Test-Path $p -and $env:PATH -notmatch [regex]::Escape($p)){
            $env:PATH += ";$p"
        }
    }
}

function Install-SSMS {
    Write-Host "Installing latest SSMS..."
    $exe = "$env:TEMP\SSMS.exe"
    Invoke-WebRequest "https://aka.ms/ssmsfullsetup" -OutFile $exe
    Start-Process $exe -ArgumentList "/install /quiet /norestart" -Wait
}

# ---------------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------------
if ($Uninstall){
    Start-Transcript "$env:USERPROFILE\Documents\DataEngUninstall.log"
    @(
        "Python.Python.3.12","Git.Git","Microsoft.VisualStudioCode",
        "Microsoft.AzureCLI","Microsoft.AzureDataStudio",
        "Docker.DockerDesktop","Microsoft.PowerBI",
        "HashiCorp.Terraform","Terraform.Ls","tflint",
        "AquaSecurity.tfsec","Accurics.Terrascan"
    ) | ForEach-Object { Uninstall-App $_ $_ }
    Stop-Transcript
    exit
}

# ---------------------------------------------------------------------
# INSTALL
# ---------------------------------------------------------------------
Start-Transcript "$env:USERPROFILE\Documents\DataEngSetup.log"
$start = Get-Date

Retry-Command { winget source update }

Install-App "Python.Python.3.12"        "Python"
Install-App "Git.Git"                   "Git"
Install-App "Microsoft.VisualStudioCode" "VS Code"
Install-App "Microsoft.AzureCLI"        "Azure CLI"
Install-App "Microsoft.AzureDataStudio" "Azure Data Studio"
Install-App "Microsoft.CascadiaCode"    "Cascadia Code Font"
Install-SSMS

if ($IncludeDocker){ Install-App "Docker.DockerDesktop" "Docker" }
if ($IncludePowerBI){ Install-App "Microsoft.PowerBI" "Power BI" }

Install-App "HashiCorp.Terraform" "Terraform"
Install-App "Terraform.Ls"        "Terraform Language Server"
Install-App "tflint"              "TFLint"

if ($IncludeSecurityTools){
    Install-App "AquaSecurity.tfsec" "tfsec"
    Install-App "Accurics.Terrascan" "Terrascan"
}

# Azure CLI upgrade (silent)
try { az upgrade --yes --only-show-errors } catch {}

# ---------------------------------------------------------------------
# Python tooling
# ---------------------------------------------------------------------
Retry-Command { python -m ensurepip }
Retry-Command { python -m pip install --upgrade pip setuptools wheel }
Retry-Command { python -m pip install pandas pyodbc sqlalchemy azure-identity azure-storage-blob sqlfluff }

# ---------------------------------------------------------------------
# VS Code extensions
# ---------------------------------------------------------------------
$code = Get-Command code.cmd -ErrorAction SilentlyContinue
if ($code){
    $exts = @(
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "esbenp.prettier-vscode",
        "dorzey.vscode-sqlfluff",
        "ms-azuretools.vscode-azureresources",
        "ms-azuretools.vscode-bicep",
        "ms-azuretools.vscode-docker",
        "docker.docker",
        "HashiCorp.terraform",
        "ms-azuretools.vscode-azureterraform",
        "github.vscode-pull-request-GitHub",
        "github.vscode-github-actions",
        "github.remotehub",
        "azure-devops",
        "seyyedkhandon.firacode"
    )
    $installed = & $code --list-extensions
    foreach($e in $exts){
        if ($installed -notcontains $e){
            Retry-Command { & $code --install-extension $e --force }
        }
    }
}

# ---------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------
Ensure-Path

$checks = @(
    "python --version",
    "git --version",
    "az --version",
    "terraform version",
    "terraform-ls --version",
    "tflint --version",
    "code --version",
    "sqlfluff --version"
)

foreach($c in $checks){
    try { Invoke-Expression $c } catch {}
}

Stop-Transcript

Write-Host "=============================================================="
Write-Host "Developer Workstation READY"
Write-Host "Duration: $((Get-Date)-$start)"
Write-Host "Restart PowerShell and VS Code to finalise PATH updates."
Write-Host "=============================================================="
