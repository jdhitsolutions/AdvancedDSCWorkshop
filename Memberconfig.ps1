#requires -version 5.0

Configuration Member {

Param()

Import-DscResource -ModuleName PSDesiredStateConfiguration,
@{ModuleName = 'xSMBShare';RequiredVersion = '2.0.0.0'},
@{ModuleName = 'xWinEventLog';RequiredVersion = '1.1.0.0'},
@{ModuleName = 'xTimeZone';RequiredVersion = '1.6.0.0'},
@{ModuleName = 'xNetworking';RequiredVersion = '5.2.0.0'}

Node $AllNodes.NodeName {

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
    FullAccess = 'Company\domain admins'
    NoAccess = 'Company\Domain Users'
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
    InterfaceAlias = $Node.InterfaceAlias       
}
        
xFirewall SMB {
    Name = 'FPS-SMB-In-TCP'
    Action = 'Allow'
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $Node.InterfaceAlias         
}

xFirewall RemoteEvtLogFWRule1 {
    Name = "RemoteEventLogSvc-In-TCP"
    Action = "Allow"
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $Node.InterfaceAlias          
}

xFirewall RemoteEvtLogFWRule2 {
    Name = "RemoteEventLogSvc-NP-In-TCP"
    Action = "Allow"
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $Node.InterfaceAlias         
}

xFirewall RemoteEvtLogFWRule3 {
    Name = "RemoteEventLogSvc-RPCSS-In-TCP"
    Action = "Allow"
    Direction = 'Inbound'
    Enabled = $True
    Ensure = 'Present'
    InterfaceAlias = $Node.InterfaceAlias      
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


LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite = $True
    ConfigurationMode = 'ApplyAndAutoCorrect'

} #LCM

} #node

Node $allnodes.Where({$_.roles -eq 'File'}).Nodename {

    WindowsFeature FileServices {
        Name = "FileAndStorage-Services"
        Ensure = "Present"
        IncludeAllSubFeature = $True
    } 

   File Public {
    Ensure = 'Present'
    DestinationPath = 'C:\Public'
    Type = 'Directory'
   }

   File Sales {
    Ensure = 'Present'
    DestinationPath = 'C:\Sales'
    Type = 'Directory'
   }

   xSmbShare Public {
    Name = "Public"
    Path = "C:\Public"
    Ensure = 'Present'
    Description =   "Public folder share"
    DependsOn = "[file]Public"
    fullAccess = "$($Node.Domain)\Domain Admins"
    ChangeAccess = "$($Node.Domain)\Domain Users"
   }

   xSmbShare Sales {
    Name = "Sales"
    Path = "C:\Sales"
    Ensure = 'Present'
    Description =   "Sales department share"
    DependsOn = "[file]Sales"
    FullAccess = "$($Node.Domain)\Domain Admins"
    ChangeAccess = "$($Node.domain)\Sales"
    ReadAccess = "$($Node.Domain)\Domain Users"
   }
 } #file

Node $allnodes.Where({$_.roles -eq 'Web'}).Nodename {

    WindowsFeature Web {
        Name = "Web-WebServer"
        Ensure = "Present"
        IncludeAllSubFeature = $True
    } 
   WindowsFeature OData {
        Name = "ManagementOData"
        Ensure = "Present"
    } 
   
   WindowsFeature PSWA {
    name = 'WindowsPowerShellWebAccess'
    Ensure = 'Present'
    DependsOn = "[WindowsFeature]Web"

   }
 } #Web

} #configuration

$ConfigData = @{
    AllNodes = @(
    @{
        NodeName = '*'
        InterfaceAlias = 'Ethernet'
        Domain = 'Company'
    },
    @{NodeName = 'SRV1';Roles='File'},
    @{NodeName = 'SRV2';Roles='Web'}
)}

#run it
member -ConfigurationData $ConfigData -OutputPath c:\DSC\Member



