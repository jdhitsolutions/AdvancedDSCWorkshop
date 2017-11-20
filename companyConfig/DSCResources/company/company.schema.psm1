#requires -version 5.0

#configuration that will become a composite resource

Configuration Company {

Param(
[ValidateNotNullorEmpty()]
[string]$InterfaceAlias = 'Ethernet',
[Parameter(Mandatory)]
[ValidateNotNullorEmpty()]
[string]$DomainName
)


Import-DscResource -ModuleName PSDesiredStateConfiguration,
@{ModuleName = 'xSMBShare';RequiredVersion='2.0.0.0'},
@{ModuleName = 'xWinEventLog';RequiredVersion = '1.1.0.0'},
@{ModuleName = 'xTimeZone';RequiredVersion = '1.6.0.0'},
@{ModuleName = 'xNetworking';RequiredVersion = '5.2.0.0'}

#NO NODE

File Work {
    DestinationPath = 'C:\Work'
    Type =  'Directory'
    Ensure = 'Present'
}

Service RemoteReg {
    Name = 'RemoteRegistry'
    State = 'Running'
    StartupType = 'Automatic'
    Ensure = 'Present'
}

WindowsFeature Backup {
    Name = 'Windows-Server-Backup'
    Ensure = 'Present'
    IncludeAllSubFeature = $True
}

xSMBShare WorkShare {    
    DependsOn = '[File]Work'
    Name = 'Work$'
    Path = 'C:\work'
    FullAccess = "$DomainName\Domain Admins"
    NoAccess = "$DomainName\Domain Users"
    Ensure = 'Present'
}

xTimeZone TZ {
	IsSingleInstance = 'Yes'
	TimeZone = "Central Standard Time"
} 
 
xWinEventLog Security {
    LogName = 'Security'
    MaximumSizeInBytes = 256MB
    IsEnabled = $True
    LogMode = 'AutoBackup' 

}

xFirewall vmpingFWRule {
    Name = 'vm-monitoring-icmpv4'
    Action = 'Allow'
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $InterfaceAlias       
}
        
xFirewall SMB {
    Name = 'FPS-SMB-In-TCP'
    Action = 'Allow'
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $InterfaceAlias         
}

xFirewall RemoteEvtLogFWRule1 {
    Name = "RemoteEventLogSvc-In-TCP"
    Action = "Allow"
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $InterfaceAlias          
}

xFirewall RemoteEvtLogFWRule2 {
    Name = "RemoteEventLogSvc-NP-In-TCP"
    Action = "Allow"
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $InterfaceAlias         
}

xFirewall RemoteEvtLogFWRule3 {
    Name = "RemoteEventLogSvc-RPCSS-In-TCP"
    Action = "Allow"
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $InterfaceAlias      
}
   

#Enable DSC Analytic logs 

Script DSCAnalyticLog {

    DependsOn = '[xFirewall]RemoteEvtLogFWRule3'
    TestScript = {
                    $status = wevtutil get-log "Microsoft-Windows-Dsc/Analytic"
                    if ($status -contains "enabled: true") {return $True} else {return $False}
                }
    SetScript = {
                    wevtutil.exe set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:true
                }
    getScript = {
                    $Result = wevtutil get-log "Microsoft-Windows-Dsc/Analytic"
                    return @{Result = $Result}
                }
}


} #end configuration