## #requires -Version 7.3
$script:KMAVS_AvlPath = $null
$script:KMAVS_Libs = 'Avl.Net.dll', 'Avl.Net.TS.dll', 'Avl.Net.Amr.dll'
function InitLib
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Version = '*'
    )
    $key = [System.Environment]::GetEnvironmentVariables().Keys | Where-Object { $_ -like "AVL_PATH*$Version*" } | Sort-Object -Descending | Select-Object -First 1
    $script:KMAVS_AvlPath = [System.Environment]::GetEnvironmentVariable($key);
    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.location -like "*$script:KMAVS_AvlPath*" }
    $loaded
    foreach ($lib in $script:KMAVS_Libs)
    {
        if ($loaded | Where-Object { $_.Location -like "*$lib*" })
        {
            Write-Verbose "$lib already loaded"
        }
        else
        {
            $pa = Join-Path $KMAVS_AvlPath "\bin\x64\$lib"
            Write-Verbose "Loading $pa"
            Add-Type -Path $pa
        }
    }
}
Initlib -verbose

function Get-AvailableLicenses
{
    $old = $FormatEnumerationLimit
    $FormatEnumerationLimit = 8
    $list = New-Object -type System.Collections.Generic.List[AvlNet.License]
    [AvlNet.AVL]::GetAvailableLicenses($list)
    $list | ForEach-Object {
        [PSCustomObject]@{
            Storage      = $_.Storage
            LicenseTypes = ($_.LicenseTypes | sort)
            Version      = $_.Version
            ValidUntil   = if ($_.ValidUntil)
            {
                Get-Date -UnixTimeSeconds $_.ValidUntil
            }
            else { 'N/A' }
            Name         = $_.Name
            Organization = $_.Organization
            ComputerID   = $_.ComputerID.Value
        }
        $_.Dispose() | Out-Null
    }
    $FormatEnumerationLimit=$old
}
function Get-ComputerID
{
    [string]$id=''
    [AvlNet.AVL]::GetComputerID([ref]$id)
    $id
}
function Get-ThreadLimitInfo
{
    [System.Nullable[int]]$threadLimit=-1
    $list = New-Object -type System.Collections.Generic.List[string]
    [AvlNet.AVL]::GetThreadLimitInfo([ref]$threadLimit,$list)
    $threadLimit ?? 'No limit'
    $list
}