#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$SubscriptionName = 'WindowsServerLab-Security',
    [string]$SourceDomainComputers = 'Domain Computers'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Configure event collector subscription $SubscriptionName")) { return }

Set-Service Wecsvc -StartupType Automatic
Start-Service Wecsvc
wecutil.exe qc /q | Out-Null
$domain = Get-CimInstance Win32_ComputerSystem
if (-not $domain.PartOfDomain) { throw 'The collector must be domain joined before configuring source authorization.' }
$sourceAccount = [Security.Principal.NTAccount]::new($domain.Domain, $SourceDomainComputers)
$sourceSid = $sourceAccount.Translate([Security.Principal.SecurityIdentifier]).Value

$subscriptionPath = Join-Path $env:TEMP "wslab-wef-$PID.xml"
$xml = @"
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
  <SubscriptionId>$SubscriptionName</SubscriptionId>
  <SubscriptionType>SourceInitiated</SubscriptionType>
  <Description>Required security events for WindowsServerLab validation.</Description>
  <Enabled>true</Enabled>
  <Uri>http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog</Uri>
  <ConfigurationMode>Normal</ConfigurationMode>
  <Delivery Mode="Push"><Batching><MaxLatencyTime>30000</MaxLatencyTime></Batching><PushSettings><Heartbeat Interval="60000"/></PushSettings></Delivery>
  <Query><![CDATA[
    <QueryList>
      <Query Id="0">
        <Select Path="Security">*[System[(EventID=4624 or EventID=4625 or EventID=4688 or EventID=4720 or EventID=4740)]]</Select>
        <Select Path="Microsoft-Windows-PowerShell/Operational">*</Select>
        <Select Path="Microsoft-Windows-CodeIntegrity/Operational">*[System[(EventID=3076 or EventID=3077)]]</Select>
      </Query>
    </QueryList>
  ]]></Query>
  <ReadExistingEvents>false</ReadExistingEvents>
  <TransportName>HTTP</TransportName>
  <ContentFormat>RenderedText</ContentFormat>
  <Locale Language="en-US"/>
  <LogFile>ForwardedEvents</LogFile>
  <AllowedSourceNonDomainComputers></AllowedSourceNonDomainComputers>
  <AllowedSourceDomainComputers>O:NSG:BAD:P(A;;GA;;;$sourceSid)</AllowedSourceDomainComputers>
</Subscription>
"@
try {
    Set-Content -LiteralPath $subscriptionPath -Value $xml -Encoding UTF8
    $existingSubscriptions = @(& wecutil.exe es)
    if ($LASTEXITCODE -ne 0) { throw "wecutil could not enumerate subscriptions (exit code $LASTEXITCODE)" }
    if ($SubscriptionName -in $existingSubscriptions) {
        & wecutil.exe ds $SubscriptionName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "wecutil could not replace subscription $SubscriptionName (exit code $LASTEXITCODE)" }
    }
    wecutil.exe cs $subscriptionPath
    if ($LASTEXITCODE -ne 0) { throw "wecutil failed with exit code $LASTEXITCODE" }
}
finally {
    Remove-Item -LiteralPath $subscriptionPath -Force -ErrorAction Ignore
}
