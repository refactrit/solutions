param(
  [string]$LANDomainName,
  [string]$DMZDomainName,
  [string]$AdminServer,
  [string]$LANAdminUser,
  [string]$LANAdminPassword,
  [string]$DMZAdminUser,
  [string]$DMZAdminPassword,
  [string]$LicenseEmail,
  [string]$LicensePassword,
  [string]$LicenseKey,
  [string[]]$SessionHosts,
  [string[]]$SecureClientGateways,
  [string]$RASGroupName,
  [string[]]$PublishingAgents=@(),
  [string]$SMTPServer,
  [string]$SMTPUsername,
  [string]$SMTPPassword,
  [string]$SMTPSenderAddress,
  [string]$SMTPUseTLS,    # No | Yes | YesIfAvailable
  [bool]$SMTPRequireAuth
)

$ErrorActionPreference = "Stop"

Import-Module "C:\Program Files (x86)\Parallels\ApplicationServer\Modules\PSAdmin\PSAdmin.psd1"

$SecureLANAdminPassword = ConvertTo-SecureString $LANAdminPassword -AsPlainText -Force
$SecureDMZAdminPassword = ConvertTo-SecureString $DMZAdminPassword -AsPlainText -Force

New-RASSession -Username $DMZAdminUser -Password $SecureDMZAdminPassword -Server "$AdminServer.$DMZDomainName"

# Configure SMTP Settings
$SecureSMTPPassword = ConvertTo-SecureString $SMTPPassword -AsPlainText -Force
Set-RASMailboxSettings -SMTPServer $SMTPServer -SenderAddress $SMTPSenderAddress -Username $SMTPUsername -Password $SecureSMTPPassword -RequireAuth $SMTPRequireAuth -UseTLS $SMTPUseTLS

# Activate License
$SecureLicensePassword = ConvertTo-SecureString $LicensePassword -AsPlainText -Force
If ($LicenseKey) {
  Invoke-LicenseActivate -Email $LicenseEmail -Password $SecureLicensePassword -Key $LicenseKey
} Else {
  Invoke-LicenseActivate -Email $LicenseEmail -Password $SecureLicensePassword
}
Invoke-Apply

Remove-RASSession

# Add the LAN user to local Administrators to have permissions to add the RDS
$TmpUsername = If ($LANAdminUser -match '@') { ($LANAdminUser -split '@')[0] } Else { $LANAdminUser }
$TmpSecurePassword = ConvertTo-SecureString $LANAdminPassword -AsPlainText -Force
$TmpCredential = New-Object System.Management.Automation.PSCredential($TmpUsername, $TmpSecurePassword)

$TmpUser = Get-ADUser -Identity $TmpUsername -Server $LANDomainName -Credential $TmpCredential
$TmpGroup = Get-ADGroup -Identity "Administrators"
Add-ADGroupMember -Identity $TmpGroup -Members $TmpUser

New-RASSession -Username $LANAdminUser -Password $SecureLANAdminPassword -Server "$AdminServer.$DMZDomainName"

# Add RD Session Host Servers
ForEach ($RDSH in $SessionHosts) {
  Try { $ExistingRDSH = Get-RDS "$RDSH.$LANDomainName" } Catch {}
  if (-not $ExistingRDSH) {
    "Adding RDSH $RDSH.$LANDomainName"
    New-RDS "$RDSH.$LANDomainName"
  }
}
Invoke-Apply

Remove-RASSession

# Remove the LAN user from local Administrators
Remove-ADGroupMember -Identity $TmpGroup -Members $TmpUser -Confirm:$False

New-RASSession -Username $DMZAdminUser -Password $SecureDMZAdminPassword -Server "$AdminServer.$DMZDomainName"

# Add Secure Client Gateway Servers
ForEach ($SCG in $SecureClientGateways) {
  Try { $ExistingSCG = Get-GW "$SCG.$DMZDomainName" } Catch {}
  if (-not $ExistingSCG) {
    "Adding SCG $SCG.$DMZDomainName"
    New-GW "$SCG.$DMZDomainName"
  }
}
Invoke-Apply

# Create an RD Session Host Group and add both RD Session Host objects to it.
Try { $RASGroup = Get-RDSGroup -Name $RASGroupName } Catch {}
if (-not $RASGroup) {
  "Adding group $RASGroupName"
  $RDSList = Get-RDS
  $RASGroup = New-RDSGroup -Name $RASGroupName -RDSObject $RDSList
  Invoke-Apply
}

# Publish the RDS group
Try { $PubDesktop = Get-PubRDSDesktop -Name $RASGroupName } Catch {}
if (-not $PubDesktop) {
  "Adding published desktop group $RASGroupName"
  New-PubRDSDesktop -Name $RASGroupName -PublishFromGroup $RASGroup
}

# Add Publishing Agents
ForEach ($PA in $PublishingAgents) {
	if ($PA -ne "") {
		Try { $ExistingPA = Get-PA "$PA.$DMZDomainName" } Catch {}
		if (-not $ExistingPA) {
			"Adding PA $PA.$DMZDomainName"
			New-PA "$PA.$DMZDomainName"
		}
	}
}
Invoke-Apply

Remove-RASSession