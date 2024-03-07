function Get-RemovableDrives {
    Get-Volume | Where-Object DriveType -EQ 'Removable'
}

Set-Alias -Name Get-UsbDrives -Value Get-RemovableDrives

