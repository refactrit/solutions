# [ component.properties.ForwardAddress, component.properties.ForwardDomainName ] | join(' ')
param(
  [string]$MasterServers,
  [string]$DomainName
)
$ErrorActionPreference = "Stop"
$ExistingForwarder = (gwmi -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone -Filter "ZoneType = 4" | Select -Property @{n='Name';e={$_.ContainerName}}, @{n='DsIntegrated';e={$_.DsIntegrated}}, @{n='MasterServers';e={([string]::Join(',', $_.MasterServers))}}, @{n='AllowUpdate';e={$_.AllowUpdate}} | Where-Object {$_.MasterServers -eq $MasterServers -and $_.Name -eq $DomainName})
If (-not $ExistingForwarder) {
  Add-DnsServerConditionalForwarderZone -MasterServers $MasterServers -Name $DomainName -UseRecursion $true -ErrorAction "Stop"
}