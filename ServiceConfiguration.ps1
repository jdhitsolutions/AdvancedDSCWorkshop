#requires -version 5.0

Configuration ServiceConfiguration {
Param([string[]]$Computername)

Import-DscResource -ModuleName 'PSDesiredStateConfiguration' 
Node $Computername {

Service RemoteRegistry {
    Name = 'RemoteRegistry'
    State = 'Running'
    StartupType = 'Automatic'
}
Service Defender {
    Name = 'WinDefend'
    State = 'Running'
    StartupType = 'Automatic'
}

Service Bits {
    Name = 'Bits'
    StartupType = 'Manual'
}

Service Spooler {
    Name = 'Spooler'
    State = 'Stopped'
    StartupType = 'Disabled'
}

Service SharedAccess {
    Name = 'SharedAccess'
    State = 'Stopped'
    StartupType = 'Disabled'
}

} #node


}

ServiceConfiguration -Computername SRV3 -OutputPath C:\dsc\PartialDemo\ServiceConfiguration
