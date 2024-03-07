function Copy-RemovableVolume {
    <#
    .SYNOPSIS
    Copies files from a drive recursively into a temporary folder.
    .DESCRIPTION
    Copies files matching the pattern -FileFilter from a removable device. By default the devices are limited to optical media,
    but can be extended to all removables with the -AllowNonOptical switch.
    If there are multiple applicable drives, you MUST specify the -DriveLetter. If the drive letter is specified it must match an applicable drive.
    If there is only one applicable drive, the drive letter can be left unspecified.
    .OUTPUTS
    System.IO.DirectoryInfo
        The output directory.
    .PARAMETER Letter
    The letter of the drive from which the files will be copied. Values '*' matches any drive and is the default value.
    If not specified and mulitple drives are applicable, an exception is thrown.
    .PARAMETER FileFilter
    Which files will be copied from the drive.
    .PARAMETER RootFolder
    Name of the folder that will be created in %TEMP% to store data.
    The final path will look like this %TEMP%/{RootFolder}{Data}, where Date is formatted to yyyyMMdd
    .PARAMETER AllowNonOptical
    Switch which makes it possible to copy from other removable media, not only optical drives.
    #>
    [OutputType([System.IO.DirectoryInfo])]
    [CmdletBinding(PositionalBinding = $true, DefaultParameterSetName = 'normal')]
    param (
        [Parameter(Position = 0, ParameterSetName = 'normal')]
        [string]
        [Alias('DriveLetter', 'Drive')]
        $Letter = '*',
        [Parameter(ParameterSetName = 'normal')]
        [Alias('Filter')]
        [ValidateNotNullOrEmpty()]
        [string]
        $FileFilter = '*.mp3',
        [Parameter(ParameterSetName = 'normal')]
        [switch]
        $AllowNonOptical,
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $RootFolder = 'audiobooks'
    )
    begin {
        $letter = $letter.Substring(0, 1)
        $allowedDriveTypes = @('CD-ROM')
        if ($AllowNonOptical.IsPresent) {
            $allowedDriveTypes += 'Removable'
        }
        Write-host "File filter is $FileFilter"
        Write-Host "Looking for non-empty drives of type: $($allowedDriveTypes -join ', ') matching the following drive letter $Letter"
        $repetitionCount = 3
        while ($true) {
            $drives = Get-Volume | Where-Object { $_.DriveType -in $allowedDriveTypes -and $_.DriveLetter -ne $env:SystemDrive[0] -and $_.DriveLetter -like $Letter }
            $drives = $drives | Where-Object { Test-Path "$($_.DriveLetter):" }
            if ($drives.count -eq 0) {
                if ($repetitionCount -eq 0) {
                    Write-Error 'No matching non-empty drive detected. Aborting' -ErrorAction Stop
                }
                Write-Host "No matching non-empty drive detected. Retrying in 5 seconds ($repetitionCount retries remaining)"
                $repetitionCount--
                Start-Sleep -Seconds 5
            } elseif ($drives.count -gt 1) {
                Write-Error "Multiple matching drives detected ($($drives.DriveLetter -join ', '))" -ErrorAction Stop
            } else {
                $drive = $drives[0]
                Write-Host "Using drive $($drive.DriveLetter)"
                break
            }
        }
        $tempFolder = Join-Path $Env:TEMP $RootFolder
        [datetime]$sessionDate = Get-SessionDate
        $sessionOutputFolderName = $sessionDate.ToString('yyyyMMdd')
        $outputPath = Join-Path $tempFolder $sessionOutputFolderName
    }
    process {
        [datetime]$driveDate = Get-Date
        $name = $drive.FileSystemLabel -ireplace ' ', '_'
        $driveLetter = $drive.DriveLetter
        $outputDirectory = New-Item -ItemType Directory -Path $outputPath -Force
        if (-not (Test-Path "$driveLetter`:")) {
            Write-Error "Drive $driveLetter`: is not available" -ErrorAction Stop
        }
        $files = Get-ChildItem "$driveLetter`:" -File -Recurse | Sort-Object BaseName
        $fileGroups = $Files | Group-Object -Property Extension
        Write-Host "Drive $driveletter contains $($files.count) files"
        foreach ($group in $fileGroups) {
            $msg = "  $($group.Count) $($group.Name) files"
            if ($group.Name -like $FileFilter) {
                $msg += ' (matches file filter)'
            }
            Write-Host $msg
        }
        $files = $files | Where-Object { $_.Extension -like $FileFilter }
        if ($files.count -eq 0) {
            Write-Error "No files match the filter ($filefilter)." -ErrorAction Stop
        }
        Write-Host "$($files.count) files will be copied"
        Write-Host "Copying contents of drive $driveLetter`: ($name) to `"$outputDirectory`""
        Reset-ProgressPlus -Id 2137
        $count = 0
        [datetime]$copyingStartDate = Get-Date
        $progressData = @{
            ID         = 2137
            TotalCount = $files.Count
            Activity   = "Copying $driveLetter`:..."
        }
        foreach ($file in $files) {
            $newName = '{0:yyyy_MM_dd_HH_mm_ss}_{1:d4}{2}' -f $driveDate, $count, $file.Extension
            $outputFilePath = Join-Path $outputDirectory $newName
            $statusObject = '{0} -> {1}' -f $file.name, $newName
            Write-ProgressPlus -Id 2137 -InputObject $statusObject @progressData
            Copy-Item -Path $file.FullName -Destination $outputFilePath
            $count++
        }
        Reset-ProgressPlus -Id 2137
        [datetime]$copyingEndDate = Get-Date
        [timespan]$dateDiff = $copyingEndDate - $copyingStartDate
        $duration = $dateDiff.TotalSeconds
        $durationString = $duration.ToString('f2')
        Write-Host "Copied $($files.count) files to `"$outputDirectory`" in $durationString seconds"
        $outputDirectory
    }
}

Set-Alias -Name Copy-Audiobook -Value Copy-RemovableVolume

