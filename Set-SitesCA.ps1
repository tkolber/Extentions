###   Changing AD site name from Default-First-Site-Name to Prod-Site   ###

$configNCDN = (Get-ADRootDSE).ConfigurationNamingContext
$siteContainerDN = ("CN=Sites," + $configNCDN)
$siteDN = "CN=Default-First-Site-Name," + $siteContainerDN
Get-ADObject -Identity $siteDN | Rename-ADObject -NewName "PROD-Site"
New-ADReplicationSubnet -Name "10.0.0.0/24" -Site "Prod-Site"
New-ADReplicationSite -Name "DR-Site"
New-ADReplicationSubnet -Name "192.168.0.0/24" -Site "DR-Site"
Start-Sleep -s 15
New-ADReplicationSiteLink "PROD-DR" -SitesIncluded DR-Site,Prod-Site -Cost 100 -ReplicationFrequencyInMinutes 90
Start-Sleep -s 10
Move-ADDirectoryServer -Identity DC02 -Site "DR-Site"
#Write-Host -ForegroundColor Magenta "Completed Configuring DC01"
Start-Sleep -s 30
Remove-ADReplicationSiteLink -Identity DEFAULTIPSITELINK -Confirm:$false
Start-Sleep -s 30
repadmin /syncall /PADe > c:\Temp\Repl-Result.txt
Install-WindowsFeature Web-WebServer -IncludeManagementTools -Confirm:$false
Install-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools -Confirm:$false
Install-AdcsCertificationAuthority -CACommonName "Contoso-DC01-CA" -CAType EnterpriseRootCa -HashAlgorithmName SHA256 -KeyLength 4096 -ValidityPeriod Years -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -ValidityPeriodUnits 5 -confirm:$false -OverwriteExistingKey
Certutil -setreg SetupStatus -SETUP_DCOM_SECURITY_UPDATED_FLAG
$cm = "dsacls"
$par = '"CN=WebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,DC=contoso,DC=com" /g "Domain Computers:ga"'
$Action = New-ScheduledTaskAction -Execute $cm -Argument $par
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -WakeToRun
Register-ScheduledTask -Action $Action -User "contoso\wsadmin" -Password "Password123456" -TaskName "Cert-per" -RunLevel Highest -Settings $Settings -Force
Start-Sleep -Seconds 10
Start-ScheduledTask -TaskName "Cert-per" -ErrorAction Stop | Out-Null
Start-Sleep -s 10
Restart-computer -ComputerName DC02 -Force
do {
    Start-Sleep -s 20
    $TSstatP=(Get-ScheduledTask -TaskName "Cert-per").State
    } Until ($TSstatP -eq "Ready")
Restart-computer -Force
#####################################


