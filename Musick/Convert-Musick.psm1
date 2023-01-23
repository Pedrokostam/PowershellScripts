function Convert-Flac
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'Fullname')]
        [string[]]
        $CuePath
    )
    process
    {
        foreach ($path in $CuePath)
        {
            $cue = $path | Read-CueSheet
            flac.exe
        }
    }
}