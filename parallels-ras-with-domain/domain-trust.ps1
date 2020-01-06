# [ component.properties.TrustDomain, component.properties.TrustAdminUser, component.properties.TrustAdminPassword, component.properties.TrustDirection] | join(' ')
param(
  [string]$RemoteDomain,
  [string]$RemoteAdmin,
  [string]$RemotePassword,
  [string]$TrustDirection
)
$ErrorActionPreference = "Stop"
Import-Module C:\Windows\Temp\ADTrust.ps1 -Verbose
$ExistingTrust = Get-ADTrust -Filter {Target -eq $RemoteDomain}
If (-not $ExistingTrust) {
	New-ADDomainTrust -RemoteDomain $RemoteDomain -RemoteAdmin $RemoteAdmin -RemotePassword $RemotePassword -TrustDirection $TrustDirection -ErrorAction "Stop"
}