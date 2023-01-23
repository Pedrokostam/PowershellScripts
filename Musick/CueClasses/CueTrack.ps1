class CueTrack
{
   #hidden [CueSheet]$Parent
    [int]$Number
    [string]$Performer
    [string]$Title
    [string]$Flags
    [string]$ISRC
    [string]$Songwriter
    [string]$Comment
    [CueIndex[]]$Indices
    [CuePostGap]$PostGap
    [CuePreGap]$PreGap
    [string]ToString()
    {
        return '{0:d2} - {1}' -f $this.Number, $this.Title
    }
}

$remKeyRgTg = 'REPLAYGAIN_TRACK_GAIN'
$remKeyRgTp = 'REPLAYGAIN_TRACK_PEAK'
$remKeyRgAg = 'REPLAYGAIN_ALBUM_GAIN'
$remKeyRgAp = 'REPLAYGAIN_ALBUM_PEAK'
$remKeyComm = 'COMMENT'
$remKeyDate = 'DATE'
$remKeyGenre = 'GENRE'
$remKeyDiscId = 'DISCID'




