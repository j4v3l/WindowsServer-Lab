#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$ArtifactManifestPath,
    [ValidateRange(1024, 65535)][int]$HealthPort = 8888,
    [switch]$RequireGpu
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$manifest = Get-Content -LiteralPath $ArtifactManifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or @($manifest.packages).Count -eq 0) { throw 'AI/ML artifact manifest must use schemaVersion 1 and contain at least one package.' }
if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install the pinned Olympus AI/ML toolchain and health endpoint')) { return }

$cache = 'C:\ProgramData\WindowsServerLab\Artifacts'
$reportDirectory = 'C:\ProgramData\WindowsServerLab\Reports'
foreach ($directory in @($cache, $reportDirectory, 'C:\AIMLData\Models', 'C:\AIMLData\Notebooks')) {
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
}

$installed = [System.Collections.Generic.List[object]]::new()
foreach ($package in $manifest.packages) {
    if ($package.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw "Package $($package.name) does not have a valid SHA-256." }
    if ($package.uri -notmatch '^https://') { throw "Package $($package.name) must use HTTPS." }
    $fileName = if ($package.fileName) { $package.fileName } else { Split-Path $package.uri -Leaf }
    $destination = Join-Path $cache $fileName
    $detectionPath = [Environment]::ExpandEnvironmentVariables([string]$package.detection.path)
    $detected = Test-Path -LiteralPath $detectionPath
    if ($detected -and $package.detection.sha256) {
        $detected = (Get-FileHash -LiteralPath $detectionPath -Algorithm SHA256 -ErrorAction Stop).Hash -eq $package.detection.sha256.ToUpperInvariant()
    }
    if ($detected -and $package.detection.fileVersion) {
        $detected = (Get-Item -LiteralPath $detectionPath -ErrorAction Stop).VersionInfo.FileVersion -eq $package.detection.fileVersion
    }
    if ($detected) {
        $installed.Add([pscustomobject]@{ name = $package.name; sha256 = $package.sha256.ToUpperInvariant(); exitCode = 0; state = 'already-present' })
        continue
    }

    if (-not (Test-Path -LiteralPath $destination) -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $package.sha256.ToUpperInvariant()) {
        Invoke-WebRequest -Uri $package.uri -OutFile $destination -UseBasicParsing
    }
    $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($actual -ne $package.sha256.ToUpperInvariant()) { throw "Checksum mismatch for $($package.name)." }

    switch ($package.installerType) {
        'msi' {
            $arguments = @('/i', $destination, '/qn', '/norestart') + @($package.arguments)
            $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        }
        'exe' { $process = Start-Process $destination -ArgumentList @($package.arguments) -Wait -PassThru -NoNewWindow }
        'zip' {
            $target = Join-Path 'C:\AIMLData\Tools' $package.name
            Expand-Archive -LiteralPath $destination -DestinationPath $target -Force
            $process = [pscustomobject]@{ ExitCode = 0 }
        }
        default { throw "Unsupported installerType for $($package.name): $($package.installerType)" }
    }
    if ($process.ExitCode -notin @(0, 1641, 3010)) { throw "Installer for $($package.name) failed with exit code $($process.ExitCode)." }
    if (-not (Test-Path -LiteralPath $detectionPath)) { throw "Installer for $($package.name) completed but its detection path is absent: $detectionPath" }
    if ($package.detection.sha256 -and (Get-FileHash -LiteralPath $detectionPath -Algorithm SHA256 -ErrorAction Stop).Hash -ne $package.detection.sha256.ToUpperInvariant()) {
        throw "Installed detection hash did not match for $($package.name)."
    }
    if ($package.detection.fileVersion -and (Get-Item -LiteralPath $detectionPath -ErrorAction Stop).VersionInfo.FileVersion -ne $package.detection.fileVersion) {
        throw "Installed file version did not match for $($package.name)."
    }
    $installed.Add([pscustomobject]@{ name = $package.name; sha256 = $actual; exitCode = $process.ExitCode; state = 'installed' })
}

$gpu = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Microsoft Basic|Remote Display' })
if ($RequireGpu -and $gpu.Count -eq 0) { throw 'A configured GPU was required but no passthrough-capable display adapter was detected.' }

$health = [ordered]@{
    schemaVersion = 1
    status        = 'healthy'
    toolchain     = $true
    gpuDetected   = ($gpu.Count -gt 0)
    packages      = @($installed.name)
    timestamp     = (Get-Date).ToUniversalTime().ToString('o')
}
$health | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reportDirectory 'olympus-aiml-health.json') -Encoding UTF8

$endpointScript = 'C:\ProgramData\WindowsServerLab\Scripts\Start-OlympusAIMLHealthEndpoint.ps1'
$endpoint = @'
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add('http://+:{PORT}/')
$listener.Start()
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $bytes = [Text.Encoding]::UTF8.GetBytes((Get-Content -LiteralPath '{REPORT}\olympus-aiml-health.json' -Raw))
    $context.Response.ContentType = 'application/json'
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
}
'@
$endpoint = $endpoint.Replace('{PORT}', [string]$HealthPort).Replace('{REPORT}', $reportDirectory)
Set-Content -LiteralPath $endpointScript -Value $endpoint -Encoding UTF8
$urlPrefix = "http://+:$HealthPort/"
& netsh.exe http show urlacl url=$urlPrefix 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    & netsh.exe http add urlacl url=$urlPrefix 'user=NT AUTHORITY\LOCAL SERVICE' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to reserve the AI/ML health URL prefix $urlPrefix." }
}
$argument = '-NoLogo -NoProfile -NonInteractive -File "{0}"' -f $endpointScript
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\LOCAL SERVICE' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'WindowsServerLab-AIML-Health' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
if (-not (Get-NetFirewallRule -Name 'WindowsServerLab-AIML-Health' -ErrorAction Ignore)) {
    New-NetFirewallRule -Name 'WindowsServerLab-AIML-Health' -DisplayName 'WindowsServerLab Olympus AI/ML health' -Direction Inbound -Protocol TCP -LocalPort $HealthPort -Action Allow -Profile Domain | Out-Null
}
Start-ScheduledTask -TaskName 'WindowsServerLab-AIML-Health'
