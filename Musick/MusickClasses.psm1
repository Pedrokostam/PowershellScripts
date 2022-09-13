class CueIndex
{
    [int]$Number
    [int]$Minutes
    [int]$Seconds
    [int]$Frames
    CueIndex(
        [int]$num,
        [int]$min,
        [int]$sec,
        [int]$fr
    )
    {
        $this.Number = $num
        $this.Minutes = $min
        $this.Seconds = $sec
        $this.Frames = $fr
    }
    [long]GetTotalFrames()
    {
        return $this.Minutes * 60 * 75 + $this.Seconds * 60 + $this.Frames
    }
    [decimal]GetTotalSeconds()
    {
        return $this.GetTotalFrames() / [decimal]75
    }
    [decimal]GetTotalMinutes()
    {
        return $this.GetTotalFrames() / [decimal](60 * 75)
    }
    [string]ToString()
    {
        return 'INDEX {0:d2} {1:d2}:{2:d2}:{3:d2}' -f $this.number, $this.minutes, $this.seconds, $this.frames
    }
}
class CueTrack
{
    [int]$Number
    [string]$Performer
    [string]$Title
    [string]$File
    [CueIndex[]]$Indices
    [bool]HasPregap() { return $this.Indices[0].Number -eq 0 }
    [string]ToString()
    {
        return '{0:d2} - {1}' -f $this.Number, $this.Title
    }
}

class CueSheet
{
    [string]$Performer
    [string]$Title
    [string]$AudioFile
    [string]$CueFile
    [int]$Date
    [CueTrack[]]$Tracks
    [timespan]$Duration
    [string]GetAbsoluteAudioFilePath()
    {
        if ([System.IO.Path]::IsPathFullyQualified($this.AudioFile))
        {
            return $this.AudioFile
        }
        else
        {
            $dir = [System.IO.Path]::GetDirectoryName($this.CueFile)
            $audio = Join-Path -Path $dir -ChildPath $this.AudioFile
            return $audio
        }
    }
}