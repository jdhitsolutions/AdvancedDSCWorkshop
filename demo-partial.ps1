#requires -version 5.0

#read more: https://msdn.microsoft.com/en-us/powershell/dsc/partialconfigs

#configure the LCM to accept partial configurations

Return "This is a demo file you silly human."

#region the configurations

psedit .\ServiceConfiguration.ps1
psedit .\FeaturesConfiguration.ps1

#endregion

#region the LCM config needed to enable partials

[DSCLocalConfigurationManager()]
configuration PartialConfig {
Param([string[]]$Computername)

Node $Computername   {

    PartialConfiguration ServiceConfiguration #<-- Name must match eventual configuration
    {
        Description = 'Configuration to configure services.'
        RefreshMode = 'Push'
    }
    PartialConfiguration FeaturesConfiguration #<-- Name must match eventual configuration
    {
        Description = 'Configuration for Windows Features'
        RefreshMode = 'Push'
    }
    
    Settings    {
        RebootNodeIfNeeded = $True
        ConfigurationMode = 'ApplyAndAutoCorrect'
        AllowModuleOverwrite = $True
    }
            
} #node
} #config

PartialConfig -Computername SRV3 -OutputPath c:\DSC\PartialDemo

psedit C:\dsc\PartialDemo\SRV3.meta.mof
#endregion

#region deploy
#wipe current config
Remove-DscConfigurationDocument -Stage Current -CimSession SRV3
#current LCM
Get-DscLocalConfigurationManager -cimsession SRV3

#push new LCM config
Set-DscLocalConfigurationManager -Path C:\dsc\PartialDemo -Verbose

$lcm = Get-DscLocalConfigurationManager -cimsession SRV3
$lcm.PartialConfigurations

#publish partial configs with Publish-DSCConfiguration
Get-DscConfiguration -CimSession SRV3

#enable a feature to be removed
Add-WindowsFeature -Name Wins -ComputerName SRV3

Publish-DscConfiguration -Path C:\dsc\PartialDemo\FeaturesConfiguration -Verbose
Publish-DscConfiguration -Path C:\dsc\PartialDemo\ServiceConfiguration -Verbose

#endregion

#region apply with Start-DSCConfiguration and -UseExisting
Start-DscConfiguration -ComputerName SRV3 -Wait -UseExisting -Verbose

#wait for server to reboot if necessary

Get-windowsfeature -ComputerName SRV3 | where installed
Test-DscConfiguration -ComputerName SRV3 -Detailed

get-service remoteregistry,windefend,bits,spooler -com srv3 | 
Select name,displayname,status,StartType,machinename | format-table

#endregion