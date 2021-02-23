<#
SCEPDeployment Config
#>

@{

  SSHCredentialPath = 'C:\Credentials\SSH.cred'
  UMSServer         = 'igelrmserver.acme.org'
  UMSCredentialPath = 'C:\Credentials\UMSAPI.cred'
  DeploymentDirName = 'Deployment'
  DeviceNamePrefix  = 'IGELOS-'
  DCServer          = 'srv-dc-01.acme.org'
  SearchBaseColl    = @( 
    'OU=Computers,OU=department1,DC=acme,DC=org'
    'OU=Computers,OU=department2,DC=acme,DC=org' )
}
