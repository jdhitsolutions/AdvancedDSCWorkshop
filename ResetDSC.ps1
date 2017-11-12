#reset DSC

[cmdletbinding()]
Param(
[Parameter(Mandatory,Position=0)]
[string[]]$Computername

)

[DSCLocalConfigurationManager()]
configuration StandardLCM {
Param([string[]]$Computername)

Node $Computername   {

     Settings    {
        RebootNodeIfNeeded = $True
        ConfigurationMode = 'ApplyAndMonitor'
        AllowModuleOverwrite = $True
        RefreshMode = 'Push'
    }
            
} #node
} #config

StandardLCM -computername $computername -output c:\dsc\standard

Write-Host "Setting LCM back to default" -ForegroundColor Cyan
Set-DscLocalConfigurationManager -Path C:\dsc\standard -Verbose

Write-Host "Removing DSC documents" -ForegroundColor cyan
Remove-DscConfigurationDocument -Stage Pending -CimSession $Computername
Remove-DscConfigurationDocument -Stage Current -CimSession $Computername
