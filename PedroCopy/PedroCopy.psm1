$defLoc = $PSScriptRoot
$jobPath = Join-Path -Path $defLoc -ChildPath SYNCMUSIC.RCJ
function Sync-Music
{
    [CmdletBinding()]
    # Parameter help description
    param(
        [Parameter(Mandatory)]
        [string]
        $Destination
    )
    $logPath = Join-Path (Join-Path -Path $defLoc -ChildPath Logs) -ChildPath "Log_$([datetime]::now.ToString('yyyyMMdd_HHmmss')).log"
    $logDir = New-Item -ItemType Directory -Force -Path (Split-Path $logPath)
    Robocopy.exe /JOB:$jobPath  $Destination /UNILOG:"`"$logPath`""
}
