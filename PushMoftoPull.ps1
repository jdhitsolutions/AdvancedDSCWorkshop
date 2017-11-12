#requires -version 5.1

Function Push-MofToPullServer {
[cmdletbinding()]
Param(
[Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName)]
[ValidatePattern({\.mof$})]
[string]$FullName,
#the name of your pull server
[string]$PullServer = "SRV2"
)

Begin {
    Write-Verbose "Creating a PSSession to $Pullserver"
    $sess = New-PSSession -ComputerName $PullServer
}

Process {
    Write-Verbose "Processing $fullname"
    $filename = Split-path $fullname -Leaf
    $computername = $filename.split(".")[0]
    Write-Verbose "Getting configuration ID from $computername"
    $configid = (Get-DscLocalConfigurationManager -CimSession $computername).ConfigurationID
    if ($configid) {
        $new = $fullname.replace($Computername,$configID)
        Write-Verbose "Renaming to $new"
        rename-item $fullname $new -Force
        Write-Verbose "Adding a checksum"
        New-DscChecksum -Path $new -force

        Write-Verbose "copy the mof and checksum to the pull server"
        write-verbose $new
        Copy-Item -Path $new -Destination "C:\program files\windowspowershell\dscservice\configuration" -ToSession $sess
        write-verbose "$new.checksum"
        Copy-Item -Path "$new.checksum" -Destination "C:\program files\windowspowershell\dscservice\configuration" -ToSession $sess
    }
    else {
        Write-Warning "$Computername does not appear to be configured for pull"
    }
}

End {
    Write-Verbose "Removing PSSession"
    $sess| Remove-PSsession
}

}