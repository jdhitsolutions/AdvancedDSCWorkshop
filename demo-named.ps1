
Return "This is a walkthrough demo. Pay attention!"

#region configuration

Configuration NamedConfig {

Param([string[]]$Computername)

Import-DscResource -moduleName PSDesiredStateConfiguration,
@{ModuleName="xWinEventLog";Moduleversion="1.1.0.0"}

Node $Computername {

File FileData {
	DestinationPath = "C:\Files"
	Ensure = "Present"
	Force = $True 
	Type = "Directory"

} #end File resource

File Test {
    DestinationPath = "C:\files\Data.txt"
    Contents = "Lorem Ipsum Factum. Hinky Dinky Doo."
    DependsOn = "[file]FileData"
    Ensure = "Present"
    Type = "File"
}

xWinEventLog Security {
    LogName = "Security"
    IsEnabled = $True
    LogMode = "Retain"
    MaximumSizeInBytes = 1GB
    
}

Registry CompanyReg {
    Key = "HKey_Local_Machine\Software\CompanyData"
    Ensure = "present"
    valueName = "R-Record"
    ValueData = "AQ-12-CK-5684"
    ValueType = 'String'
}

Service RemoteRegistry {
    Name = "RemoteRegistry"
    Ensure = "Present"
    StartupType = "Disabled"
    State = "Stopped"
}

WindowsFeature InternalDB {
    Name = "Windows-Internal-Database"
    Ensure = "Present"
    IncludeAllSubFeature = $True
    }

} #end node

} #close configuration

$computer = "SRV1"

NamedConfig -computername $Computername -outputpath C:\DSC\DemoNamed

#rename the mof
# delete existing Named entries
# dir C:\dsc\DemoNamed\named* | del
rename-item C:\dsc\DemoNamed\SRV1.mof -NewName "Named.mof" -force

#checksum it
New-DscChecksum -Path C:\dsc\DemoNamed\named.mof -OutPath C:\dsc\DemoNamed

dir c:\dsc\DemoNamed

#copy to pull server
$pull = "srv2"
$sess = New-PSSession -ComputerName $pull

#if necessary
# icm {dir "C:\Program Files\WindowsPowerShell\DscService\Configuration\Named*"| del} -session $sess

$paramHash = @{
 Path = "c:\dsc\DemoNamed\Named*" Destination = "C:\Program Files\WindowsPowerShell\DscService\Configuration" Force = $True ToSession = $Sess}

Copy-Item @paramHash
#verify
invoke-command { dir $using:paramhash.destination} -session $sess

#endregion

#region LCM

#need some sort of shared secret. A GUID is probably best
$myRegKey = (new-guid).guid   #Get-Random -min 100000 -Maximum 250000
$myRegKey

#need to copy the key to the pull server

Set-Content -Path c:\DSC\RegistrationKeys.txt -Value $myRegKey
cat C:\DSC\RegistrationKeys.txt
$paramhash.Destination = "c:\Program Files\WindowsPowerShell\DscService"
$paramhash.Path = "C:\DSC\RegistrationKeys.txt"
Copy-item @paramhash

invoke-command -scriptblock { dir $using:paramhash.Destination } -session $sess

#define a new LCM configuration
[DSCLocalConfigurationManager()]
Configuration DEMO_LCM_ConfigName {
    param
        (
            [Parameter(Mandatory)]
            [string[]]$ComputerName,

            #[Parameter(Mandatory=$true)]
            #[string]$guid, <------------------------Don't need this anymore

            [Parameter(Mandatory)]
            [string]$RegistrationKey,

            [Parameter(Mandatory)]
            [string]$ThumbPrint #<---------- still need this

        )      	
	Node $ComputerName {
	
		Settings {
		
			AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshMode = 'Pull'
			ConfigurationID = "" # Setting to blank - but can leave a guid in - won't matter
            }

            ConfigurationRepositoryWeb DSCHTTPS {
                ServerURL = 'https://DSC.company.pri:8080/PSDSCPullServer.svc'
                CertificateID = $Thumbprint
                AllowUnsecureConnection = $False
                RegistrationKey = "$RegistrationKey" # <----------- We Need this 
                ConfigurationNames = @("Named")      # <----------- The names of your configuration
                <#
                Note: If you specify more than one value in the ConfigurationNames, 
                you must also specify PartialConfiguration blocks in your configuration. 
                #>
            }
            ReportServerWeb CompanyPullSrv {
                ServerURL = 'https://DSC.company.pri:8080/PSDSCPullServer.svc'
        }
	}
}

$Thumbprint = Invoke-Command -Computername 'srv2' -scriptblock {
Get-Childitem Cert:\LocalMachine\My | Where-Object {$_.Subject -match  "^CN=DSC"} | 
Select-Object -ExpandProperty ThumbPrint
}

$computer = "SRV1"

# Create the Computer.Meta.Mof in folder
DEMO_LCM_ConfigName -ComputerName $computer -Thumbprint $Thumbprint -registrationKey $myRegKey -OutputPath C:\dsc\DemoNamed

psedit C:\dsc\DemoNamed\SRV1.meta.mof

#set the server

#may need to reset it
# .\ResetDSC.ps1 -Computername srv1 -Verbose
# Get-DscLocalConfigurationManager -cimsession $computer

Set-DscLocalConfigurationManager -cimsession $computer -Path c:\dsc\DemoNamed -verbose

#endregion

#region Use it

Get-DSCLocalConfigurationmanager -CimSession $computer
Get-DSCLocalConfigurationmanager -CimSession $computer | 
Select -ExpandProperty ConfigurationDownLoadManagers

Update-DscConfiguration -Wait -Verbose -CimSession $computer

Get-DscConfiguration -CimSession $computer

dir \\$computer\c$\files
get-windowsfeature -ComputerName SRV1 -Name windows-internal-database
cls

#endregion

#clean up and reset

dir C:\dsc\DemoNamed | del
icm {dir "C:\Program Files\WindowsPowerShell\DscService\Configuration\named*" | del} -session $sess
icm {dir "C:\Program Files\WindowsPowerShell\DscService\registrationkeys.txt" | del} -session $sess

remove-pssession $sess