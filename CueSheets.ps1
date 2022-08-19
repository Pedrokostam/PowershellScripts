function Get-CueAudioPath
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $cuePath
    )

    $fileLine = Get-Content -LiteralPath $cuePath | Where-Object { $_ -imatch '\s*FILE .* WAVE' } | Select-Object -First 1
    if (-not $fileline)
    {
        return $null
    }
    $match = [Regex]::Match($fileLine, "file\s*`"?(?<path>[^`"]*)`"?\s*wave", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $audioFile = $match.Groups['path'].Value
    if (Test-Path -LiteralPath (Join-Path (Split-Path $cuePath ) -ChildPath $audioFile))
    {
        Write-Output $audioFile
    }
    else { Write-Output $null }
}
function Compress-CUEImage
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $WorkingDirectory = $null
    )
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory))
    {
        $WorkingDirectory = [Environment]::GetFolderPath('MyMusic')
    }
    try
    {
        flac | Out-Null
    }
    catch
    {
        Write-Host 'FLAC encoder not installed. Installing...'
        while (Test-Admin)
        {
            choco install flac
        }
        else
        {
            Start-CommandAsAdmin -Command 'choco install flac' -wait
        }
    }
    try{
        flac | Out-Null
    }
    catch{
        throw 'FLAC is not installed. Aborting...'
    }
    Write-Host "Looking for CUE sheets in $WorkingDirectory..."
    $shell = New-Object -ComObject 'Shell.Application'
    $cues = Get-ChildItem -LiteralPath $WorkingDirectory -File -Recurse -Include '*.cue'
    Write-Host "Found $($cues.Count) CUE sheets. Checking...`n"
    Reset-progress
    $waveCues = foreach ($c in $cues)
    {
        $cuePath = $c | Get-CueAudioPath
        if (-not $cuePath) { continue }
        if ($cuePath -imatch '\.WAV')
        {
            @{CUE = $_ ; Audio = Join-Path -Path $folder -ChildPath $cuePath; }
        }
    }

    $waveCues = @($waveCues | Sort-Object -Property { $_.CUE.LastWriteTime } -Descending)
    if (-not $waveCues)
    {
        return 'No suitable CUE sheets detected'
    }
    else
    {
        if ($waveCues.Count -eq 1)
        {
            Write-Host "Only 1 CUE sheet suitable.`n"
        }
        else
        {
            Write-Host "$($waveCues.Count) CUE sheets suitable.`n"
        }
    }
    $convertees = Select-FromMenu -Items $waveCues -DisplayItems $waveCues.Audio -MultipleChoice
    $convertees | Write-Host
    for ($i = 0; $i -lt $convertees.Count; $i++)
    {
        $curr = $convertees[$i]
        Write-Host "Processing $($i + 1) out of $($convertees.Count)" -ForegroundColor Cyan
        $proc = New-Object -TypeName System.Diagnostics.Process
        $proc.StartInfo.RedirectStandardOutput = $false
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.FileName = 'flac.exe'
        $proc.StartInfo.Arguments = "-7 `"$($curr.Audio)`""
        $proc.Start() | Out-Null
        $proc.WaitForExit()
        Write-Host "Converted $($curr.Audio) to FLAC" -ForegroundColor Green

        $cuetext = Get-Content -Path $curr.CUE -Raw
        $oldPath = Split-Path -Leaf -Path $curr.Audio
        $newPath = [System.IO.Path]::ChangeExtension($oldPath, 'flac')

        $t = $cuetext.Replace($oldPath, $newPath)
        $t | Out-File -Force -Path $curr.CUE
        Write-Host 'Updated CUE sheet'
        $shell.NameSpace(0).ParseName($_.Audio).InvokeVerb('delete') | Out-Null
        Write-Host 'Moved WAVE file to recycle bin'
    }
}