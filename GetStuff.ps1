[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Path
)
$content = Get-Content -Path $path -Raw

$regFunc = [regex]::new('^function (?<FUNC>[\w-]*)\s', [System.Text.RegularExpressions.RegexOptions]::Multiline)
$regAlias = [regex]::new('^...-Alias (-Name )?(?<ALIAS>[\w]*)\s', [System.Text.RegularExpressions.RegexOptions]::Multiline)
$funcs = $regFunc.Matches($content)
$aliass = $regAlias.Matches($content)
$FunctionsToExport = @()
$AliasesToExport = @()

foreach ($mf in $funcs)
{
    $FunctionsToExport += $mf.Groups['FUNC'].Value.Trim()
}
foreach ($ma in $aliass)
{
    $AliasesToExport += $ma.Groups['ALIAS'].Value.Trim()
}
$pars=@{
    SingleQuote=$true
    Separator =",`n`t"
    OutputPrefix ="`nFunctionsToExport = @(`n`t"
    OutputSuffix= "`n`t)"
}
if ($FunctionsToExport)
{
    $FunctionsToExport | sort | Join-String @pars
    # "`nFunctionsToExport = @(`n" + ($FunctionsToExport | Join-String -SingleQuote -Separator ",`n") + "`n)"
}
if ($AliasesToExport)
{
    $pars.OutputPrefix=$pars.OutputPrefix -replace 'Functions','Aliases'
    $AliasesToExport | sort | Join-String @pars
    # "`nAliasesToExport = @(`n" + ($AliasesToExport | Join-String -SingleQuote - -Separator ",`n") + "`n)"
}