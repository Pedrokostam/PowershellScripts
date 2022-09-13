function Get-MediaDuration
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [SupportsWildcards()]
        [string[]]
        $Path = '.',
        [Parameter()]
        [Alias('NoPath')]
        [switch]
        $OnlyDuration,
        [Parameter()]
        [Alias('Seconds')]
        [switch]
        $DurationInSeconds
    )
    begin
    {
        $objShell = New-Object -ComObject Shell.Application
        $LengthColumn = 27
    }
    process
    {
        foreach ($s in $Path)
        {
            $p = Get-ChildItem $s
            foreach ($f in $p)
            {
                if ($f -is [System.IO.DirectoryInfo])
                {
                    $f | Get-MediaDuration
                }
                else
                {
                    $objFolder = $objShell.Namespace($f.DirectoryName)
                    $objFile = $objFolder.ParseName($f.Name)
                    $Len = $objFolder.GetDetailsOf($objFile, $LengthColumn)
                    if ($Len)
                    {
                        $duration = [timespan]::Parse($Len)
                        if ($DurationInSeconds.IsPresent)
                        {
                            $duration = $duration.TotalSeconds
                        }
                        if ($OnlyDuration.IsPresent)
                        {
                            $duration
                        }
                        else
                        {
                            [PSCustomObject]@{
                                File     = $f.FullName
                                Duration = [timespan]::Parse($Len)
                            }
                        }
                    }
                }
            }
        }
    }
}

function Read-CueSheet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]
        [Alias('Fullname', 'PSPath', 'Path')]
        $CuePath
    )
    process
    {
        foreach ($path in $CuePath)
        {
            $content = Get-Content $path -Encoding utf8
            $isGlobal = $true
            $sheet = [CueSheet]::new()
            $track = [CueTrack]::new()
            $sheet.CueFile = $path

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
                        $sheet.AudioFile = $Matches['FILE']
                    }
                    else
                    {
                        $track.AudioFile = $Matches['FILE']
                    }
                }
                elseif ($line -match 'REM DATE (?<DATE>\d{4})')
                {
                    $sheet.DATE = $Matches['DATE']
                }
            }
            $sheet.Duration = Get-MediaDuration -Path $sheet.GetAbsoluteAudioFilePath() -OnlyDuration
            $sheet
        }
    }
}
Set-Alias rcue Read-CueSheet
function Test-Accurip
{
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string[]]
        [Alias('Fullname', 'PSPath')]
        $CuePath,
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Sheet')]
        [CueSheet[]]
        [Alias('Cue')]
        $CueSheet
    )
    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Path')
        {
            $CueSheet = $CuePath | Read-CueSheet
        }
        foreach ($sheet in $CueSheet)
        {
            $dir = [System.IO.Path]::GetDirectoryName($sheet.CueFile)
            $pattern = [regex]::Escape([System.IO.Path]::GetFileNameWithoutExtension($sheet.CueFile))
            $accuripFile = Get-ChildItem $dir -Filter *.accurip | Where-Object BaseName -Match $pattern | Select-Object -First 1
            if (-not $accuripFile)
            {
                Write-Information "Verifying accurate rip status for $($sheet.CueFile)"
                $accuripFile = [System.IO.Path]::ChangeExtension($sheet.CueFile, '.accurip')
                & "$Global:CueToolsFolder/CUETools.ARCUE.exe" $sheet.CueFile | Set-Content -Path $accuripFile
            }
            Read-AccuripStatusFile $accuripFile
        }
    }

}

function Read-AccuripStatusFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'PSPath', 'InputObject', 'Fullname')]
        [string[]]
        $Paths
    )
    process
    {
        foreach ($accurip in $Paths)
        {
            $content = Get-Content $accurip -Raw
            $correctedSamples = 0
            if ($content -match 'CUETools DB: corrected (?<samples>\d+)')
            {
                $correctedSamples = $Matches['samples']
            }
            $notpresent = $content -match 'disk not present in database'
            $trackListingStarted = $false
            $tracks = foreach ($line in ($content -split '\n'))
            {
                if ($line -match '\s+(?<TRACK>\d+)\s+\|\s*\(\d+[\/\\]\d+\)\s(?<TwoWords>\w+ \w+)')
                {
                    $trackListingStarted = $true
                    [PSCustomObject]@{
                        Track  = $Matches['TRACK']
                        Status = $Matches['TwoWords'] -eq 'Accurately ripped'
                        Context = if($line.Length -gt 80){$line.Substring(0,80)}else{$line}
                    }
                }
                elseif ($trackListingStarted)
                {
                    break
                }
            }
            $allGood = $tracks.Status -notcontains $false
            $cue = [System.IO.Path]::ChangeExtension($accurip, '.cue')
            $cue = $cue | Read-CueSheet
            [PSCustomObject]@{
                Artist              = $cue.Performer
                Album               = $cue.Title
                'Cue Path'          = $cue.CueFile
                'Audio Path'        = $cue.GetAbsoluteAudioFilePath()
                'Duration'          = $cue.Duration.ToString('hh\:mm\:ss')
                'Accurate rip'      = $allGood
                'Verified'          = -not $notpresent
                'Corrected Samples' = $correctedSamples
                'Tracks'            = $tracks
            }
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