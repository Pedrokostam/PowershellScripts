function Get-LastVolumeCopySession {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $RootFolder = 'audiobooks',
        [Parameter()]
        [switch]
        $AllowEmpty
    )
    $rootPath = Join-Path $env:TEMP $RootFolder
    $newestItems = Get-ChildItem $rootPath -Directory -ErrorAction Stop | Sort-Object CreationTime -Descending
    foreach ($item in $newestItems) {
        $innerFiles = Get-ChildItem $item
        if ($innerFiles) {
            $item
            return
        }
        if ($AllowEmpty.IsPresent) {
            $item
            Write-Warning 'No items in the found session folder!'
            return
        }
        Write-Verbose "Ignored empty folder: $Item"
    }
    if ($AllowEmpty.IsPresent) {
        Write-Error "No folders in $rootPath"
    } else {

        Write-Error "No non-empty folders in $rootPath"
    }
}

Set-Alias -Name Get-LastAudiobookSession -Value Get-LastVolumeCopySession

