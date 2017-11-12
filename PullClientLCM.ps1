#requires -version 5.0 

[dsclocalconfigurationmanager()]
Configuration LCMPull {

Param([string]$Computername,[string]$guid)

Node $Computername {

ConfigurationRepositoryWeb  Pull {
 ServerURL = "https://dsc.company.pri:8080/PSDSCPullServer.svc"
 AllowUnsecureConnection = $False
 #CertificateID = "A GUID that represents the certificate used to authenticate to the server."
 #RegistrationKey =  shared secret for named configurations
 #ConfigurationNames =  An array of names of configurations to be pulled by the target node. 
}

ResourceRepositoryWeb Pull {
    ServerURL = "https://dsc.company.pri:8080/PSDSCPullServer.svc"
    AllowUnsecureConnection = $False
}

ReportServerWeb Pull {
    ServerURL = "https://dsc.company.pri:8080/PSDSCPullServer.svc"
    AllowUnsecureConnection = $false
}

Settings {
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyAndAutoCorrect'
    RefreshMode = 'Pull'
    ActionAfterReboot = 'ContinueConfiguration'
    ConfigurationID = $GUID
    AllowModuleOverwrite = $true
}


} #node


} #config

$guid = (New-Guid).guid

LCMPull -computername SRV3 -guid $guid -output c:\dsc\lcmpull