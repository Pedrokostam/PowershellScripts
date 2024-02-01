function Copy-AudioBook {
    <#
    .SYNOPSIS
    Copies the mp3 file from the optical drive recursively into a temporary folder.
    .DESCRIPTION
    Copies files matching the pattern -FileFilter from a removable device. By default the devices are limited to optical media,
    but can be extended to all removables with the -AllowNonOptical switch.
    If there are multiple applicable drives, you MUST specify the -DriveLetter. If the drive letter is specified it must match an applicable drive.
    If there is only one applicable drive, the drive letter can be left unspecified.
    .OUTPUTS
    System.IO.DirectoryInfo
        The output directory.
    .PARAMETER Letter
    The letter of the drive from which the files will be copied. Can be left unspecified if there is only one applicable drive.
    If not specified and mulitple drives are present, an exception is thrown.
    .PARAMETER FileFilter
    Which files will be copied from the drive.
    .PARAMETER RootFolder
    Name of the folder that will be created in %TEMP% to store data.
    The final path will look like this %TEMP%/{RootFolder}{Data}, where Date is formatted to yyyyMMdd
    .PARAMETER AllowNonOptical
    Switch which makes it possible to copy from other removable media, not only optical drives. System drive is never available.
    #>
    [OutputType([System.IO.DirectoryInfo])]
    [CmdletBinding(PositionalBinding = $false,DefaultParameterSetName='normal')]
    param (
        [Parameter(Position = 0,ParameterSetName='normal')]
        [string]
        [Alias('DriveLetter', 'Drive')]
        $Letter,
        [Parameter(ParameterSetName='normal')]
        [Alias('Filter')]
        [ValidateNotNullOrEmpty()]
        [string]
        $FileFilter = '*.mp3',
        [Parameter(ParameterSetName='normal')]
        [switch]
        $AllowNonOptical,
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $RootFolder = 'audiobooks'
    )
    begin {
        if ($AllowNonOptical.IsPresent) {
            $opticals = @(Get-Volume | Where-Object { $_.DriveType -ne 'Fixed' -and $_.Size -gt 0 -and $_.DriveLetter -ne $env:SystemDrive[0] }  )
        } else {
            $opticals = @(Get-Volume | Where-Object { $_.DriveType -eq 'CD-ROM' -and $_.Size -gt 0 } )
        }
        $tempFolder = Join-Path $Env:TEMP $RootFolder
        [datetime]$sessionDate = Get-Date
        #if it is the begininng of a new day, check if there was a session near the end of the previous day.
        if ($sessionStartDate.Hour -le 2) {
            $yesterday = $sessionDate.Subtract([timespan]::FromDays(1))
            $yesterdaySessionFolderName = $yesterday.ToString('yyyyMMdd')
            $oldFold = Get-ChildItem -Path $tempFolder -Directory -Filter $yesterdaySessionFolderName
            if ($oldFold -and $oldFold.CreationTime.Hour -gt 22) {
                $sessionDate = $yesterday
                Write-Verbose "Reusing folder $($oldFold.Name) from previous session"
            }
        }
        $sessionOutputFolderName = $sessionDate.ToString('yyyyMMdd')
        $outputPath = Join-Path $tempFolder $sessionOutputFolderName
    }
    process {
        [datetime]$driveDate = Get-Date
        $noLetter = [string]::IsNullOrWhiteSpace($Letter)
        $match = $opticals | Where-Object DriveLetter -EQ $Letter
        if ($opticals.Count -gt 1 -and $noLetter) {
            throw 'Multiple optical disk inserted. Specify drive letter'
        }
        if (-not $opticals) {
            throw 'No optical media present'
        }
        if ($opticals.Count -eq 1 -and $noLetter) {
            $drive = $opticals[0]
            Write-Verbose "Using the only available optical media at $($drive.DriveLetter):"
        } else {
            $match = $opticals | Where-Object DriveLetter -EQ $Letter
            if ($match) {
                $drive = $match
                Write-Verbose "Using specified optical media at $($drive.DriveLetter):"
            } else {
                throw "No optical media in driveLetter $letter`:"
            }
        }
        $name = $drive.FileSystemLabel -ireplace ' ', '_'
        $driveLetter = $drive.DriveLetter
        $outputDirectory = New-Item -ItemType Directory -Path $outputPath -Force
        $files = Get-ChildItem "$($driveLetter):" -File -Recurse -Filter $FileFilter | Sort-Object BaseName
        Write-Verbose "Copying contents of drive $driveLetter`: ($name) to `"$outputDirectory`""
        Reset-Progress -Id 1
        $count = 0
        [datetime]$copyingStartDate = Get-Date
        foreach ($file in $files) {
            $newName = '{0:yyyy_MM_dd_HH_mm_ss}_{1:d4}{2}' -f $driveDate, $count, $file.Extension
            $outputFilePath = Join-Path $outputDirectory $newName
            $statusObject = '{0} -> {1}' -f $file.name, $newName
            Write-ProgressPlus -Id 1 -CurrentIteration $count -InputObject $statusObject -TotalCount ($files.count) -Activity 'Copying...'
            Copy-Item -Path $file.FullName -Destination $outputFilePath
            $count++
        }
        [datetime]$copyingEndDate = Get-Date
        [timespan]$dateDiff = $copyingEndDate - $copyingStartDate
        $duration = $dateDiff.TotalSeconds
        $durationString = $duration.ToString('f2')
        Write-Verbose "Copied $($files.count) mp3 files to `"$outputDirectory`" in $durationString seconds"
        $outputDirectory
    }
}



function Get-LastAudiobookSession {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $RootFolder = 'audiobooks',
        [Parameter()]
        [switch]
        $AllowEmpty
    )
    $rootPath = Join-Path $env:TEMP $RootFolder
    $newestItems = Get-ChildItem $rootPath -Directory  -ErrorAction Stop| Sort-Object CreationTime -Descending
    foreach ($item in $newestItems) {
        $innerFiles = Get-ChildItem $item
        if ($innerFiles) {
            $item
            return
        }
        if ($AllowEmpty.IsPresent) {
            $item
            Write-Warning 'No items in the found session folder!'
            return
        }
        Write-Verbose "Ignored empty folder: $Item"
    }
    if ($AllowEmpty.IsPresent) {
        Write-Error "No folders in $rootPath"
    }    else{

        Write-Error "No non-empty folders in $rootPath"
    }
}

