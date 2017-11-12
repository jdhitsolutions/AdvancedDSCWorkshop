#requires -version 4.0 

Configuration DemoPullConfig {

Param([string[]]$Computername)

Import-DscResource -moduleName PSDesiredStateConfiguration,
@{ModuleName='xNetworking';RequiredVersion = '5.2.0.0'},
@{ModuleName='xTimeZone';RequiredVersion = '1.6.0.0'},
@{ModuleName='xSMBShare';RequiredVersion = '2.0.0.0'}

Node $Computername {

xTimeZone Eastern {
    TimeZone = "Central Standard Time"
    IsSingleInstance = "Yes"
    
}  #end xTimeZone

File Stuff {
	DestinationPath = "C:\Stuff"
	Ensure = "Present"
	Force = $True 
	Type = "Directory"

} #end File resource

xSMBShare Stuff {
    Name = "Stuff$"
    Path = "c:\stuff"
    Description = "company stuff"
    Ensure = 'Present'
    FolderEnumerationMode = 'AccessBased'
    FullAccess = "company\domain admins"
    DependsOn = "[file]Stuff"
}

xDnsServerAddress CompanyDNS   {
    Address        = "192.168.3.10","8.8.8.8"
    InterfaceAlias = "Ethernet"
    AddressFamily  = "IPv4"

} #end DNSServer resource

WindowsFeature SNMP {
    Name = "SNMP-Service"
    Ensure = 'Present'
    IncludeAllSubFeature = $True 
}


} #end node

} #close configuration


DemoPullConfig -Computername SRV3 -OutputPath c:\dsc\DemoPullConfig