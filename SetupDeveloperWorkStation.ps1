# =====================================================================
# Setup-DeveloperWorkstation.ps1
# Version: 2026.01.11.02
# Purpose: Install-only developer workstation setup
# NOTE: This script is fully standalone and requires WinGet.
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
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [Environment]::GetEnvironmentVariable("PATH","User")
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

Install-App "Python.Python.3.12"         "Python"
Install-App "Git.Git"                    "Git"
Install-App "Microsoft.DotNet.SDK.8"     ".NET SDK"
Install-App "Microsoft.VisualStudioCode" "VS Code"
Install-App "Microsoft.AzureCLI"         "Azure CLI"
Install-App "HashiCorp.Terraform"        "Terraform"

# Optional tools
if ($IncludeDocker){ Install-App "Docker.DockerDesktop" "Docker" }
if ($IncludePowerBI){ Install-App "Microsoft.PowerBI" "Power BI" }

# Terraform ecosystem
Install-App "HashiCorp.TerraformLS" "Terraform Language Server"
Install-App "TerraformLinters.tflint" "TFLint"

if ($IncludeSecurityTools){
    Install-App "AquaSecurity.tfsec"  "tfsec"
    Install-App "Accurics.Terrascan"  "Terrascan"
}

# SSMS (always latest)
Install-SSMS

# Azure CLI self-upgrade
try {
    az upgrade --yes --only-show-errors 2>$null
} catch {}

# ---------------------------------------------------------------------
# PATH refresh BEFORE using tools
# ---------------------------------------------------------------------
Refresh-Path

# ---------------------------------------------------------------------
# Python tooling
# ---------------------------------------------------------------------
Retry { python --version }
Retry { python -m ensurepip }
Retry { python -m pip install --upgrade pip setuptools wheel }
Retry {
    python -m pip install `
        pandas pyodbc sqlalchemy `
        azure-identity azure-storage-blob `
        sqlfluff
}

# ---------------------------------------------------------------------
# VS Code extensions
# ---------------------------------------------------------------------
$codeCmd = Get-Command code.cmd -ErrorAction SilentlyContinue
if ($codeCmd){

    $extensions = @(
        # Core
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "esbenp.prettier-vscode",
        "dorzey.vscode-sqlfluff",
        "ms-windows-ai-studio.windows-ai-studio",

        # Python / Jupyter
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-python.debugpy",
        "ms-python.vscode-python-envs",
        "ms-toolsai.jupyter",
        "ms-toolsai.vscode-jupyter-cell-tags",
        "ms-toolsai.jupyter-keymap",
        "ms-toolsai.vscode-jupyter-slideshow",

        # Azure / IaC
        "ms-azuretools.vscode-bicep",
        "ms-azuretools.vscode-docker",
        "docker.docker",
        "HashiCorp.terraform",
        "ms-azuretools.vscode-azureterraform",

        # DevOps / GitHub
        "github.vscode-pull-request-github",
        "github.vscode-github-actions",
        "github.remotehub",
        "ms-azure-devops.azure-pipelines",

        # Fonts
        "seyyedkhandon.firacode"
    )

    $installed = & $codeCmd --list-extensions
    foreach($ext in $extensions){
        if ($installed -notcontains $ext){
            try {
                & $codeCmd --install-extension $ext --force
            } catch {
                Write-Warning "Extension failed: $ext"
            }
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
