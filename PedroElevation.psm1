function Test-Admin
{
    [CmdletBinding()]
    [Alias('Test-IsAdmin')]
    [Alias('Test-Elevated')]
    [Alias('Test-IsElevated')]
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
function Start-CommandAsAdmin
{
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Command,
        [Parameter()]
        [switch]
        $NoProfile,
        [Parameter()]
        [switch]
        $NoExit,
        [Parameter()]
        [string]
        $WorkingDirectory='.'
    )
    if (Test-Admin)
    {
        Invoke-Expression $Command
    }
    else
    {
        $comm =''
        $comm += if($NoProfile.IsPresent){'-NoProfile'}else{''}
        $com += if($NoExit.IsPresent){' -NoExit'}else{''}
        $com += " -WorkingDirectory $WorkingDirectory "
        $com += ' -ExecutionPolicy bypass -command '
        $com += $Command
        $psexe = if ($PSVersionTable.PSEdition -ieq 'Core') { 'pwsh.exe' }else { 'powershell.exe' }
        Start-Process $psexe -ArgumentList $com -Verb runAs
    }
}
function Start-ScriptAsAdmin
{
    param (
        # Parameter help description
        [Parameter()]
        [string]
        $ScriptPath,
        [Parameter()]
        [switch]
        $NoProfile,
        [Parameter()]
        [switch]
        $NoExit,
        [Parameter()]
        [string]
        $WorkingDirectory=''
    )
    if($null -eq $ScriptPath -or $ScriptPath -eq ''){
        $ScriptPath = $PSCommandPath
    }
    if (Test-Admin)
    {
        & $ScriptPath
    }
    else
    {
        $comm =''
        $comm += if($NoProfile.IsPresent){'-NoProfile'}else{''}
        $com += if($NoExit.IsPresent){' -NoExit'}else{''}
        $com += " -WorkingDirectory $WorkingDirectory "
        $com += '-ExecutionPolicy bypass -file '
        $com += $Command
        $psexe = if ($PSVersionTable.PSEdition -ieq 'Core') { 'pwsh.exe' }else { 'powershell.exe' }
        Start-Process $psexe -ArgumentList $com -Verb runAs
    }
}