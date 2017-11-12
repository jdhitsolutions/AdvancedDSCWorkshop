#Demo using composite resource

Configuration MyComposite {

Param([string]$Computername)

Import-DscResource -ModuleName CompanyConfig

Node $Computername {

#vvv this is the composite resource vvvv
Company Core {
    DomainName = "Company.pri"
    InterfaceAlias = "Ethernet"
}
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

service Wuauserv {
    Name = "Wuauserv"
    Ensure = 'Present'
    State = 'Running'
    StartupType = 'Automatic'
}

WindowsFeature Containers {
    Name = 'Containers'
    Ensure = 'Present'
    IncludeAllSubFeature = $True
    DependsOn = "[Company]Core"
    
}

LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite = $True
    ConfigurationMode = 'ApplyAndAutoCorrect'

} #LCM

} #node
} #configuration
 

 MyComposite -computername SRV1 -OutputPath c:\DSC\Composite