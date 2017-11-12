#requires -version 5.0

Configuration FeaturesConfiguration {

Param([string[]]$Computername)

Import-DscResource -ModuleName 'PSDesiredStateConfiguration' 

Node $Computername {

WindowsFeature InternalDB {
    Name = 'Windows-Internal-Database'
    Ensure = 'Present'
    IncludeAllSubFeature = $True

}

WindowsFeature Defender {
    Name = 'Windows-Defender'
    Ensure = 'Present'
}

WindowsFeature TelnetClient {
    Name = 'Telnet-Client'
    Ensure = 'Present'
}

WindowsFeature PowerShell2 {
    Name = 'PowerShell-V2'
    Ensure = 'Absent'
}

WindowsFeature Wins {
    Name = 'Wins'
    Ensure = 'Absent'
}

WindowsFeature SNMP {
    Name = 'SNMP-Service'
    Ensure = 'Present'
    IncludeAllSubFeature = $True
}
} #node

} #config

FeaturesConfiguration -Computername SRV3 -OutputPath C:\dsc\PartialDemo\FeaturesConfiguration