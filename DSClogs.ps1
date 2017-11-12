Show-EventLog -ComputerName SRV3

#region Using Eventlogs

Get-WinEvent -ListLog *dsc*,*desired* -ComputerName SRV3 | 
Format-List

$paramHash = @{
 LogName = "Microsoft-Windows-DSC/Operational"
 ComputerName = "SRV3"
 MaxEvents = 25
}

Get-WinEvent @paramHash | Out-GridView

#add filtering
#construct a hash table for the -FilterHashTable parameter in Get-WinEvent
$start = (Get-Date).AddDays(-1)
$filter= @{
Logname= "Microsoft-Windows-DSC/Operational"
Level=2,3
StartTime= $start
} 

#get all errors and warnings in the last 14 days
Get-WinEvent -FilterHashtable $filter -Computer SRV3 | 
Out-GridView -Title "DSC Events"

#or use XML
#errors and warnings in the last 7 days
$xml=@"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-DSC/Operational">
    <Select Path="Microsoft-Windows-DSC/Operational">*
    [System[(Level=2 or Level=3) and 
    TimeCreated[timediff(@SystemTime) 
    &lt;= 604800000]]]</Select>
  </Query>
</QueryList>
"@

Get-WinEvent -FilterXml $xml -ComputerName SRV1 | 
Out-GridView

#Tip: use EventViewer to build XML

#enable Analytic and Debug logs
#must be run locally on the server
invoke-command {
 Wevtutil.exe set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:true
 Wevtutil.exe set-log "Microsoft-Windows-Dsc/Debug" /q:true /e:true
} -computername SRV3

<# disable

invoke-command {
Wevtutil.exe set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:false
Wevtutil.exe set-log "Microsoft-Windows-Dsc/Debug" /q:true /e:false
} -computername SRV3

#>

Get-WinEvent -ListLog "Microsoft-Windows-dsc/Analytic" -ComputerName SRV3

#but this is a special type of log
Get-WinEvent "Microsoft-Windows-dsc/Analytic" -ComputerName SRV3 -MaxEvents 25 | Out-GridView

#nothing new will show up until after the log is enabled
Update-DscConfiguration -ComputerName srv3 -Wait -Verbose
Test-DscConfiguration -ComputerName srv3

Get-WinEvent "Microsoft-Windows-dsc/Analytic" -ComputerName SRV3 -MaxEvents 25 -Oldest | 
Out-GridView

#events grouped by job
Get-DscConfiguration -CimSession SRV3

$DscEvents = Get-WinEvent "Microsoft-windows-dsc/operational" -ComputerName SRV3
$DscEvents += Get-WinEvent "Microsoft-Windows-Dsc/Analytic","Microsoft-Windows-Dsc/Debug" -Oldest -ComputerName SRV3
$DscEvents.count

#job ID
$DscEvents[0].Properties[0].value
#group by job Id
$DSCGrouped = $DscEvents | group {$_.Properties[0].value} | sort name

$DSCGrouped

#sample data
($DSCGrouped[0..10]) | 
Format-Table -GroupBy Name -Property @{Name="Time";
Expression={$_.Group.timecreated}},
@{Name="Message";Expression={$_.Group.Message}},
@{Name="Log";Expression={$_.group.containerLog}} -Wrap

#get today's events from all logs
$DscEvents.where({$_.timecreated -ge (Get-Date).Date}) | 
sort TimeCreated  | 
Select TimeCreated,Message | 
Out-GridView

#find non Information events
$DscEvents.where({$_.leveldisplayname -ne 'Information'})

#create a grouped hashtable based on entry type (LevelDisplayName)
$DSCLevels = $DscEvents | 
Group LevelDisplayname -AsHashTable
$DSCLevels

#display sample of entries for Error
$DSCLevels.error[0..10]

#view errors
$DSCLevels.error | Sort TimeCreated -descending | 
Select TimeCreated,Message | 
Out-GridView

#endregion

cls
