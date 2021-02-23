#requires -PSEdition Desktop

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
