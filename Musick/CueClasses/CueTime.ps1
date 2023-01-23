class CueTime
{
    [int]$Minutes
    [int]$Seconds
    [int]$Frames
    CueTime(
        [int]$min,
        [int]$sec,
        [int]$fr
    )
    {
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
class CueIndex :CueTime
{
    [int]$Number
    CueIndex(
        [int]$num,
        [int]$min,
        [int]$sec,
        [int]$fr
    ) : base($min, $sec, $fr)
    {
        $this.Number = $num
    }
    [string]ToString()
    {
        return 'INDEX {0:d2} {1}' -f $this.number, [CueTime]$this.ToString()
    }
}
class CuePreGap :CueTime
{
    CuePreGap(
        [int]$min,
        [int]$sec,
        [int]$fr
    ) : base($min, $sec, $fr)
    {    }
    CuePreGap() : base(0, 0, 0)
    {    }
    [string]ToString()
    {
        return 'PREGAP {0}' -f [CueTime]$this.ToString()
    }
}
class CuePostGap :CueTime
{
    CuePostGap(
        [int]$min,
        [int]$sec,
        [int]$fr
    ) : base($min, $sec, $fr)
    {    }
    CuePostGap() : base(0, 0, 0)
    {    }
    [string]ToString()
    {
        return 'POSTGAP {0}' -f [CueTime]$this.ToString()
    }
}