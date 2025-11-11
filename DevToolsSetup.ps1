# =====================================================================
# Microsoft Developer Work station setup - Setup & Uninstall
# Azure DotNet and Azure Management Tools
# Data Engineer Tools
# =====================================================================
#  Purpose:
#     Complete enterprise-ready environment for Data, Azure, Terraform,
#     and Infrastructure-as-Code development.
#     C#, Python
#     Visual Studio Code with recommended extensions
# =====================================================================

param(
    [switch]$IncludeAzureTools,
    [switch]$IncludeSQLTools,
    [switch]$IncludeDocker,
    [switch]$IncludePowerBI,
    [switch]$IncludeSecurityTools,  # Security scanners (tfsec, terrascan)
    [switch]$Uninstall
)

# ---------------------------------------------------------------------
# --- Elevate + execution policy bypass
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
# --- Helper utilities
# ---------------------------------------------------------------------
function Install-App($id,$name){
    Write-Host "Installing $name ($id)..."
    winget install --id $id --accept-package-agreements --accept-source-agreements -h
}

function Uninstall-App($id,$name){
    try{
        Write-Host "Uninstalling $name ($id)..."
        winget uninstall --id $id -h
    }catch{
        Write-Warning "Skip $name: not installed or uninstall failed."
    }
}

function Retry-Command([ScriptBlock]$cmd,[int]$n=3,[int]$delay=5){
    for($i=1;$i -le $n;$i++){
        try { & $cmd; return } catch {
            Write-Warning "Attempt $i failed. Retrying in $delay s..."
            Start-Sleep -Seconds $delay
        }
    }
    Write-Warning "Command failed after $n attempts."
}

function Ensure-Path {
    # Common dev tools
    $paths = @(
        "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin",
        "$env:ProgramFiles\Git\cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin",
        # Likely Terraform-related install locations (best-effort)
        "$env:ProgramFiles\HashiCorp\Terraform",
        "$env:ProgramFiles\terraform-ls",
        "$env:ProgramFiles\tflint",
        "$env:ProgramFiles\tfsec",
        "$env:ProgramFiles\terrascan"
    )
    foreach($p in $paths){
        if ((Test-Path $p) -and ($env:PATH -notmatch [regex]::Escape($p))){
            $env:PATH += ";$p"
            Write-Host "Added $p to PATH"
        }
    }

    # Python Scripts folder
    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($pythonExe) {
        $scriptsPath = Join-Path (Split-Path $pythonExe) "Scripts"
        if ((Test-Path $scriptsPath) -and ($env:PATH -notmatch [regex]::Escape($scriptsPath))){
            $env:PATH += ";$scriptsPath"
            Write-Host "Added Python Scripts path: $scriptsPath"
        }
    }
}

# ---------------------------------------------------------------------
# --- UNINSTALL
# ---------------------------------------------------------------------
if ($Uninstall){
    Start-Transcript -Path "$env:USERPROFILE\Documents\DataEngUninstall.log" -Append
    $toRemove = @(
        "Python.Python.3.12","Git.Git","Microsoft.VisualStudioCode",
        "Microsoft.AzureCLI","Microsoft.AzureDataStudio",
        "Docker.DockerDesktop","Microsoft.PowerBI",
        "HashiCorp.Terraform","Terraform.Ls","tflint",
        "AquaSecurity.tfsec","Accurics.Terrascan"
    )
    foreach($pkg in $toRemove){ Uninstall-App $pkg $pkg }
    Stop-Transcript
    Write-Host "Uninstall complete."
    exit 0
}

# ---------------------------------------------------------------------
# --- INSTALL
# ---------------------------------------------------------------------
Start-Transcript -Path "$env:USERPROFILE\Documents\DataEngSetup.log" -Append
$start = Get-Date

# --- Core software ---
Install-App "Python.Python.3.12" "Python"
Install-App "Git.Git" "Git"
Install-App "Microsoft.VisualStudioCode" "VS Code"
Install-App "Microsoft.AzureCLI" "Azure CLI"
Install-App "Microsoft.AzureDataStudio" "Azure Data Studio"
if ($IncludeDocker){ Install-App "Docker.DockerDesktop" "Docker" }
if ($IncludePowerBI){ Install-App "Microsoft.PowerBI" "Power BI" }

# --- Terraform toolchain ---
Install-App "HashiCorp.Terraform" "Terraform CLI"
Install-App "Terraform.Ls" "Terraform Language Server"
Install-App "tflint" "Terraform Linter"
if ($IncludeSecurityTools){
    Install-App "AquaSecurity.tfsec" "Terraform Security Scanner (tfsec)"
    Install-App "Accurics.Terrascan" "Terraform Compliance Scanner (terrascan)"
}

# ---------------------------------------------------------------------
# --- Python & SQLFluff setup
# ---------------------------------------------------------------------
Retry-Command { python -m ensurepip }
Retry-Command { python -m pip install --upgrade pip wheel setuptools }
Retry-Command { python -m pip install pandas pyodbc sqlalchemy azure-identity azure-storage-blob sqlfluff }

try {
    Retry-Command { sqlfluff config --write-defaults }
    $configFile = "$env:USERPROFILE\.config\sqlfluff\config.toml"
    if (Test-Path $configFile) {
        (Get-Content $configFile) -replace 'dialect = "ansi"', 'dialect = "tsql"' | Set-Content $configFile
        Write-Host "Configured SQLFluff default dialect = tsql"
    }
} catch {
    Write-Warning "SQLFluff config initialisation skipped."
}

# Suppress Azure CLI update prompts
$env:AZURE_CORE_SUPPRESS_UPDATE_WARNING = "1"

# ---------------------------------------------------------------------
# --- VS Code extensions
# ---------------------------------------------------------------------
$codeCmdObj = Get-Command code.cmd -ErrorAction SilentlyContinue
if (-not $codeCmdObj){
    Write-Warning "VS Code CLI not yet in PATH; retrying..."
    Start-Sleep -Seconds 10
    $codeCmdObj = Get-Command code.cmd -ErrorAction SilentlyContinue
}
if ($codeCmdObj){
    $codeCmd = $codeCmdObj.Source
    $coreExt  = @(
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "humao.rest-client",
        "dorzey.vscode-sqlfluff"
    )
    $sqlExt   = @("ms-mssql.mssql","mtxr.sqltools","sqltools-driver.sqlserver","MEngRBatinov.mssql-scripts")
    $azureExt = @("ms-vscode.azure-account","ms-azuretools.vscode-azureresources",
                  "ms-azuretools.vscode-azurefunctions","ms-azuretools.vscode-logicapps","ms-azuretools.vscode-bicep")
    $dockerExt= @("ms-azuretools.vscode-docker")

    $terraformExt = @(
        "HashiCorp.terraform",                 # HashiCorp Terraform
        "ms-azuretools.vscode-azureterraform", # Microsoft Terraform (Azure)
        "mauve.terraform-docs",                # Terraform Docs generator
        "erd0s.terraform-snippets",            # Helpful snippets
        "yusukehirao.vscode-tflint"            # Terraform Linter integration
    )

    $exts=$coreExt
    if ($IncludeSQLTools){$exts+=$sqlExt}
    if ($IncludeAzureTools){$exts+=$azureExt}
    if ($IncludeDocker){$exts+=$dockerExt}
    $exts+=$terraformExt

    $installed=&$codeCmd --list-extensions
    foreach($e in $exts){
        if ($installed -notcontains $e){
            Retry-Command { & $codeCmd --install-extension $e --force }
        }
    }
}else{
    Write-Warning "VS Code CLI not found; extensions skipped. Open VS Code once and rerun for extensions."
}

# ---------------------------------------------------------------------
# --- System-wide upgrades
# ---------------------------------------------------------------------
Write-Host "Upgrading Microsoft .NET SDK and all winget packages..."
Retry-Command { winget upgrade Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements }
Retry-Command { winget upgrade --all --accept-source-agreements --accept-package-agreements }

# ---------------------------------------------------------------------
# --- Validation (smarter, command-aware)
# ---------------------------------------------------------------------
Ensure-Path

$tests=@(
    @{Name="Python"      ;Cmd="python --version"},
    @{Name="Git"         ;Cmd="git --version"},
    @{Name="AzureCLI"    ;Cmd="az --version"},
    @{Name="Terraform"   ;Cmd="terraform version"},
    @{Name="Terraform-LS";Cmd="terraform-ls --version"},
    @{Name="TFLint"      ;Cmd="tflint --version"},
    @{Name="VS Code"     ;Cmd="code --version"},
    @{Name="SQLFluff"    ;Cmd="sqlfluff --version"}
)
if ($IncludeSecurityTools){
    $tests += @(
        @{Name="tfsec"    ;Cmd="tfsec --version"},
        @{Name="Terrascan";Cmd="terrascan version"}
    )
}

foreach($t in $tests){
    $cmdName = ($t.Cmd -split ' ')[0]  # first token, e.g. 'terraform'
    $cmdObj  = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmdObj){
        try{
            Write-Host "`n$($t.Name):"
            Invoke-Expression $t.Cmd
        }catch{
            Write-Warning "$($t.Name) command exists but failed to run: $($_.Exception.Message)"
        }
    }else{
        Write-Warning "$($t.Name): '$cmdName' not found in PATH (may require restart or install issue)."
    }
}

$elapsed=(Get-Date)-$start
Stop-Transcript

Write-Host "`n=============================================================="
Write-Host "Azure + Terraform + Security + Data Engineering Environment ready!"
Write-Host "Duration: $($elapsed.ToString('hh\:mm\:ss'))"
Write-Host "Restart PowerShell and VS Code to finalise PATH updates."
Write-Host "Log file: $env:USERPROFILE\Documents\DataEngSetup.log"
Write-Host "=============================================================="
