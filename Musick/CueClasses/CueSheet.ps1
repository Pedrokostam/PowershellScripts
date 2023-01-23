class CueSheet
{
    #Required field
    [string] $Title
    [System.IO.FileInfo] $File

    #Optional fields
    [string] $CdTextFile
    [string] $Catalog
    [string[]] $Rem
    [string] $Performer

    #Common REM fields
    [System.Nullable[float]] $ReplayGainPeak
    [System.Nullable[float]] $ReplayGainGain
    [System.Nullable[long]] $Date
    [string] $Genre
    [string] $DiscId
    [string[]] $Comment

    #Meta
    [System.IO.FileInfo] $CueFile
    [timespan] $Duration
    [CueTrack[]] $Tracks


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