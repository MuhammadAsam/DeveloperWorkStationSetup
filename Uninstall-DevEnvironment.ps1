# =====================================================================
# Microsoft Developer Workstation Uninstall
# Removes: Azure, Terraform, Data, VS Code + tooling
# =====================================================================

# Elevate
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

function Uninstall-App($id,$name){
    try{
        Write-Host "Uninstalling $name ($id)..."
        winget uninstall --id $id -h
    }catch{
        Write-Warning "Skip ${name}: not installed or uninstall failed."
    }
}

Start-Transcript -Path "$env:USERPROFILE\Documents\DataEngUninstall.log" -Append

$toRemove = @(
    "Python.Python.3.12",                 # Python
    "Git.Git",                            # Git
    "Microsoft.VisualStudioCode",         # VS Code
    "Microsoft.AzureCLI",                 # Azure CLI
    "Microsoft.AzureDataStudio",          # Azure Data Studio
    "Microsoft.SQLServerManagementStudio",# SSMS
    "Docker.DockerDesktop",               # Docker Desktop
    "Microsoft.PowerBI",                  # Power BI Desktop
    "Hashicorp.Terraform",                # Terraform CLI
    "Hashicorp.TerraformLanguageServer",  # Terraform Language Server
    "TerraformLinters.tflint",            # TFLint
    "AquaSecurity.tfsec",                 # tfsec
    "Accurics.Terrascan"                  # Terrascan
)

foreach($pkg in $toRemove){
    Uninstall-App $pkg $pkg
}

Stop-Transcript
Write-Host "Uninstall complete. See log: $env:USERPROFILE\Documents\DataEngUninstall.log"
