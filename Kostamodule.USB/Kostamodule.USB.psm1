function Show-USBDrives {
    Get-Volume | Where-Object DriveType -EQ 'Removable'
}

function Format-USBDrive {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Letter = $null,
        [Parameter()]
        [ValidateSet('exFAT', 'FAT', 'FAT32', 'NTFS', 'ReFS')]
        [string]
        $FileSystem = $null,
        [Parameter()]
        [string]
        $Name = $null,
        [Parameter()]
        [switch]
        $Force
    )
    $removables = Get-Volume | Where-Object DriveType -EQ 'Removable'
    # if (-not $removables)
    # {
    #     # Get-Volume return translated drivetype. I dunno if the translation is always to English, or to system language
    #     # So I also use the older Get-CimInstance which does not translate it (removable is '2')
    #     $removables = Get-CimInstance Win32_LogicalDisk | Where-Object DriveType -EQ '2'
    # }
    if (-not $removables) {
        Write-Error 'No removable volumes detected!'
        return
    }
    $removables = @($removables)
    $seletected_volume = $null
    if ($removables.count -gt 1) {
        if (-not $Letter) {
            Write-Host 'Detected follwoing removable volumes:'
            $removables | Out-String | Write-Host
            Write-Error 'Multiple removable volumes detected. Specify driveLetter letter.'
            return
        }
        $seletected_volume = $removables | Where-Object DriveLetter -EQ $Letter | Select-Object -First 1
        if (-not $seletected_volume) {
            Write-Error 'Specified volume does not exist!'
            return
        }
    } else {
        $seletected_volume = $removables | Select-Object -First 1
    }
    if (-not $FileSystem) {
        $FileSystem = $seletected_volume.FileSystemType
    }
    if (-not $Name) {
        $Name = $seletected_volume.FriendlyName
    }
    $N = if ($name) { $name }else { '$Null' }
    $seletected_volume | Out-String | Write-Host
    if ($force.IsPresent) {
        Write-Warning "Formatting this volume to $FileSystem and name $n"
    } else {
        Read-Host "Are you sure you want to format this volume to $FileSystem and name $n? Press CTRL-C to abort, enter to continue"
    }
    $seletected_volume | Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $Name
}

