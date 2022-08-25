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
    Robocopy.exe /JOB:$jobPath $Destination /UNILOG:"`"$logPath`""
}
function Copy-AudioBook
{
    $opticals = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 5 -and $_.Size } | Select-Object -First 1
    foreach ($optical in $opticals)
    {
        Write-Host "Copying drive $($optical.DeviceID) ($($optical.VolumeName))" -ForegroundColor Green
        $name = $opticals.volumename -ireplace ' ', ''
        $drive = $opticals.DeviceID
        $dateName = (Get-Date -Format 'yyyyMMddHHmmss') + $name
        $day = (Get-Date -Format 'yyyyMMdd') + $name
        $direct = "$Env:TEMP/audiobooks/$day/"
        $f = New-Item -ItemType Directory -Path $direct -Force
        $files = Get-ChildItem $drive -File -Recurse -Filter '*.mp3' | Sort-Object BaseName
        Reset-progress -id 1
        $count = 0
        foreach ($file in $files)
        {
            $num = '{0:d4}' -f $count
            Write-ProgressPlus -id 1 -CurrentIteration $count -InputObject ($file.name) -TotalCount ($files.count) -activity 'Copying...'
            Copy-Item -Path $file.FullName -Destination $direct/$datename$num.mp3
            $count++
        }
        Write-Host "Copied $($files.count) mp3 files to $direct ($datename)" -ForegroundColor Yellow
    }
}
