function Get-Pasta {
    Get-ChildItem $PSScriptRoot -Filter *.cpasta | Get-Random | Get-Content -Raw
    Write-Host
}

