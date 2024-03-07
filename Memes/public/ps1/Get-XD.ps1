function Get-XD {
    [CmdletBinding()]
    param (
    )
    $xd = @(
        '                                                   ',
        '                                                   ',
        '                              DDDDDDDDDDDDD        ',
        '                              D::::::::::::DDD     ',
        '                              D:::::::::::::::DD   ',
        '                              DDD:::::DDDDD:::::D  ',
        '          xxxxxxx      xxxxxxx  D:::::D    D:::::D ',
        '           x:::::x    x:::::x   D:::::D     D:::::D',
        '            x:::::x  x:::::x    D:::::D     D:::::D',
        '             x:::::xx:::::x     D:::::D     D:::::D',
        '              x::::::::::x      D:::::D     D:::::D',
        '               x::::::::x       D:::::D     D:::::D',
        '               x::::::::x       D:::::D     D:::::D',
        '              x::::::::::x      D:::::D    D:::::D ',
        '             x:::::xx:::::x   DDD:::::DDDDD:::::D  ',
        '            x:::::x  x:::::x  D:::::::::::::::DD   ',
        '           x:::::x    x:::::x D::::::::::::DDD     ',
        '          xxxxxxx      xxxxxxxDDDDDDDDDDDDD        ',
        '                                                   ',
        '                                                   '
    )
    $xd | Write-Host
}

Set-Alias -Name XD -Value Get-XD