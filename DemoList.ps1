#requires -version 5.0

Return "This is a demo script, Jeff! (you goober)."
<#

DSC Review
passwords and credentials
Using a secure pull server
Using Partial Configurations
Using Composite Configurations
Using Named Configurations
Reporting and Troubleshooting

#>

#region member configuration

psedit .\Memberconfig.ps1

$s = New-PSSession SRV1,SRV2
#copy Resources
$needed = 'xWinEventLog','xTimeZone','xNetworking','xSMBShare'

foreach ($item in $s) {
   Split-Path (get-module $needed -ListAvailable ).ModuleBase | 
   Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $item
}
#verify
Invoke-command { Get-module $using:needed -list } -session $s

#push the LCM
Set-DscLocalConfigurationManager -Path C:\dsc\Member -force -Verbose
Get-DscLocalConfigurationManager -CimSession SRV1
Get-DscLocalConfigurationManager -CimSession SRV2

#push the configs one at a time for the sake of demonstration
psedit C:\dsc\Member\SRV1.mof
cls
Start-DscConfiguration -Path C:\dsc\Member -ComputerName SRV1 -Force -Wait -Verbose
cls
Start-DscConfiguration -Path C:\dsc\Member -ComputerName SRV2 -Force -Wait -Verbose

#may need to give configuration time to converge and complete
Test-DscConfiguration -ComputerName SRV1,SRV2 -Verbose -Detailed

#endregion

#region encrypt a credential password locally

Get-command -noun CMSMessage
dir Cert:\CurrentUser\my -DocumentEncryptionCert

#be careful about quoting
$certreq = @'
[Version]
Signature = "$Windows NT$"
    
[Strings]
szOID_ENHANCED_KEY_USAGE = "2.5.29.37"
szOID_DOCUMENT_ENCRYPTION = "1.3.6.1.4.1.311.80.1"
    
[NewRequest]
Subject = "cn=administrators@company.pri"
MachineKeySet = false
KeyLength = 2048
KeySpec = AT_KEYEXCHANGE
HashAlgorithm = Sha1
Exportable = true
RequestType = Cert
KeyUsage = "CERT_KEY_ENCIPHERMENT_KEY_USAGE | CERT_DATA_ENCIPHERMENT_KEY_USAGE"
ValidityPeriod = "Years"
ValidityPeriodUnits = "1000"
    
[Extensions]
%szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_DOCUMENT_ENCRYPTION%"
'@

Set-Content -Value $certreq -Path C:\mycert.inf
dir C:\mycert.inf

#add it
certreq -new C:\mycert.inf C:\mycert.cer

dir Cert:\CurrentUser\my -DocumentEncryptionCert 

$plainPass = "P@ssw0rd"

help Protect-CmsMessage -param To
Protect-CMSMessage -Content $plainPass -OutFile .\CMSPassword.txt -to cn=administrators@company.pri

get-content .\CMSPassword.txt

get-content .\cmspassword.txt | Unprotect-CmsMessage 

$securePass = ConvertTo-SecureString -String $(get-content .\cmspassword.txt | Unprotect-CmsMessage) -AsPlainText -force
$Cred = New-Object PSCredential "company\administrator",$securePass

#prove it
$cred
$cred.GetNetworkCredential().Password

#endregion

#region encrypting passwords the right way

<#
Note - WMF 5 now requires an additional Enhanced Key Usage of Document Encryption. 

The error message will contain the following:
Encryption certificates must contain the Data Encipherment or Key Encipherment key usage, and include the 
Document Encryption Enhanced Key Usage (1.3.6.1.4.1.311.80.1).

This means that after adding the template, you will need to perform
the following to add the new requirements.
1. Open MMC
2. Add Certificate Templates - pointed to ADCS
3. Open the properties of the Workstation Authentication certificate
4. Select Extensions tab
5. Edit the Application Policies and add Document Encyption

# Now, on the TARGET node, get the new certificate if not using autoenrollment
Invoke-Command -computername s2 {Get-Certificate -template 'workstation' -url https://dc.company.pri/ADPolicyProvider_CEP_Kerberos/service.svc/cep -CertStoreLocation Cert:\LocalMachine\My\ -Verbose}
#>

#request  the certificate

<# to do this remotely might require CredSSP or AD Delegation

$server = Get-ADComputer DOM1
$client = Get-ADComputer SRV3
Set-ADComputer -Identity $Server -PrincipalsAllowedToDelegateToAccount $client
#verify
Get-ADComputer -Identity $Server -Properties PrincipalsAllowedToDelegateToAccount

#need to purge tickets due to 15min SPN negative cache
Invoke-Command -ComputerName $Server.Name  -ScriptBlock {            
    klist purge -li 0x3e7            
}
#>

#I created my own certificate template - you can deploy however you want
 Invoke-Command -computername SRV1 {
   Get-Certificate -template 'CompanyComputer' -url https://DOM1.company.pri/ADPolicyProvider_CEP_Kerberos/service.svc/CEP -CertStoreLocation Cert:\LocalMachine\My\ -Verbose 
 }
 

#get certificate and thumbprint
$cert = Invoke-Command { 
     #get server authentication certs that have not expired
     dir Cert:\LocalMachine\my | 
     where {$_.EnhancedKeyUsageList.FriendlyName -contains "Document Encryption" -AND $_.notAfter -gt (Get-Date) -AND $_.Subject -eq "CN=SRV1.company.pri" } |
     Sort NotAfter -Descending | select -first 1
     } -computername SRV1 -ErrorAction Stop

$cert
#mkdir C:\Certs
Export-Certificate -Cert $cert -FilePath C:\Certs\SRV1.cer -Force

psedit .\ConfigLocalGroup.ps1

$DomainCredential = Get-Credential company\administrator

 #add cert thumbprint to encrypt credentials
$ConfigData = @{
    AllNodes = @(
    @{
        NodeName = "SRV1"
        Credential = $DomainCredential
        Thumbprint = $cert.thumbprint
        CertificateFile = 'C:\Certs\SRV1.cer'
        psDSCAllowDomainUser = $True
    }
    )
}

LocalGroup -ConfigurationData $ConfigData -OutputPath C:\dsc\localGroup

#view the encrypted password in the MOF
psedit C:\dsc\localGroup\SRV1.mof

<#
instance of MSFT_Credential as $MSFT_Credential1ref
{
Password = "-----BEGIN CMS-----\nMIIB4wYJKoZIhvcNAQcDoIIB1DCCAdACAQAxggGLMIIBhwIBADBvMFgxFTATBgoJkiaJk/IsZAEZ\nFgVsb2NhbDEcMBoGCgmSJomT8ixkARkWDEdMT0JPTUFOVElDUzEhMB8GA1UEAxMYR0xPQk9NQU5U\nSUNTLUNISS1EQzA0LUNBAhMdAAAAtjP8M3EFNZNQAAAAAAC2MA0GCSqGSIb3DQEBBzAABIIBAEdv\nLXcX8fjklAfsxDAY9RLSz7Ad814NbJ5leUq+g38oYHYAq82DxwEhAYdod1lOHRYacIZCN/UvTSvf\nbvq0+AKQM6NZ/Ya5cg1aROBe4aJnnnQlaIspsRWPrejZDNG9DAmzVldERo6je0ZjJVinGplOMUwr\nX4ArmLhNlw7vzjll+Lpyw6ubMCN4hHltHD5U5z7VkGlyjUd1aApIv8cn1FeBI8BIgbEnOLGC3lBv\n+O8hY731tvEnYwd0WLrGnCGVkByOAYwRwIUT+ad/xfUWudkucyY/ktQ5fciqFVcaWOo64qoO4R9n\nGcVOFGWD8huw+NoDDqx0iu6iEbdT7KOBkgswPAYJKoZIhvcNAQcBMB0GCWCGSAFlAwQBKgQQXUjO\nVq5lwicyWWpYMnCHDIAQ4HcMIXywBYvHJoVGQXftmQ==\n-----END CMS-----";
 UserName = "company\\administrator";

};

instance of MSFT_GroupResource as $MSFT_GroupResource1ref
{
ResourceID = "[Group]Localadmin";
 Members = {
    "company\\help desk"
};
 Credential = $MSFT_Credential1ref;
 SourceInfo = "C:\\users\\jeff.company\\Documents\\Magic Briefcase\\presentations\\ITDevConnections2016\\DSCWorkshop\\demos\\ConfigLocalGroup.ps1::11::1::Group";
 GroupName = "Administrators";
 ModuleName = "PSDesiredStateConfiguration";
 #>
#before
invoke-command { net localgroup administrators} -computer SRV1

#push the meta config
Set-DscLocalConfigurationManager -Path C:\dsc\localGroup -Verbose

#check the new cert id
Get-DscLocalConfigurationManager -CimSession SRV1

Start-DscConfiguration -Path C:\dsc\localGroup -Verbose -wait -force

invoke-command { net localgroup administrators} -computer SRV1


#endregion

#region setup a secure pull server

#setup a DNS record and associated certificate
Resolve-DnsName srv2.company.pri | Tee-object -Variable A

# DNS for Pull server
$paramHash = @{
 ComputerName = 'DOM1'
 name = 'DSC'
 ZoneName = 'company.pri'
 IPv4Address = $A.IP4Address
}

Add-DnsServerResourceRecordA @paramHash

Resolve-DnsName dsc.company.pri

# Enter you target web server
$ComputerName = 'SRV2' 

#this might require CredSSP or Kerberos delegation

Invoke-Command -computername $ComputerName -scriptblock {
    $params = @{
     template = 'WebServer2' 
     url = 'https://DOM1.company.pri/ADPolicyProvider_CEP_Kerberos/service.svc/CEP' 
     DnsName = "dsc.company.pri"
     CertStoreLocation = 'Cert:\LocalMachine\My\'
     SubjectName = 'CN=dsc.company.pri,OU=Servers,DC=Company,DC=Pri'
     Verbose = $True
    }
    Get-Certificate @params 
}
    
# Can Export to PFX if needed on other web servers for high availability - Get-Help *pfx*

Invoke-command -ComputerName $computername -ScriptBlock {
    dir Cert:\LocalMachine\My\
}

psedit .\Advanced-HttpsPull.ps1

enter-pssession srv2
get-website
exit

#endregion

#region pull configuration

#current status
Get-DscLocalConfigurationManager -CimSession SRV3
#clear DSC config for the sake of the demo
Remove-DscConfigurationDocument -Stage Current -CimSession srv3

Get-DscConfiguration -CimSession SRV3

psedit .\PullClientLCM.ps1

Set-DscLocalConfigurationManager -Path C:\dsc\lcmpull -ComputerName SRV3 -Verbose
Get-DscLocalConfigurationManager -CimSession SRV3

psedit .\SamplePullConfig.ps1

#need to rename config with guid and copy to pull server
$configid = (Get-DscLocalConfigurationManager -CimSession SRV3).ConfigurationID

rename-item C:\dsc\DemoPullConfig\SRV3.mof C:\dsc\DemoPullConfig\$configid.mof 
#it needs a checksum
New-DscChecksum -Path C:\dsc\DemoPullConfig\$configid.mof

dir C:\dsc\DemoPullConfig

#copy the mof and checksum to the pull server 
$s = new-pssession SRV2

dir C:\dsc\DemoPullConfig -file | 
copy -Destination "C:\program files\windowspowershell\dscservice\configuration" -ToSession $s

Invoke-Command { dir "C:\program files\windowspowershell\dscservice\configuration" } -session $s

#also need to copy resources to pull server
#need to restructure folder before zipping
#https://docs.microsoft.com/en-us/powershell/dsc/pullserver

invoke-item 'C:\Program Files\WindowsPowerShell\Modules\xTimeZone\'

$dest = "C:\DSCResources" 
if (-not (Test-path $dest)) { mkdir $dest}

Get-DscResource | 
where path -match "^c:\\Program Files\\WindowsPowerShell\\Modules" |
Select -ExpandProperty Module |
Select Name,Version,ModuleBase -unique | 
foreach {
 $out = "{0}_{1}.zip" -f $_.Name,$_.Version
 $zip = Join-Path -path $dest  -ChildPath $out
 write-host "Creating $out" -ForegroundColor green
 dir $_.modulebase | Compress-Archive -DestinationPath $zip -CompressionLevel Fastest -Force
  #give file a chance to close
 start-sleep -Seconds 1 
 If (Test-Path $zip) {
    Try {
        New-DSCCheckSum -Path $zip -ErrorAction Stop -Force
    }
    Catch {
        Write-Warning "Failed to create checksum for $zip"
    }
 }
 else {
    Write-Warning "Failed to find $zip"
 }
 
}

dir $dest

#copy over remoting
$target = "C:\Program Files\WindowsPowerShell\DSCService\Modules"
dir $dest | foreach {
    $_ | Copy-item -Destination $target -ToSession $s -Force
}

Invoke-command { dir $using:target} -session $s

remove-pssession $s

#clear DSCResource files
Invoke-Command { 
 dir 'C:\Program Files\WindowsPowerShell\Modules\x*' |
 del -Recurse -Force
} -comp SRV3

Invoke-command { Get-DscResource } -comp srv3

#force the member server to update
cls
Update-DscConfiguration -Wait -computerName SRV3 -Verbose

Get-DscConfiguration -CimSession srv3
get-smbshare -CimSession srv3

#endregion

#region v5 changes
#these commands don't seem to do much remotely

help Publish-ModuleToPullServer -full

help Publish-MOFToPullServer -full

#endregion

#region composite resources

# https://msdn.microsoft.com/en-us/powershell/dsc/authoringresourcecomposite

psedit .\companyConfig.ps1

#need this file structure
# <CompositeResourceName>\DSCResources\<ResourceName>
# mkdir companyConfig\DSCResources\company

#save as companyConfig.schema.psm1
copy .\companyConfig.ps1 -Destination .\companyConfig\DSCResources\company\company.schema.psm1 -PassThru

#need manifests
New-ModuleManifest -Path .\companyConfig\companyConfig.psd1
New-ModuleManifest -Path .\companyConfig\DSCResources\company\company.psd1 -RootModule company.schema.psm1

cls
dir .\companyConfig -Recurse

psedit .\companyConfig\companyConfig.psd1

#copy to PSModulePath
copy .\companyConfig -Destination 'C:\Program Files\WindowsPowerShell\Modules' -PassThru -Recurse -Container -Force

Get-DscResource company
Get-DscResource company -Syntax

psedit .\Demo-Composite.ps1
psedit C:\dsc\Composite\SRV1.mof

#deploy to pull server
$guid = (New-Guid).guid
LCMPull -computername SRV1 -guid $guid -output c:\dsc\lcmpull
Set-DscLocalConfigurationManager -Path C:\dsc\lcmpull -ComputerName SRV1 -force

psedit .\pushMoftoPull.ps1

dir C:\dsc\Composite\*.mof | Push-MofToPullServer -Verbose

#clear current MOFs for demo
Remove-DscConfigurationDocument -Stage Pending -CimSession SRV1
Remove-DscConfigurationDocument -Stage current -CimSession SRV1
cls
Update-DscConfiguration -Wait -computerName SRV1 -Verbose

#check later after reboot and configuration has finished
Get-DscConfiguration -CimSession srv1

#endregion

#region named configurations
# https://docs.microsoft.com/en-us/powershell/dsc/pullclientconfignames
psedit .\demo-named.ps1

#endregion

#region partial configurations

#is this a technical solution for a business process problem?

psedit .\demo-partial.ps1

#endregion

#region troubleshooting

#database viewer http://www.nirsoft.net/utils/ese_database_view.html
esedatabaseview

help Get-DscConfigurationStatus
Get-DscConfigurationStatus -CimSession srv1
Get-DscConfigurationStatus -CimSession srv3 | fl

Test-DscConfiguration -CimSession srv3 -Detailed

#event logs
psedit .\DSClogs.ps1

#reporting 
#https://docs.microsoft.com/en-us/powershell/dsc/reportserver
function Get-DSCReport {
[cmdletbinding()]
    param(
    [Parameter(Position=0,Mandatory)]
    [string]$Computername, 
    [string]$serviceURL = "https://DSC.company.pri:8080/PSDSCPullServer.svc"
    )
        
    $AgentId = (Get-DscLocalConfigurationManager -CimSession $Computername).AgentID
    $requestUri = "$serviceURL/Nodes(AgentId= '$AgentId')/Reports"
    $params = @{
      Uri = $requestUri
      ContentType = "application/json;odata=minimalmetadata;streaming=true;charset=utf-8"
      UseBasicParsing = $True
      Headers = @{Accept = "application/json";ProtocolVersion = "2.0"}
      ErrorAction = "Stop"
    }
    Try {
    Write-Verbose "Querying $requestUri"
        $request = Invoke-RestMethod @params
        #$object = ConvertFrom-Json $request.content
        $request.value
    }
    Catch {
        Throw $_
    }
}

#may need to do this to handle SSL connection
# $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
# [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

$r = Get-DSCReport -Computername srv1 -Verbose
$r.count
$r[0]
$r[0].StatusData | ConvertFrom-Json
($r[0].StatusData | ConvertFrom-Json).ResourcesInDesiredState

$r | Select JobID,@{N="Start";E={$_.StartTime -as [datetime]}},
@{N="Finish";E={$_.EndTime -as [datetime]}},OperationType,RefreshMode,Status |
Out-Gridview

#endregion