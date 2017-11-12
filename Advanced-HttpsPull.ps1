
#region define the configuration

Configuration HTTPSPullserver {
    # Import the module that defines custom resources
    Import-DscResource -Module PSDesiredStateConfiguration,  
    @{ModuleName='xPSDesiredStateConfiguration';RequiredVersion='5.0.0.0'}

    # Dynamically find the applicable nodes from configuration data
    Node $AllNodes.where{$_.Role -eq 'Web'}.NodeName {    

        <# 
         Install the IIS role - you might want to install the features 
         manually to control Security
         #>

#        WindowsFeature IIS {
#        
#            Ensure = "Present"
#            Name = "Web-Server"
#        }

#       # Make sure the following defaults cannot be removed:        

        WindowsFeature DefaultDoc {
        
            Ensure = "Present"
            Name = "Web-Default-Doc"
            
        }

        WindowsFeature HTTPErrors {
        
            Ensure = "Present"
            Name = "Web-HTTP-Errors"
            
        }

        WindowsFeature HTTPLogging {
        
            Ensure = "Present"
            Name = "Web-HTTP-Logging"
           
        }

        WindowsFeature StaticContent {
        
            Ensure = "Present"
            Name = "Web-Static-Content"
            
        }

        WindowsFeature RequestFiltering {
        
            Ensure = "Present"
            Name = "Web-Filtering"
            
        }
        
 #      # Install additional IIS components to support the Web Application 

        WindowsFeature NetExtens4 {
        
            Ensure = "Present"
            Name = "Web-Net-Ext45"
            
        }

        WindowsFeature AspNet45 {
        
            Ensure = "Present"
            Name = "Web-Asp-Net45"
            
        }

        WindowsFeature ISAPIExt {
        
            Ensure = "Present"
            Name = "Web-ISAPI-Ext"
           
        }

        WindowsFeature ISAPIFilter {

            Ensure = "Present"
            Name = "Web-ISAPI-filter"
            
        }
 
 
        WindowsFeature DirectoryBrowsing {
        
            Ensure = "Present"
            Name = "Web-Dir-Browsing"
            
        }
     

        WindowsFeature StaticCompression {
        
            Ensure = "Present"
            Name = "Web-Stat-Compression"
            
        }        

        # I don't want these Additional settings for Web-Server to ever be enabled:
        # This list is shortened for demo purposes. I include eveything that should not be installed

       WindowsFeature ASP {
        
            Ensure = "Absent"
            Name = "Web-ASP"
            
        }

       WindowsFeature CGI {
        
            Ensure = "Absent"
            Name = "Web-CGI"
            
        }

       WindowsFeature IPDomainRestrictions {
        
            Ensure = "Absent"
            Name = "Web-IP-Security"
           
        }

# !!!!! # GUI Remote Management of IIS requires the following: - people always forget this until too late

        WindowsFeature Management {

            Name = 'Web-Mgmt-Service'
            Ensure = 'Present'
        }

        Registry RemoteManagement { # Can set other custom settings inside this reg key

            Key = 'HKLM:\SOFTWARE\Microsoft\WebManagement\Server'
            ValueName = 'EnableRemoteManagement'
            ValueType = 'Dword'
            ValueData = '1'
            DependsOn = @('[WindowsFeature]Management')
       }

       Service StartWMSVC {

            Name = 'WMSVC'
            StartupType = 'Automatic'
            State = 'Running'
            DependsOn = '[Registry]RemoteManagement'

       }
 
    } #End Node Role Web

###############################################################################

    Node $AllNodes.where{$_.Role -eq 'PullServer'}.NodeName {

#       # This installs both, WebServer and the DSC Service for a pull server
#       # You could do everything manually 

         WindowsFeature DSCServiceFeature {

            Ensure = "Present"
            Name   = "DSC-Service"
        }

       xDscWebService PSDSCPullServer {
        
            Ensure = "Present"
            EndpointName = $Node.PullServerEndPointName
            Port = $Node.PullServerPort   # <----------------------- Why this port?
            PhysicalPath = $Node.PullserverPhysicalPath
            CertificateThumbPrint =  $Node.PullServerThumbprint # <---- Certificate Thumbprint
            ModulePath = $Node.PullServerModulePath
            ConfigurationPath = $Node.PullserverConfigurationPath
            State = "Started"
            UseSecurityBestPractices = $True
            DependsOn = "[WindowsFeature]DSCServiceFeature"
        }

       
    } # End Node PullServer

} # End Config

#endregion

#region create configuration data
$Thumbprint = Invoke-Command -Computername SRV2 -scriptblock {
 Get-Childitem Cert:\LocalMachine\My | 
 Where-Object {$_.Subject -match "^CN=DSC"} | 
 Select-Object -ExpandProperty ThumbPrint
 }

$ConfigData=@{
    # Node specific data
    AllNodes = @(

       # All Servers need following identical information 
       @{
            NodeName           = '*'
           # PSDscAllowPlainTextPassword = $true;
           # PSDscAllowDomainUser = $true
            
       },

       # Unique Data for each Role
       @{
            NodeName = 'srv2.company.pri'
            Role = @('Web', 'PullServer')
           
            PullServerEndPointName = 'PSDSCPullServer'
            PullserverPort = 8080                      #< - ask me why I use this port
            PullserverPhysicalPath = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer"
            PullserverModulePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            PullServerConfigurationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            PullServerThumbPrint = $thumbprint

        }


    );
} 

#endregion

#region create the config

HTTPSPullserver -ConfigurationData $ConfigData -OutputPath c:\DSC\Pull

#endregion

#region deploy
#make sure resources are deployed to the server

invoke-command { get-module xpsdesiredstate* -list } -comp srv2

Start-DscConfiguration -Wait -Verbose -Path c:\dsc\pull

#endregion