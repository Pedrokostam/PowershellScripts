function Get-MediaDuration
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, Position = 0)]
        [string[]]
        $Path ,
        [Parameter()]
        [Alias('NoPath')]
        [switch]
        $OnlyDuration,
        [Parameter()]
        [Alias('Seconds')]
        [switch]
        $DurationInSeconds,
        [Alias('Minutes')]
        [switch]
        $DurationInMinutes
    )
    begin
    {
        $objShell = New-Object -ComObject Shell.Application
        $LengthColumn = 27
    }
    process
    {
        $cc = $Path | Get-FileMeta -column $LengthColumn
        foreach ($c in $cc)
        {
            $len = $c.$LengthColumn
            if ($len)
            {
                $duration = [timespan]::Parse($Len)
                if ($DurationInSeconds.IsPresent)
                {
                    $duration = $duration.TotalSeconds
                }
                elseif ($DurationInMinutes.IsPresent)
                {
                    $duration = $duration.TotalMinutes
                }
                if ($OnlyDuration.IsPresent)
                {
                    $duration
                }
                else
                {
                    [PSCustomObject]@{
                        File     = $c.File
                        Duration = $duration
                    }
                }
            }
        }
    }
}

function Get-SafeFileInfo
{
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $path,
        [Parameter()]
        [string]
        $SafeValue = '[file missing]'
    )
    process
    {
        (Get-Item $path -ErrorAction SilentlyContinue -ErrorVariable nic) ?? $SafeValue
    }
}

function Read-CueSheet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]
        [Alias('Fullname', 'CuePath')]
        $Path
    )
    process
    {
        try
        {
            $cuefile = Get-Item $path -ErrorAction Stop
            if ($cuefile.Length -gt 500kb)
            {
                Write-Warning "File $($cuefile.FullName) is larger than 500kB ($([int]($cuefile.Length / 1kB))kB) and probably not a cue sheet. File has been skipped"
                return
            }
            $content = $cuefile | Get-Content -Encoding utf8 -ErrorAction stop -Raw
        }
        catch
        {
            Write-Error "Could not read contents of $cuefile"
            return
        }
        if ($null -eq $content -or $content -notmatch 'FILE' -or $content -notmatch 'TRACK' -or $content -notmatch 'TITLE' -or $content -notmatch 'PERFORMER')
        {
            Write-Verbose "$cuefile is not a cuesheet"
            return
        }
        $content = $content -split "`n"
        $isGlobal = $true
        $sheet = [CueSheet]::new()
        $track = [CueTrack]::new()
        $sheet.CueFile = $cuefile

        foreach ($Line in $content)
        {
            if ($line -match 'INDEX (?<NUMBER>\d\d) (?<MINUTES>\d\d):(?<SECONDS>\d\d):(?<FRAMES>\d\d)')
            {
                $track.Indices += [CueIndex]::new($Matches['NUMBER'], $Matches['MINUTES'], $Matches['SECONDS'], $Matches['FRAMES'])
            }
            elseif ($line -match '^\s*TRACK (?<TRACK>\d\d)')
            {
                $isGlobal = $false
                if ($track.Number -ne 0)
                {
                    $sheet.Tracks += $track
                }
                $track = [CueTrack]::new()
                $track.Number = $Matches['TRACK']
            }
            elseif ($line -match '^\s*TITLE ["|''](?<Title>.+)["|'']')
            {
                if ($isGlobal)
                {
                    $sheet.Title = $Matches['TITLE']
                }
                else
                {
                    $track.Title = $Matches['TITLE']
                }
            }
            elseif ($line -match '^\s*PERFORMER ["|''](?<PERFORMER>.+)["|'']')
            {
                if ($isGlobal)
                {
                    $sheet.Performer = $Matches['PERFORMER']
                }
                else
                {
                    $track.Performer = $Matches['PERFORMER']
                }
            }
            elseif ($line -match '^\s*FILE ["|''](?<FILE>.+)["|'']')
            {
                if ($isGlobal)
                {
                    $checkedAudioPath = Join-Path $sheet.CueFile.Directory $Matches['FILE']
                    $sheet.AudioFile = Get-SafeFileInfo $checkedAudioPath
                }
                else
                {
                    $checkedAudioPathTr = Join-Path $sheet.CueFile.Directory $Matches['FILE']
                    $track.AudioFile = Get-SafeFileInfo $checkedAudioPathTr
                }
            }
            elseif ($line -match 'REM DATE (?<DATE>\d{4})')
            {
                $sheet.DATE = $Matches['DATE']
            }
        }
        if (Test-Path $sheet.AudioFile -ErrorAction SilentlyContinue)
        {
            $sheet.Duration = Get-MediaDuration -Path $sheet.AudioFile -OnlyDuration
        }
        else
        {
            Write-Warning "Cue file $($sheet.CueFile) has a missing audio file (checked $checkedAudioPath)"
        }
        $sheet
    }
}
Set-Alias rcue Read-CueSheet

function Test-AccuripSheet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Cuesheet[]]
        $CueSheet,
        [Parameter()]
        [switch]
        $Force
    )
    begin
    {
        Write-Verbose 'Force is present - all accurip files will be overwritten'
    }
    process
    {
        foreach ($sheet in $CueSheet)
        {
            $dir = [System.IO.Path]::GetDirectoryName($sheet.CueFile)
            $pattern = [regex]::Escape([System.IO.Path]::GetFileNameWithoutExtension($sheet.CueFile))
            $accuripFile = Get-ChildItem $dir -Filter *.accurip | Where-Object BaseName -Match $pattern | Select-Object -First 1
            if (-not $accuripFile -or $Force.IsPresent)
            {
                Write-Information "Verifying accurate rip status for $($sheet.CueFile) with ARCUE"
                $accuripFile = [System.IO.Path]::ChangeExtension($sheet.CueFile, '.accurip')
                & "$Global:CueToolsFolder/CUETools.ARCUE.exe" $sheet.CueFile | Set-Content -Path $accuripFile
            }
            Read-AccuripStatusFile -Accurip $accuripFile -Cuesheet $sheet
        }
    }
}

function Convert-Wildcard
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path,
        [Parameter()]
        [switch]
        $Recurse,
        [Parameter()]
        [string]
        $Filter = '*'
    )

    if ([system.IO.File]::Exists($Path)) # normal file path
    {
        Get-Item $path
    }
    elseif ($path -match '[\*\?]' -or [System.IO.Directory]::Exists($path)) # wildcards or a folder
    {
        Get-ChildItem -Path $Path -Filter $Filter -Recurse:$Recurse.IsPresent
    }
    # else #invalid path
    # {
    #     Write-Error "$path is an invalid path"
    # }
}

function Test-Accurip
{
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string[]]
        [Alias('Fullname', 'CuePath', 'PSPath')]
        $Path = '.',
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Sheet')]
        [CueSheet[]]
        [Alias('Cue')]
        $CueSheet,
        [Parameter()]
        [Alias('Overwrite')]
        [switch]
        $Force,
        [Parameter()]
        [switch]
        $Recurse,
        [Parameter()]
        [string]
        $Filter = '*'
    )
    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Path')
        {
            $files = @()
            $params = @{
                Recurse = $Recurse.IsPresent
                Filter  = $Filter
            }

            $files = @()
            foreach ($p in $path)
            {
                $files += Convert-Wildcard $p @params
            }
            if ($files.Count -eq 0)
            {
                if ($path.Count -eq 1)
                {

                    Write-Error "$path is not a valid file"
                }
                else
                {

                    Write-Error 'No matching files for specified array'
                }
                return
            }
            foreach ($cs in $files)
            {
                $c = $cs | Read-CueSheet -ErrorAction SilentlyContinue -ErrorVariable errVar -WarningAction SilentlyContinue -WarningVariable warVar
                if ($errVar)
                {
                    $errVar | Write-Warning
                }
                if ($warVar -match 'a missing audio file')
                {
                    continue
                }
                else
                {
                    $warVar | Write-Warning
                }
                $CueSheet += $c
            }
            if ($CueSheet.Count -eq 0)
            {
                Write-Error 'No valid Cue sheets found'
                return
            }
        }
        foreach ($sheet in $CueSheet)
        {
            $dir = [System.IO.Path]::GetDirectoryName($sheet.CueFile)
            $pattern = [regex]::Escape([System.IO.Path]::GetFileNameWithoutExtension($sheet.CueFile))
            $accuripFile = Get-ChildItem $dir -Filter *.accurip | Where-Object BaseName -Match $pattern | Select-Object -First 1
            if (-not $accuripFile -or $Force.IsPresent)
            {
                Write-Information "Verifying accurate rip status for $($sheet.CueFile) with ARCUE"
                $accuripFile = [System.IO.Path]::ChangeExtension($sheet.CueFile, '.accurip')
                & "$Global:CueToolsFolder/CUETools.ARCUE.exe" $sheet.CueFile | Set-Content -Path $accuripFile
            }
            Read-AccuripStatusFile -Accurip $accuripFile -Cuesheet $sheet
        }
    }
}

function Read-AccuripStatusFile
{
    [CmdletBinding()]
    param (
        [Parameter( ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [Alias('Path', 'AccuripPath', 'PSPath', 'Fullname')]
        [string]
        $Accurip,
        [Parameter( ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [Alias('Cue')]
        [cuesheet]
        $Cuesheet,
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [string]
        $CuePath
    )
    process
    {
        $verified = $false
        $accurate = $false

        if (-not $Cuesheet -and -not $Accurip -and -not $CuePath)
        {
            Write-Error 'All input parameters are null'
            return
        }
        if (-not $Accurip -or -not (Test-Path $Accurip))
        {
            if ($Cuesheet)
            {
                $Accurip = [System.IO.Path]::ChangeExtension($Cuesheet.CueFile, '.accurip')
                if (-not (Test-Path $Accurip))
                {
                    Write-Error "Could not find accurip based on Cuesheet $($Cuesheet.CueFile)"
                    return
                }
            }
            elseif ($CuePath -and (Test-Path $CuePath))
            {
                $Accurip = [System.IO.Path]::ChangeExtension($CuePath, '.accurip')
                if (-not (Test-Path $Accurip))
                {
                    Write-Error "Could not find accurip based on Cue path $CuePath"
                    return
                }
            }
            else
            {
                if ($CuePath)
                {
                    Write-Error "Specified accurip file ($accurip) does not exist and Cue path ($CuePath) is invalid"
                }
                else
                {
                    Write-Error "Specified accurip file ($Accurip) does not exist"
                }
                return
            }
        }
        $content = Get-Content $accurip -Raw
        $noAudio = $content -match 'Error: unable to locate the audio files'
        if ($noAudio)
        {
            Write-Error "Audio file for accurip $accurip is missing "
            return
        }

        $correctedSamples = 0
        if ($content -match 'CUETools DB: corrected (?<samples>\d+)')
        {
            $correctedSamples = $Matches['samples']
        }
        $notpresent = $content -match 'disk not present in database'
        $trackListingStarted = $false
        $tracks = foreach ($line in ($content -split '\n'))
        {
            if ($line -match '\s+(?<TRACK>\d+)\s+\|\s*\(\s?\d+[\/\\]\d+\)\s(?<TwoWords>\w+ \w+)')
            {
                $trackListingStarted = $true
                [PSCustomObject]@{
                    Track   = $Matches['TRACK']
                    Status  = $Matches['TwoWords'] -eq 'Accurately ripped'
                    Context = if ($line.Length -gt 80) { $line.Substring(0, 80) }else { $line }
                }
            }
            elseif ($trackListingStarted)
            {
                break
            }
        }
        $allGood = $tracks.Status -notcontains $false -and $tracks
        if (-not $Cuesheet)
        {
            if (-not $CuePath)
            {
                $CuePath = [System.IO.Path]::ChangeExtension($accurip, '.cue')
            }
            $Cuesheet = $CuePath | Read-CueSheet
        }
        [PSCustomObject]@{
            Artist              = $Cuesheet.Performer
            Album               = $Cuesheet.Title
            'Cue Path'          = $Cuesheet.CueFile
            'Audio Path'        = $Cuesheet.GetAbsoluteAudioFilePath()
            'Duration'          = $Cuesheet.Duration.ToString('hh\:mm\:ss')
            'Accurate rip'      = $allGood
            'Verified'          = -not $notpresent
            'Corrected Samples' = $correctedSamples
            'Tracks'            = $tracks
        }
    }
}

function Format-CueToUTF8
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]
        $Path
    )
    process
    {
        foreach ($p in $path)
        {
            $fail = Get-Content -Path $p -Raw -Encodin utf8 | Test-UnicodeFailure
            if ($fail)
            {
                Write-Information "Reformatting $p"
                Rename-Item $p -NewName "$($p)_backup" -Force
                Get-Content -Path "$($p)_backup" -Encoding 'windows-1251' | Set-Content -Path $p -Encoding utf8 -Force
            }
        }
    }
}