#requires -version 5.0

#create a new local

configuration LocalGroup {

Param()

Import-DscResource -ModuleName PSDesiredStateConfiguration

Node $Allnodes.NodeName {

Group Localadmin {
 GroupName = "Administrators"
 Ensure = 'Present'
 MembersToInclude  = @("company\aprils","company\help desk")
 psdscrunasCredential = $node.credential
}

LocalConfigurationManager {
    ActionAfterReboot = 'ContinueConfiguration'
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyAndMonitor'
    CertificateID = $node.thumbprint #<--- LCM need to know what certificate to use
    RefreshMode = 'Push'
}

} #node

}

#run this script to define the configuration