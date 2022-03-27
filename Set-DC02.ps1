###   Configure DC02 as a domain controller and DNS server for the contoso.com domain   ###

#Write-Host -ForegroundColor Green "Configuring DC02 as a domain controller and DNS server for the contoso.com domain"
mkdir C:\Temp
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled false
$nicactive=(get-wmiobject win32_networkadapter -filter "netconnectionstatus = 2").netconnectionid
netsh interface ip set dns "$nicactive" static 10.0.0.10
netsh interface ip add dns "$nicactive" 192.168.0.10 index=2
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
$RP="repadmin"
$REPL = "/syncall /PADe"
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$tr = New-ScheduledTaskTrigger -Once -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 55) -At 01:00
$Action = New-ScheduledTaskAction -Execute $RP -Argument $REPL
$settings = New-ScheduledTaskSettingsSet -MultipleInstances Parallel
Register-ScheduledTask -Action $Action  -Principal $principal -Trigger $tr -TaskName "DC_REPL" -Settings $Settings -Force
Start-ScheduledTask -TaskName "DC_REPL" -ErrorAction Stop | Out-Null
Add-WindowsFeature RSAT-ADDS-Tools
Install-WindowsFeature -name AD-Domain-Services
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
$pass="Aa123456"
$sPwd = $pass | ConvertTo-SecureString -AsPlainText -Force
$user = "contoso\wsadmin"
$password = "Password123456"
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $user, $secureStringPwd
Install-ADDSDomainController -CriticalReplicationOnly:$false -DomainName "contoso.com" -SiteName "Default-First-Site-Name" -SafeModeAdministratorPassword $spwd -Force:$true -confirm:$false -Credential $cred
#Write-Host -ForegroundColor Magenta "Completed Configuring DC02"

#####################################