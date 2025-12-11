# =====================================================================
# Uninstall-DevEnvironment.ps1
# Version: 2025.02.15.02
# Author: Viridians
#
# Purpose:
#   Clean removal of all components installed by the setup script.
# =====================================================================

# Elevate
$curr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $curr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting PowerShell as Administrator..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "powershell"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb      = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

function Uninstall-App($id,$name){
    try {
        Write-Host "Uninstalling $name ($id)..."
        winget uninstall --id $id -h
    }
    catch {
        Write-Warning "Skipping ${name}: not installed or uninstall failed."
    }
}

Start-Transcript -Path "$env:USERPROFILE\Documents\DataEngUninstall.log" -Append

$toRemove = @(
    "Python.Python.3.12",
    "Git.Git",
    "Microsoft.VisualStudioCode",
    "Microsoft.AzureCLI",
    "Microsoft.AzureDataStudio",
    "Microsoft.SQLServerManagementStudio",
    "Microsoft.CascadiaCode",
    "Docker.DockerDesktop",
    "Microsoft.PowerBI",
    "HashiCorp.Terraform",
    "HashiCorp.TerraformLanguageServer",
    "TerraformLinters.tflint",
    "AquaSecurity.tfsec",
    "Accurics.Terrascan"
)

foreach ($pkg in $toRemove){
    Uninstall-App $pkg $pkg
}

Stop-Transcript
Write-Host "Uninstall complete! (Version 2025.02.15.02)"
