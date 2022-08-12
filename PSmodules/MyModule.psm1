#robocopy /JOB:SYNCMUSIC F:\Dzwiek\MUZYKA\FLACBAZA


function ConvertTo-Int
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Value,
        [int]
        $Default = 0
    )
    if ($Value -is [string])
    {
        $Value = $Value -ireplace '[\D]', ''
        $number = -1
        if ([int]::TryParse($Value, [ref]$number))
        {
            Write-Output $number
        }
        else
        {
            Write-Output $Default
        }
    }
    else
    {
        try
        {
            Write-Output [int]$value
        }
        catch
        {
            Write-Output $Default
        }

    }
}
function Select-FromMenu
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]
        $Items,
        [string[]]
        $DisplayItems,
        [string]
        $ItemName,
        [Switch]
        $MultipleChoice

    )
    if (-not $DisplayItems) { $DisplayItems = $Items }
    $ItemName = if ([string]::IsNullOrWhiteSpace($header)) { 'item' }

    $i = 0
    $DisplayItems | ForEach-Object { Write-Host "$($i) - $($_)"; $i += 1 }
    $selection = -1
    $indices = 0
    do
    {
        if ($MultipleChoice)
        {
            $selection = Read-Host "`nSelect $($ItemName)s. You can use ranges, or sequences of indices"
        }
        else
        {
            $selection = Read-Host "`nSelect one of $($ItemName)s"
        }
        $indices = 0
        if ($selection -imatch '\d?(\.\.|-)\d?')
        {
            $split = $selection -isplit '(\.\.|-)'
            $start = $split[0] | ConvertTo-Int
            $end = $split[-1] | ConvertTo-Int -Default ($DisplayItems.Count - 1)
            $indices = $start..$end
        }
        elseif ($selection.Trim() -eq '' -and $DisplayItems.Count -gt 0)
        {
            $indices = 0..($DisplayItems.Count - 1)
        }
        else
        {
            $indices = $selection | ConvertTo-Int -Default (-1)
            if ($indices -lt 0 -or $indices -ge $DisplayItems.Count)
            {
                Write-Host "$($indices) is out of range."
                $indices = -1
            }
        }
    }until ($indices.Count -gt 1 -or $indices -ge 0)
    Write-Output $Items[$indices]
}

function Confirm-ElevatedShell
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $NewStart,
        [switch]
        $Command,
        [switch]
        $Script
    )

    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin)
    {
        # Create a new process object that starts PowerShell
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo 'PowerShell';
        $isScript = $Script.IsPresent -or (-not $Command.IsPresent -and [System.IO.Path]::GetExtension($NewStart) -imatch '\.ps')
        # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
        #$newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
        if ($isScript)
        {
            $newProcess.Arguments = "-Command `" { cd '$($pwd)'; & $($NewStart) }`""
        }
        else
        {
            $newProcess.Arguments = "-Command `" { cd '$($pwd)'; $($NewStart) }`""
        }

        # Indicate that the process should be elevated
        $newProcess.Verb = 'runAs';
        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    }
    #exit
}
function Resolve-Bool
{
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [string] $A
    )
    Write-Output $A -imatch '(1|true|yes|enabled|ja|da|tak|jak najbardziej|jeszcze jak|zgoda|dawaj|affirmative|let''s dance|graj muzyko|ehe)'
}
function Resolve-Int
{
    param(
        [Parameter(ValueFromPipeline)]
        [string] $A,
        [int] $DefaultValue = -1
    )
    $intstring = $A -ireplace '[^0-9,\.+-]', ''
    $returnedInt = $DefaultValue
    if ([int]::TryParse($intstring, [ref]$returnedInt))
    {
        Write-Output $returnedInt
    }
    else
    {
        Write-Output $DefaultValue
    }
}



