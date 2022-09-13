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
    $driveLetter = [io.path]::GetPathRoot($Destination) -ireplace '\W', ''
    $id = Get-Partition -DriveLetter $driveLetter | Select-Object -ExpandProperty DiskId
    if ($id -ilike '*scsi*')
    {

        Write-Warning "Destination $Destination is listed as a local drive."
        Read-Host 'Last chance to CTRL-C out of this mess'
        Read-Host 'Sike, now is the last chance'
    }

    if ([System.Environment]::GetFolderPath('MyMusic').ToLowerInvariant().Contains($Destination.ToLowerInvariant()))
    {
        throw 'DO NOT PUT YOUR CURRENT MUSIC LIBRARY, DEKLU'
    }
    else
    {

        $logPath = Join-Path (Join-Path -Path $defLoc -ChildPath Logs) -ChildPath "Log_$([datetime]::now.ToString('yyyyMMdd_HHmmss')).log"
        $logDir = New-Item -ItemType Directory -Force -Path (Split-Path $logPath)
        Robocopy.exe /JOB:$jobPath $Destination /UNILOG:"`"$logPath`""
    }
}
function Copy-AudioBook
{
    $opticals = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 5 -and $_.Size } | Select-Object -First 1
    foreach ($optical in $opticals)
    {
        $name = $opticals.volumename -ireplace ' ', ''
        $drive = $opticals.DeviceID
        $dateName = (Get-Date -Format 'yyyyMMddHHmmss') + $name
        $day = (Get-Date -Format 'yyyyMMdd') + $name
        $direct = Join-Path "$Env:TEMP/audiobooks/" (Get-Date -Format 'yyyyMMdd')
        $f = New-Item -ItemType Directory -Path $direct -Force
        $files = Get-ChildItem $drive -File -Recurse -Filter '*.mp3' | Sort-Object BaseName
        Write-Host "Copying drive $($optical.DeviceID) ($($optical.VolumeName)) to $direct" -ForegroundColor Green
        Reset-progress -id 1
        $count = 0
        $startDate = Get-Date
        foreach ($file in $files)
        {
            $num = '{0:d4}' -f $count
            Write-ProgressPlus -id 1 -CurrentIteration $count -InputObject ($file.name) -TotalCount ($files.count) -activity 'Copying...'
            Copy-Item -Path $file.FullName -Destination (Join-Path $direct "$datename$num.mp3" )
            $count++
        }
        $endDate = Get-Date
        Write-Host "Copied $($files.count) mp3 files to $direct ($datename) in $(($endDate- $startDate).TotalSeconds) seconds" -ForegroundColor Yellow
    }
}
