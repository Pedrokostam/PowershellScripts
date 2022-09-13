# ipmo Pedrosia.psd1
# Start-ScriptAsAdmin -NoExit

function Get-UnixPath
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'Fullname')]
        [string[]]
        $WindowsPath
    )
    process
    {
        foreach ($element in $WindowsPath)
        {
            $original = $element
            if ($element -match '(?<Drive>\w+):[\\\/]')
            {
                $element = $element.Replace($Matches[0], "/mnt/$($Matches['Drive'].ToLower())/")
            }
            if ($element -notmatch '$[''"].*[''"]^')
            {
                $element = '"{0}"' -f $element
            }
            [PSCustomObject]@{
                Path     = $original
                UnixPath = $element -replace '\\', '/'
            }
        }
    }
}

function Test-File
{
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Fullname')]
        [string[]]
        $Path
    )
    begin
    {
        where.exe wsl /Q | Out-Null
        if ($LASTEXITCODE)
        {
            Write-Error "WSL could not be found. Cannot use 'file' to test files..."
            break
        }
    }
    process
    {
        $Path | Get-UnixPath -PipelineVariable file | ForEach-Object { wsl file $_.UnixPath --brief } | ForEach-Object {
            [PSCustomObject]@{
                Path   = Get-Item $file.Path | Select-Object -ExpandProperty Fullname -First 1
                Result = $_
            } }
    }
}
Get-ChildItem -Recurse | Test-File