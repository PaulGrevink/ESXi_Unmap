<#
.Synopsis
    UnmapDeploy.ps1 performs an unmap for datastores in a vSphere Cluster

.DESCRIPTION
    Unmap.ps1 performs an unmap for datastores in a vSphere Cluster
    The script performs the following actions:

.EXAMPLE  
    Example with all parameters
    .\UnmapDeploy.ps1 -ServerCSV "server.csv" -vcenter "vcsa.acme.com" -WorkingDirectory "C:\TEMP" -logfile "Unmap_date.log"

.PARAMETERS
    -ServerCSV = valid name for the hosts to run the unmap scripts, example: -ServerCSV "blue.csv"

    -vcenter = valid name for a vCenter Server, example: -vcenter "vcsa.acme.com"

    -workingDirectory = Override default working folder, example: -workingDirectory"C:\TEMP".
        Default folder is the current folder.

    -logfile = Override default logfile, example: -logfile "MyLog.log"
        Default log file is named "CompareEsxHostsCluster_YYMMDD_hhmmss.log" and is located in the WorkingDirectory.

.INPUTS
    unmap.plink is the command file for plink and must look like this:

==================================================================
cd /tmp
> log.txt
> my.log
echo "if [ \`hostname | grep -i dcr\` ]" > unmap.sh
echo "then" >> unmap.sh
echo "   find /vmfs/volumes/ -type l | cut -d \"/\" -f4 | grep -i dcr | sort > /tmp/datastores" >> unmap.sh
echo "else" >> unmap.sh
echo "   find /vmfs/volumes/ -type l | cut -d \"/\" -f4 | grep -i wpr | sort > /tmp/datastores" >> unmap.sh
echo "fi" >> unmap.sh
echo "for ds in \`cat datastores\`; do" >> unmap.sh
echo "  echo \`esxcli hardware clock get\` \"Start unmap Datastore $ds\" >> log.txt" >> unmap.sh
echo "#  esxcli storage vmfs unmap -l \$ds -n 200" >> unmap.sh
echo "  echo \`esxcli hardware clock get\` \"Ready unmap Datastore $ds\" >> log.txt" >> unmap.sh
echo "done" >> unmap.sh
chmod 744 /tmp/unmap.sh
nohup /tmp/unmap.sh > /tmp/my.log 2>&1 &
echo $! > save_pid.txt
 

Example server input file:
==========================
Hostname,User,Password
esxi01.acme.com,root,passw
esxi02.acme.com,root,passw
 

.OUTPUTS
    Log file 

.NOTES
   XYZ

.COMPONENT

.ROLE

.FUNCTIONALITY

.VERSION
    20180530_1200

    20180530_1200
    First version
#>
 

Param (
        # The path to the server.csv (input) file
        [Parameter(Mandatory=$True,Position=1)]
        [string]$ServerCSV ="server.csv",
        # The FQDN or IP of the vCenter Server
        [string]$vcenter = "vcsa.acme.com",
        # The path to the folder for output files
        [string]$WorkingDirectory = ".",
        # File with extended logging
        [string]$logfile=""
)
 

#
# logit function to log output to the logfile AND screen
# 1st parameter = message written to logfile
# 2nd parameter = 1 - log to output and screen
# 2nd parameter, value other then 1 changes foreground color: 2=green, 3=blue, 4=red, 5=purple etc
function logit($message , $toscreen)
{
   Write-Output $message | Out-File -FilePath $logfile -Encoding "utf8"  -Append   #avoid UTF-16 output
   IF(-NOT [string]::IsNullOrWhiteSpace($toscreen)) 
   {
      if($toscreen -eq "1")
      { Write-Host $message}
      else
      { Write-Host -ForegroundColor $toscreen  $message}
   }
}
 
 
function loop_through_all_hosts()
{
    foreach ($VMhost in $ListofServers)
    {
        $VMhostName = $VMhost.Hostname
        $VMhostUser = $VMhost.User
        $VMhostPass = $VMhost.Password
        if ( $VMhostName )
        {
            logit " " 1
            logit "-------------------------------------------------------------------------" 1
            logit "Configuring host: $VMhostName" 1
            $time = date -Format "yyyy-MM-dd hh:mm:ss"
            logit "Current timestamp: $time" 1
            Try {
                Get-VMHost -Name $VMhostName | Foreach {Start-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} )}
                & "C:\Program Files (x86)\PuTTY\plink.exe" $VMhostUser@$VMhostName -pw $VMhostPass -m .\unmap.plink
            }
            Catch {
                   logit "Caught a system exception while attempting to access $VMhostName" Red
                   write-host " "
                   write-host " "
                   logit $_.Exception Red
                   continue   #next host
            }
        }
    }
}
#
#
#
#
#  MAIN starts here
#
$currentLocation = Get-Location
$today = date -Format yyyyMMdd_hhmm
$project = "Unmap Datastores"
if($logfile -eq "") {$logfile = "${OutputDirectory}\${project}_$today.log";}
write-host "Logfile: $logfile"
write-output "Unmap Datastores version: 1.0 " | Out-File -FilePath $logfile -Encoding "utf8"
logit "Date: $today"
# ----------------------------
# Check input file
if ( -not $ServerCSV)
{
    Write-Host -ForegroundColor Red "No file specified in -iLOServerCSV ."
    return
}
 
if ( -not (Test-path $ServerCSV) )
{
    Write-Host -ForegroundColor Red "File $ServerCSV does not exist."
    return
}
# ----------------------------
# Process the input file
# Read the CSV Users file
logit "reading CSV file $ServerCSV" 1
$i=0;
$ListofServers=@()
foreach($line in Get-Content $ServerCSV)
{
   if($i -eq 0 -AND $line -match "^Hostname,") {continue}  #headline not used by this script
   if($line -notmatch "^\s*#" )
   {
      $X=$line.Split(",")
   
      if($globallogin)
      {
        $ListofServers += @{Hostname=$X[0].Trim() ; User=$C.UserName ; Password=$C_password}
      }
      else
      {
         if($X.Count -lt 3)
         { write-host -ForegroundColor Red "Bad format found in CSV file - please use Syntax: Hostname,User,Password"
           write-host -ForegroundColor Red "Please Enter global used credentials or cancel to exit."
           write-host -ForegroundColor Red "Make sure there is no blank last line!!!"
           try{$Script:C = Get-Credential
              }
           catch{ write-host -ForegroundColor Red "reading credentials failed - abort"
                  exit
                }
           $C_password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($C.Password))
           $ListofServers += @{Hostname=$X[0].Trim() ; User=$C.UserName ; Password=$C_password }
           $globallogin=$True;
         }
         $ListofServers += @{Hostname=$X[0] ; User=$X[1] ; Password=$X[2]}
      }
      $i++
   }
}
logit "$($ListofServers.Hostname.Count) ESXi hosts in file $ServerCSV" 1
# Login vCenter Server
logit "vCenter Server is: $vcenter" 1
Write-Host "Provide Credentials for the vCenter Server"
try{$cred=Get-Credential
}
catch{ write-host -ForegroundColor Red "reading credentials failed - abort"
    exit
}
Connect-VIServer -Server $vcenter -Credential $cred
# loop hosts
loop_through_all_hosts
logit "### End ###" 1
#eof
