Write-host
Get-ChildItem $PSScriptRoot -Filter *.txt | Get-Random | Get-Content -Raw
Write-host

