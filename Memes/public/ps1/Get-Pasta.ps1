function Get-Pasta {
    Get-ChildItem $PSScriptRoot/../private/cpasta -Filter *.cpasta | Get-Random | Get-Content -Raw
    Write-Host
}

Set-Alias -Name Pasta -Value Get-Pasta