### Display Media Duration

class TrackInfo
{
    [int] $Number
    [string] $Title
    [string] $Artist
    [long] $Offset
    TrackInfo(
        [int]$num,
        [string]$tit,
        [string]$art,
        [long]$off
    )
    {
        $this.Number = $num
        $this.Title = $tit
        $this.Artist = $art
        $this.Offset = $off
    }
    [string]ToString()
    {
        return '{0} - {1} - {2}' -f $this.Number, $this.Title, $this.Artist
    }
    [string] hidden GetFramesStr() { return '{0:d2}' -f $this.GetFrames() }
    [int] hidden GetFrames()
    {
        return ($this.offset % 75)
    }
    [string] hidden GetSecondsStr() { return '{0:d2}' -f $this.GetSeconds() }
    [int] hidden GetSeconds()
    {
        return [int][math]::Floor(($this.Offset / 75)) % 60

    }
    [string] hidden GetMinutesStr() { return '{0:d2}' -f $this.GetMinutes() }
    [int] hidden GetMinutes()
    {
        return [int][math]::Floor(($this.Offset / 75 / 60))
    }
    [regex] hidden GetPattern()
    {
        $optionsTrack = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        return [regex]::new(("TRACK {0:d2}.*?PERFORMER `"(?<artist>.*?)`".*?TITLE `"(?<title>.*?)`".*?INDEX 01\s*(?<minutes>\d+):(?<seconds>\d+):(?<frames>\d+)" -f $this.Number), $optionsTrack)
    }
}
class CueContent
{
    [string]$CuePath
    [string]$AudioPath
    [string]$AlbumArtist
    [string]$Album
    [timespan]$Duration
    [TrackInfo[]]$Tracks
    CueContent(
        [string]$cue,
        [string]$audio,
        [string]$art,
        [string]$alb,
        [timespan]$dur,
        [TrackInfo[]]$tr
    )
    {
        $this.CuePath = $cue
        $this.AudioPath = $audio
        $this.AlbumArtist = $art
        $this.Album = $alb
        $this.Duration = $dur
        $this.Tracks = $tr
    }
}
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
                    $f | Get-MediaLength
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
        [Alias('FullName')]
        [string[]]
        $Path
    )
    begin
    {
        $options = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::Multiline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        $optionsTrack = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        $RegAlbumArtist = [regex]::new('^PERFORMER\s*"(.*)"', $options)
        $RegAlbumTitle = [regex]::new('^TITLE\s*"(.*)"', $options)
        $RegFile = [regex]::new('^FILE\s*"(.*)"\s*\w+', $options)
        $RegTracksStart = [regex]::new('^  TRACK', $options)

        $RegArtist = [regex]::new('PERFORMER\s*"(.*)"', $options)
        $RegIndex = [regex]::new('INDEX 01\s*(?<minutes>\d+):(?<seconds>\d+):(?<frames>\d+)', $options)
        $RegTitle = [regex]::new('TITLE\s*"(.*)"', $options)
        $trackInfos = [System.Collections.ArrayList]::new()
        $RegTrack = [regex]::new('TRACK (?<number>\d\d).*?PERFORMER "(?<artist>.*?)".*?TITLE "(?<title>.*?)".*?INDEX 01\s*(?<minutes>\d+):(?<seconds>\d+):(?<frames>\d+)', $optionsTrack)
    }
    process
    {
        foreach ($x in $Path)
        {
            $cueText = Get-Content $x -Raw
            $AlbumArtist = $RegAlbumArtist.Match($cueText).Groups[1].Value
            $AlbumTitle = $RegAlbumTitle.Match($cueText).Groups[1].Value
            $File = $RegFile.Match($cueText).Groups[1].Value
            $File = Join-Path (Split-Path $x) -ChildPath $File
            $trackMatch = $RegTracksStart.Match($cueText)
            $trackCount = 1
            $tracks = $RegTrack.Matches($cueText)
            foreach ($track in $tracks)
            {
                $sectors = [int]($track.Groups['minutes'].Value) * 60 * 75 + [int]($track.Groups['seconds'].Value) * 75 + [int]($track.Groups['frames'].Value)
                $trackInfos.Add(
                    [TrackInfo]::new(
                        $track.Groups['number'].Value,
                        $track.Groups['title'].Value,
                        $track.Groups['artist'].Value,
                        $sectors
                    ))
                | Out-Null
            }
            # while ($trackMatch.Success)
            # {
            #     $title = $RegTitle.Match($cueText, $trackMatch.Index).Groups[1].Value
            #     $artist = $RegArtist.Match($cueText, $trackMatch.Index).Groups[1].Value
            #     $Index = $RegIndex.Match($cueText, $trackMatch.Index)
            #     if (-not $Index.Success)
            #     {
            #         Write-Error "Could not parse index for track $trackCount - $title"
            #     }
            #     $sectors = [int]($index.Groups['minutes'].Value) * 60 * 75 + [int]($index.Groups['seconds'].Value) * 75 + [int]($index.Groups['frames'].Value)
            #     $trackInfos.Add(
            #         [TrackInfo]::new(
            #             $trackCount,
            #             $title,
            #             $artist,
            #             $sectors
            #         ))
            #     | Out-Null
            #     $trackMatch = $trackMatch.NextMatch()
            #     $trackCount++
            # }
        }
        [CueContent]::new(
            $x,
            $File,
            $AlbumArtist,
            $AlbumTitle,
          (Get-MediaDuration -Path $file -OnlyDuration),
            $trackInfos
        )
    }
}
function Set-TextByMatch
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Text,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Group')]
        [System.Text.RegularExpressions.Group]
        $Group,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Match')]
        [System.Text.RegularExpressions.Match]
        $Match,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Match')]
        [string]
        $GroupName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Replacement
    )
    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Match')
        {
            $Group = $Match.Groups[$GroupName]
        }
        $Text = $cueText.Remove($Group.index, $Group.Length)
        $Text = $cueText.Insert($Group.index, $Replacement)
    }
    end
    {
        $Text
    }
}
function Update-CueSheet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Path,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AudioPath,
        [Parameter(ValueFromPipelineByPropertyName)]
        [TrackInfo[]]
        $Tracks,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $Artist,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AlbumTitle
    )
    process
    {
        $any = $AudioPath -or $Tracks -or $Artist -or $AlbumTitle
        if ((-not $any) -or (-not (Test-Path $Path))) { return }
        $cueText = Get-Content $Path -Raw
        if ($Tracks)
        {
            $tracks = $tracks | Sort-Object Number -Descending
            foreach ($track in $tracks)
            {
                $reg = $track.getpattern()
                $trackMatch = $reg.Match($cuetext)
                if ($trackMatch.success)
                {
                    $cueText = Set-TextByMatch -Text $cueText -Match $trackMatch -GroupName 'frames' -Replacement $track.GetFramesStr()
                    $cueText = Set-TextByMatch -Text $cueText -Match $trackMatch -GroupName 'seconds' -Replacement $track.GetSecondsStr()
                    $cueText = Set-TextByMatch -Text $cueText -Match $trackMatch -GroupName 'minutes' -Replacement $track.GetMinutesStr()
                    $cueText = Set-TextByMatch -Text $cueText -Match $trackMatch -GroupName 'title' -Replacement $track.Title
                    $cueText = Set-TextByMatch -Text $cueText -Match $trackMatch -GroupName 'artist' -Replacement $track.Artist
                }
            }
        }
    }
}
function Get-OffsetString
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [CueContent]
        $Cue
    )
    process
    {
        $strb = [System.Text.StringBuilder]::new()
        $strb.Append($Cue.Tracks.Count) | Out-Null
        foreach ($t in $cue.Tracks)
        {
            $strb.Append('+') | Out-Null
            $strb.Append($t.Offset) | Out-Null
        }
        $strb.Append('+') | Out-Null
        $strb.Append($Cue.Duration.TotalSeconds) | Out-Null
        $strb.ToString()
    }
}
$FreeDbHello = 'script+my.host.com+powershell+1.0'
function Search-FreeDbByCue
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Path
    )
    process
    {
        $cue = Read-CueSheet $Path
        $offsets = Get-OffsetString $cue
        $uri = 'http://gnudb.gnudb.org/~cddb/cddb.cgi?cmd=discid+'
        $uri += $offsets
        $uri += "&hello={0}&proto=6" -f $FreeDbHello
        $uri
        $content = Invoke-WebRequest $uri | Select-Object -ExpandProperty Content
        if ($content -imatch 'Disc ID is (.*)')
        {
            $discid = $matches[1]
        }
        else
        {
            $discid = 1337
        }
        $uri2 = "http://gnudb.gnudb.org/~cddb/cddb.cgi?cmd=cddb+query+$discid+$offsets&hello=$FreeDbHello&proto=6"
        Invoke-WebRequest $uri2 | select -ExpandProperty content
    }
}

Search-FreeDbByCue "E:\FLACBAZA\Rips\REM\1991 - Out of Time\R.E.M. - Out of Time.cue"