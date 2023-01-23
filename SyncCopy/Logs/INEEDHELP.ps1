$backup = Import-Csv .\backup.csv | ForEach-Object { $_.Fullname = $_.Fullname -ireplace 'E\:\\JAWALE', 'E:\FLACBAZA\Kolekcja'; $_ }
function Get-Files
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Log
    )
    begin
    {
        $count = 0
    }
    process
    {
        $cont = Get-Content $Log
        $dir = ''
        Write-Warning "Iteration $($count)"
        $count++
        foreach ($line in $cont)
        {
            if ($line -imatch 'EXTRA Dir\s*-1\s*(.*)')
            {
                $dir = $matches[1]
            }
            elseif ($line -imatch 'EXTRA File.*\t(.*)')
            {
                $file = $matches[1]
                if ($file -imatch '.')
                {
                    "$dir$file"
                }
            }
        }
    }
}
$l = @('./Log_20220830_120142.log', './Log_20220830_120137.log', './Log_20220830_120105.log')
$killed = $l | Get-Files