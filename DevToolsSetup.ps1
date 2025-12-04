# =====================================================================
# Microsoft Developer Workstation Setup
# Azure, .NET, Data, Terraform, Security, VS Code & Extensions
# =====================================================================
# Purpose:
#   Complete enterprise-ready environment for:
#   - Azure & Terraform (IaC)
#   - Data Engineering tools (Python, SQLFluff, SSMS, ADS)
#   - C# / .NET development
#   - VS Code with recommended extensions
#
# Parameters:
#   -IncludeAzureTools    : Install Azure-focused VS Code extensions
#   -IncludeSQLTools      : Install SQL-focused VS Code extensions
#   -IncludeDocker        : Install Docker Desktop + VS Code Docker ext
#   -IncludePowerBI       : Install Power BI Desktop
#   -IncludeSecurityTools : Install tfsec & Terrascan (Terraform security)
#
# Typical usage:
#   # Full workstation (Azure + SQL + Terraform + Security)
#   .\Setup-DevEnvironment.ps1 -IncludeAzureTools -IncludeSQLTools -IncludeDocker -IncludePowerBI -IncludeSecurityTools
#
#   # Core developer setup (no Docker/PowerBI/Security extras)
#   .\Setup-DevEnvironment.ps1 -IncludeAzureTools -IncludeSQLTools
# =====================================================================

param(
    [switch]$IncludeAzureTools,
    [switch]$IncludeSQLTools,
    [switch]$IncludeDocker,
    [switch]$IncludePowerBI,
    [switch]$IncludeSecurityTools  # Security scanners (tfsec, terrascan)
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

function Retry-Command([ScriptBlock]$cmd,[int]$n=3,[int]$delay=5){
    for($i=1;$i -le $n;$i++){
        try {
            & $cmd
            return
        } catch {
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
        # Terraform-related (best-effort guesses)
        "$env:ProgramFiles\HashiCorp\Terraform",
        "$env:ProgramFiles\Terraform Language Server",
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
# --- INSTALL
# ---------------------------------------------------------------------
Start-Transcript -Path "$env:USERPROFILE\Documents\DataEngSetup.log" -Append
$start = Get-Date

Write-Host "Updating winget sources..."
Retry-Command { winget source update }

# --- Core software ---
Install-App "Python.Python.3.12"                 "Python"
Install-App "Git.Git"                            "Git"
Install-App "Microsoft.VisualStudioCode"         "VS Code"
Install-App "Microsoft.AzureCLI"                 "Azure CLI"
Install-App "Microsoft.AzureDataStudio"          "Azure Data Studio"
Install-App "Microsoft.SQLServerManagementStudio" "SSMS"

if ($IncludeDocker)  { Install-App "Docker.DockerDesktop" "Docker Desktop" }
if ($IncludePowerBI) { Install-App "Microsoft.PowerBI"    "Power BI Desktop" }

# --- Terraform toolchain (correct winget IDs) ---
Install-App "Hashicorp.Terraform"               "Terraform CLI"
Install-App "Hashicorp.TerraformLanguageServer" "Terraform Language Server"
Install-App "TerraformLinters.tflint"           "Terraform Linter (tflint)"

if ($IncludeSecurityTools){
    Install-App "AquaSecurity.tfsec" "Terraform Security Scanner (tfsec)"
    Install-App "Accurics.Terrascan" "Terraform Compliance Scanner (terrascan)"
}

# ---------------------------------------------------------------------
# --- Python & SQLFluff setup
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

# --- SQLFluff configuration (no CLI 'config' command) ---
try {
    # Preferred simple approach: .sqlfluff in home directory
    $sqlfluffConfigPath = Join-Path $env:USERPROFILE ".sqlfluff"

    if (-not (Test-Path $sqlfluffConfigPath)) {
        "[sqlfluff]`n# Default dialect for this machine`ndialect = tsql" |
            Set-Content -Path $sqlfluffConfigPath -Encoding UTF8
        Write-Host "Created SQLFluff config at $sqlfluffConfigPath (dialect = tsql)."
    } else {
        $content = Get-Content $sqlfluffConfigPath -Raw
        if ($content -notmatch '^\s*dialect\s*=' ) {
            $content += "`n`n[sqlfluff]`n# Default dialect for this machine`ndialect = tsql`n"
            $content | Set-Content -Path $sqlfluffConfigPath -Encoding UTF8
            Write-Host "Updated existing SQLFluff config with dialect = tsql."
        } else {
            Write-Host "SQLFluff config already exists; leaving dialect as-is."
        }
    }
} catch {
    Write-Warning "SQLFluff config initialisation skipped: $($_.Exception.Message)"
}

# Suppress Azure CLI update prompts as far as possible
$env:AZURE_CORE_SUPPRESS_UPDATE_WARNING = "1"
try {
    if (Get-Command az -ErrorAction SilentlyContinue) {
        Retry-Command { az config set core.check_for_updates false }
    }
} catch {
    Write-Warning "Unable to update Azure CLI config to disable update checks."
}

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
    Write-Host "Installing VS Code extensions..."

    $coreExt  = @(
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "humao.rest-client",
        "dorzey.vscode-sqlfluff"
    )

    $sqlExt   = @(
        "ms-mssql.mssql",
        "mtxr.sqltools",
        "sqltools-driver.sqlserver",
        "MEngRBatinov.mssql-scripts"
    )

    $azureExt = @(
        "ms-vscode.azure-account",
        "ms-azuretools.vscode-azureresources",
        "ms-azuretools.vscode-azurefunctions",
        "ms-azuretools.vscode-logicapps",
        "ms-azuretools.vscode-bicep"
    )

    $dockerExt = @(
        "ms-azuretools.vscode-docker"
    )

    # Terraform ecosystem (all valid IDs)
    $terraformExt = @(
        "HashiCorp.terraform",                 # HashiCorp Terraform extension
        "ms-azuretools.vscode-azureterraform", # Azure-focused Terraform integration
        "run-at-scale.terraform-doc-snippets", # Auto-generated doc snippets
        "mindginative.terraform-snippets",     # General Terraform snippets
        "NandovdK.tflint-vscode"               # TFLint VS Code integration
    )

    $exts = $coreExt
    if ($IncludeSQLTools)  { $exts += $sqlExt }
    if ($IncludeAzureTools){ $exts += $azureExt }
    if ($IncludeDocker)    { $exts += $dockerExt }
    $exts += $terraformExt

    $installed = & $codeCmd --list-extensions
    foreach($e in $exts){
        if ($installed -notcontains $e){
            try {
                Retry-Command { & $codeCmd --install-extension $e --force }
            } catch {
                Write-Warning "Failed installing VS Code extension: $e"
            }
        }
    }
} else {
    Write-Warning "VS Code CLI not found; extensions skipped. Open VS Code once and rerun this script for extensions."
}

# ---------------------------------------------------------------------
# --- System-wide upgrades
# ---------------------------------------------------------------------
Write-Host "Upgrading Microsoft .NET SDK and all winget packages..."
Retry-Command { winget upgrade Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements }
Retry-Command { winget upgrade --all --accept-source-agreements --accept-package-agreements }

# ---------------------------------------------------------------------
# --- Validation (command-aware, with 2>&1 for noisy CLIs)
# ---------------------------------------------------------------------
Ensure-Path

$tests=@(
    @{Name="Python"      ;Cmd="python --version 2>&1"},
    @{Name="Git"         ;Cmd="git --version 2>&1"},
    @{Name="AzureCLI"    ;Cmd="az --version 2>&1"},
    @{Name="Terraform"   ;Cmd="terraform version 2>&1"},
    @{Name="Terraform-LS";Cmd="terraform-ls --version 2>&1"},
    @{Name="TFLint"      ;Cmd="tflint --version 2>&1"},
    @{Name="VS Code"     ;Cmd="code --version 2>&1"},
    @{Name="SQLFluff"    ;Cmd="sqlfluff --version 2>&1"},
    @{Name="SSMS"        ;Cmd="winget list --id Microsoft.SQLServerManagementStudio 2>&1"}
)
if ($IncludeSecurityTools){
    $tests += @(
        @{Name="tfsec"    ;Cmd="tfsec --version 2>&1"},
        @{Name="Terrascan";Cmd="terrascan version 2>&1"}
    )
}

foreach($t in $tests){
    $cmdName = ($t.Cmd -split ' ')[0]  # first token, e.g. 'terraform'
    $cmdObj  = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmdObj){
        Write-Host "`n$($t.Name):"
        try{
            $result = Invoke-Expression $t.Cmd
            if ($result) {
                $result | Out-String | Write-Host
            }
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
Write-Host "Azure + Terraform + Security + Developer + Data Engineering Environment ready!"
Write-Host "Duration: $($elapsed.ToString('hh\:mm\:ss'))"
Write-Host "Restart PowerShell and VS Code to finalise PATH updates."
Write-Host "Log file: $env:USERPROFILE\Documents\DataEngSetup.log"
Write-Host "=============================================================="
