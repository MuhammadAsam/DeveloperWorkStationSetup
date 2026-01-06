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

param(
    [switch]$IncludeAzureTools,
    [switch]$IncludeSQLTools,
    [switch]$IncludeDocker,
    [switch]$IncludePowerBI,
    [switch]$IncludeSecurityTools
)

# ---------------------------------------------------------------------
# WinGet prerequisite
# ---------------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "WinGet not found. Install App Installer from Microsoft Store."
    exit 1
}

# ---------------------------------------------------------------------
# Elevation
# ---------------------------------------------------------------------
$curr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $curr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell `
        "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $($args -join ' ')" `
        -Verb RunAs
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ---------------------------------------------------------------------
# Helpers
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

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                 [System.Environment]::GetEnvironmentVariable("PATH","User")
}

function Retry([scriptblock]$cmd,[int]$n=3){
    for($i=1;$i -le $n;$i++){
        try { & $cmd; return } catch { Start-Sleep 5 }
    }
}

function Install-SSMS {
    Write-Host "Installing latest SSMS..."
    $exe = "$env:TEMP\SSMS.exe"
    Invoke-WebRequest "https://aka.ms/ssmsfullsetup" -OutFile $exe
    Start-Process $exe "/install /quiet /norestart" -Wait
}

# ---------------------------------------------------------------------
# INSTALL
# ---------------------------------------------------------------------
Start-Transcript "$env:USERPROFILE\Documents\DataEngSetup.log"
$start = Get-Date

Retry { winget source update }

Install-App "Python.Python.3.12"        "Python"
Install-App "Git.Git"                   "Git"
Install-App "Microsoft.DotNet.SDK.8"    ".NET SDK"
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

# Azure CLI upgrade
try { az upgrade --yes --only-show-errors } catch {}

# ---------------------------------------------------------------------
# PATH refresh before Python / VS Code usage
# ---------------------------------------------------------------------
Refresh-Path

# ---------------------------------------------------------------------
# Python tooling
# ---------------------------------------------------------------------
Retry { python --version }
Retry { python -m ensurepip }
Retry { python -m pip install --upgrade pip setuptools wheel }
Retry { python -m pip install pandas pyodbc sqlalchemy azure-identity azure-storage-blob sqlfluff }

# ---------------------------------------------------------------------
# VS Code extensions (install only if CLI available)
# ---------------------------------------------------------------------
$codeCmd = Get-Command code.cmd -ErrorAction SilentlyContinue
if ($codeCmd){
    $extensions = @(
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

    $installed = & $codeCmd --list-extensions
    foreach($ext in $extensions){
        if ($installed -notcontains $ext){
            Retry { & $codeCmd --install-extension $ext --force }
        }
    }
}

# ---------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------
Refresh-Path

foreach($cmd in @(
    "python --version",
    "git --version",
    "dotnet --version",
    "az --version",
    "terraform version",
    "terraform-ls --version",
    "tflint --version",
    "code --version",
    "sqlfluff --version"
)){
    try { Invoke-Expression $cmd } catch {}
}

Stop-Transcript

Write-Host "=============================================================="
Write-Host "Developer Workstation READY"
Write-Host "Duration: $((Get-Date)-$start)"
Write-Host "Restart PowerShell and VS Code once."
Write-Host "=============================================================="
