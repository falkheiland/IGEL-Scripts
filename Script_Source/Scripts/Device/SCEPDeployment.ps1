#requires -PSEdition Desktop

<#
.\NewDeviceSCEPCert.ps1 -Computername '10.109.99.108' -SSHCredential (Import-Clixml -Path 'C:\Credentials\DeviceRoot.cred')
.\NewDeviceSCEPCert.ps1 -Computername '10.109.99.108' -SSHCredential (Get-Credential)
#>

# param (

#   [PSCredential]
#   $SSHCredential = (Import-Clixml -Path 'C:\Credentials\DeviceRoot.cred'),

#   [String]
#   $UMSServer = 'srvums01.bfw.local',

#   [PSCredential]
#   $UMSCredential = (Import-Clixml -Path 'C:\Credentials\srvums01rmdb.cred'),

#   $Cfg.DeploymentDirName = 'I_RA_1U07',

#   $($Cfg.DeviceNamePrefix) = 'TC',

#   [String]
#   $DCServer = 'srvdc02.bfw.local',

#   [String[]]
#   $Cfg.SearchBaseColl = @( 'OU=I_Computers,OU=IT,DC=bfw,DC=local',
#     'OU=A_Computers,OU=Ausbildung,DC=bfw,DC=local',
#     'OU=V_Computers,OU=Verwaltung,DC=bfw,DC=local' )

# )

$Cfg = Import-PowerShellDataFile -Path ('{0}/SCEPDeploymentConfig.psd1' -f $PSScriptRoot)

foreach ($PSModule in ('Posh-SSH', 'PSIGEL', 'CommonTools'))
{
  if (!@(Get-Module -ListAvailable -Name $PSModule))
  {
    Install-Module -Name $PSModule
  }
  else
  {
    Import-Module -Name $PSModule -DisableNameChecking -Force
  }
}

$PSDefaultParameterValues = @{
  '*-UMS*:Computername' = $Cfg.UMSServer
  '*-SSH*:Credential'   = (Import-Clixml -Path $Cfg.SSHCredentialPath)
  '*-AD*:Server'        = $Cfg.DCServer
}

$WebSession = New-UMSAPICookie -Credential (Import-Clixml -Path $Cfg.UMSCredentialPath)
$PSDefaultParameterValues.Add('*-UMS* :WebSession', $WebSession)

$DeploymentDir = ((Get-UMSDeviceDirectory ).where{ $_.Name -eq $Cfg.DeploymentDirName })[0]
$OnlineDeploymentDeviceColl = (Get-UMSDevice -Filter online).where{ 
  ($_.ParentId -eq $DeploymentDir.Id) -and ($_.Name -match "^$($($Cfg.DeviceNamePrefix))")
}

$PingDeploymentDeviceColl = foreach ($OnlineDeploymentDevice In $OnlineDeploymentDeviceColl)
{
  if ((Invoke-FastPing -HostName $OnlineDeploymentDevice.LastIP).Online)
  {
    $OnlineDeploymentDevice
  }
}

If ($null -ne $PingDeploymentDeviceColl)
{
  $ADDeviceComputerColl = Foreach ($SearchBase in $Cfg.SearchBaseColl)
  {
    Get-ADComputer -LDAPFilter "(name=$($Cfg.DeviceNamePrefix)*)" -SearchBase $SearchBase 
  }

  $ADDeviceUserColl = Foreach ($SearchBase in $Cfg.SearchBaseColl)
  {
    Get-ADUser -LDAPFilter "(sAMAccountName=$($Cfg.DeviceNamePrefix)*)" -SearchBase $SearchBase
  }
}

$DeviceQueryColl = foreach ($PingDeploymentDevice in $PingDeploymentDeviceColl)
{
  $SSHSessionParams = @{
    ComputerName = $PingDeploymentDevice.LastIP
    AcceptKey    = $treu
    ErrorAction  = 'SilentlyContinue'
  }
  $SSHSession = New-SSHSession @SSHSessionParams

  $PSDefaultParameterValues = @{
    'Invoke-SSH*:SShSession' = $SSHSession
  }

  $Result = [pscustomobject]@{
    UMSDeviceName  = $PingDeploymentDevice.Name
    UMSDeviceId    = $PingDeploymentDevice.Id
    ADUser         = ((@($ADDeviceUserColl)).where{ $_.SamAccountName -eq $PingDeploymentDevice.Name }).DistinguishedName
    ADComputer     = ((@($ADDeviceComputerColl)).where{ $_.Name -eq $PingDeploymentDevice.Name }).DistinguishedName
    Hostname       = Invoke-SSHCommandStream -Command 'hostname'
    SCEPUrl        = Invoke-SSHCommandStream -Command 'cat /wfs/group.ini | grep "scepurl" | sed "s/[[:space:]]//g" | sed "s/scepurl=<//" | sed "s/>//"'
    SCEPClientCert = Invoke-SSHCommandStream -Command 'cat /wfs/scep_certificates/cert0/client.cert'
  }
  $Result

  $null = $SSHSession | Remove-SSHSession
}
$DeviceQueryColl


<#todo

  $Prepare = @"
rm /wfs/scep_cerificates/cert0/*
cd /wfs/scep_cerificates/cert0
scep_getca 0
scep_mkrequest 0
scep_enroll 0
"@

  $Null = ($Prepare -split "`n").ForEach{
    #Invoke-SSHCommandStream -Command $_
  }

[ ] igelrmserver DNS 10.0.5.58 -> 10.0.5.57
[x] check group.ini for scep url in profile


[x] ums alle devices unter i_1u07 und name beginnt mit TC und ist online:
- wenn kein AD Computerkonto + Userkonto
- certrequest
- Computerkonto erstellen
- Userkonto erstellen
- check ob wifi ok


- igelos device is added to ums
- get ums devices
- get ad igelos devices - computer
- get ad igelos devices - user (ndes) - with mapped x509 cert
- compare
- missing ad igelos devices
- get online missing ad igelos devices (user)
- script cert request
- save cert in share on ndes (accessible) share
- create ad igelos devices (user)
- name mapping ad igelos devices (user) to cert - security identity mapping x509 cert
- create ad igelos devices (device)

#>
<#


# create ad user with name of the device

#>
