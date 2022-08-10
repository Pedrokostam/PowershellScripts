#robocopy /JOB:SYNCMUSIC F:\Dzwiek\MUZYKA\FLACBAZA
Function Write-InformationColored
{
    <#
    .SYNOPSIS
        Writes messages to the information stream, optionally with
        color when written to the host.
    .DESCRIPTION
        An alternative to Write-Host which will write to the information stream
        and the host (optionally in colors specified) but will honor the
        $InformationPreference of the calling context.
        In PowerShell 5.0+ Write-Host calls through to Write-Information but
        will _always_ treats $InformationPreference as 'Continue', so the caller
        cannot use other options to the preference variable as intended.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object]$MessageData,
        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor, # Make sure we use the current colours by default
        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [Switch]$NoNewline
    )

    $msg = [System.Management.Automation.HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }

    Write-Information $msg
}

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

function Get-CueAudioPath
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $cuePath
    )

    $fileLine = Get-Content -LiteralPath $cuePath | Where-Object { $_ -imatch '\s*FILE .* WAVE' } | Select-Object -First 1
    if (-not $fileline)
    {
        return $null
    }
    $match = [Regex]::Match($fileLine, "file\s*`"?(?<path>[^`"]*)`"?\s*wave", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $audioFile = $match.Groups['path'].Value
    if (Test-Path -LiteralPath (Join-Path (Split-Path $cuePath ) -ChildPath $audioFile))
    {
        Write-Output $audioFile
    }
    else { Write-Output $null }
}
function Compress-CUEImage
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]
        $WorkingDirectory = $null
    )
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory))
    {
        $WorkingDirectory = [Environment]::GetFolderPath('MyMusic')
    }
    try
    {
        flac | Out-Null
    }
    catch
    {
        Write-Host 'FLAC encoder not installed. Installing...'
        Confirm-ElevatedShell "`"cd $($PWD);Compress-CUEImage`"" -Command
        choco install flac
    }
    Write-Host "Looking for CUE sheets in $WorkingDirectory..."
    $shell = New-Object -ComObject 'Shell.Application'
    $cues = Get-ChildItem -LiteralPath $WorkingDirectory -File -Recurse -Include '*.cue'
    Write-Host "Found $($cues.Count) CUE sheets. Checking...`n"
    for ($i = 0; $i -lt $array.Count; $i++)
    {
        { ##########
        }
        $waveCues = $cues | ForEach-Object {
            $cuePath = $_ | Get-CueAudioPath
            if (-not $cuePath) { return }
            $folder = Split-Path -Path $_
            if (-not ($cuePath -imatch '\.WAV'))
            {
                return
            }
            else
            {
                return @{CUE = $_ ; Audio = Join-Path -Path $folder -ChildPath $cuePath; }
            }

        }
        $waveCues = @($waveCues | Sort-Object -Property { $_.CUE.LastWriteTime } -Descending)
        if (-not $waveCues)
        {
            return 'No suitable CUE sheets detected'
        }
        else
        {
            if ($waveCues.Count -eq 1)
            {
                Write-Host "Only 1 CUE sheet suitable.`n"
            }
            else
            {
                Write-Host "$($waveCues.Count) CUE sheets suitable.`n"
            }
        }
        $convertees = Select-FromMenu -Items $waveCues -DisplayItems $waveCues.Audio -MultipleChoice
        $convertees | Write-Host
        for ($i = 0; $i -lt $convertees.Count; $i++)
        {
            $curr = $convertees[$i]
            Write-Host "Processing $($i + 1) out of $($convertees.Count)" -ForegroundColor Cyan
            $proc = New-Object -TypeName System.Diagnostics.Process
            $proc.StartInfo.RedirectStandardOutput = $false
            $proc.StartInfo.UseShellExecute = $false
            $proc.StartInfo.FileName = 'flac.exe'
            $proc.StartInfo.Arguments = "-7 `"$($curr.Audio)`""
            $proc.Start() | Out-Null
            $proc.WaitForExit()
            Write-Host "Converted $($curr.Audio) to FLAC" -ForegroundColor Green

            $cuetext = Get-Content -Path $curr.CUE -Raw
            $oldPath = Split-Path -Leaf -Path $curr.Audio
            $newPath = [System.IO.Path]::ChangeExtension($oldPath, 'flac')

            $t = $cuetext.Replace($oldPath, $newPath)
            $t | Out-File -Force -Path $curr.CUE
            Write-Host 'Updated CUE sheet'
            $shell.NameSpace(0).ParseName($_.Audio).InvokeVerb('delete') | Out-Null
            Write-Host 'Moved WAVE file to recycle bin'
        }
    }
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
function Limit-Object
{
    <#
    .SYNOPSIS
    Checks if the input objects fits inside the specified range. The returned object is coerced to the range.
    .PARAMETER InputObject
    An object or collection of objects that have to be limited to the range
    .PARAMETER Minimum
    The lower bound of the range. If Minimum is larger than Maximum they are swapped with a warning. Null value indicates no lower bound
    .PARAMETER Maximum
    The upper bound of the range. If Maximum is smaller than Minimum they are swapped with a warning. Null value indicates no upper bound
    .EXAMPLE
    Limit-Object 5 8 -InputObject 1,2,3,4,5,6,7,8,9
    5, 5, 5, 5, 5, 6, 7, 8, 8
    .EXAMPLE
    1..1000 Limit-Object 200 300
    Numbers from 200 to 300
    .EXAMPLE
    1..1000 | Limit-Object 500 100
    Numbers from 100 to 500, even though the range was specififed incorrectly
    .EXAMPLE
    -1000..1000 | Limit-Object -max 100
    Numbers from -1000 to 100
    .EXAMPLE
    -1000..1000 | Limit-Object $null 100
    Numbers from -1000 to 100
    #>
    [CmdletBinding()]
    param
    (
        [Alias('Min')]
        [Parameter( Position = 0)]
        $Minimum = $null,
        [Alias('Max')]
        [Parameter( Position = 1)]
        $Maximum = $null,
        [Parameter(ValueFromPipeline, Mandatory)]
        [object[]] $InputObject
    )
    begin
    {
        if ($null -eq $Maximum -and $null -eq $Minimum) { Write-Warning 'Both bounds are set to null, no limiting will be done.' }
        elseif ($null -ne $Maximum -and $null -ne $Minimum)
        {
            if ($Minimum -eq $Maximum) { Write-Warning 'The limiting range is zero, as minimum equals to maximum.' }
            elseif ($Minimum -gt $Maximum)
            {
                Write-Warning 'Specified Maximum is larger than Minimum. Values have been swapped.'
                $a = $Minimum
                $Minimum = $Maximum
                $Maximum = $a
            }
        }
        Write-Debug "Limiting objects to range: < $(if($null -eq $Minimum){'N/A'}else{$Minimum}) ; $(if($null -eq $Maximum){'N/A'}else{$Maximum}) >"
    }
    process
    {
        foreach ($item in $InputObject)
        {
            if ($item -gt $Maximum -and $null -ne $Maximum)
            {
                $Maximum
            }
            elseif ($item -lt $Minimum -and $null -ne $Minimum)
            {
                $Minimum
            }
            else
            {
                $item
            }
        }
    }
}

function Group-ObjectFaster
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]]
        $InputObject,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Properties,
        [Parameter()]
        [int]
        $TotalCount,
        [Parameter()]
        [int]
        $UpdatesNumber = 100,
        [Parameter()]
        [switch]
        $HideProgressBar
    )
    begin
    {
        $hashy = @{}
        $counter = 0
        #If the value is not from pipeline we know how many elements there are
        if (-not $PSCmdlet.MyInvocation.ExpectingInput)
        {
            $TotalCount = $InputObject.Count
        }
        if ($UpdatesNumber -le 0)
        {
            $UpdatesNumber = 100
        }
        $UpdateThreshold = Limit-Object ([int][Math]::Floor($TotalCount / $UpdatesNumber)) 1 100000
        Write-Verbose "Update threshold is $UpdateThreshold"
        if (-not $UpdateThreshold -and (-not $HideProgressBar.IsPresent))
        {
            Write-Progress -Id 1 -Activity 'Grouping objects...' -Status 'Unknown number of objects' -PercentComplete -1
        }
    }
    process
    {
        foreach ($obj in $InputObject)
        {
            $props = $Properties | ForEach-Object { [string]($obj.$_) }
            $key = -join $props
            if (-not $hashy[$key])
            {
                $hashy[$key] = New-Object Collections.Generic.List[PSCustomObject]
                Write-Verbose "$counter - Added key: $key"
            }
            $hashy[$key].Add($obj)
            if ((-not $HideProgressBar.IsPresent) -and $UpdateThreshold -gt 0 -and $counter % $UpdateThreshold -eq 0)
            {
                Write-ProgressThrottled -Id 1 'Grouping objects...' -Total $TotalCount -Current $counter -UpdateThreshold $UpdateThreshold
            }
            $counter++
        }
    }
    end
    {
        if ($UpdateThreshold -gt 0)
        {
            Write-Progress -Id 1 -Activity 'Grouping objects...' -Completed
        }
        Write-Output $hashy
    }
}
$defaultTimeUnits = @{
    days = 'days'; hours = 'hours'; minutes = 'minutes'; seconds = 'seconds'; milliseconds = 'milliseconds'
}
function Format-TimeSpan
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Timespan[]]
        $Timespan,
        [Parameter()]
        [switch]
        $IncludeMilliseconds,
        [Parameter()]
        [switch]
        $DisableLegend,
        [Parameter()]
        [Hashtable]
        $Units = @{
            days = 'days'; hours = 'hours'; minutes = 'minutes'; seconds = 'seconds'; milliseconds = 'milliseconds'
        }
    )
    begin
    {
        $Units = @{
            days = if ($Units.days) { $Units.days } else { $defaultTimeUnits.days }
            hours = if ($Units.hours) { $Units.hours } else { $defaultTimeUnits.hours }
            minutes = if ($Units.minutes) { $Units.minutes } else { $defaultTimeUnits.minutes }
            seconds = if ($Units.seconds) { $Units.seconds } else { $defaultTimeUnits.seconds }
            milliseconds = if ($Units.milliseconds) { $Units.milliseconds } else { $defaultTimeUnits.milliseconds }
        }
    }
    process
    {
        foreach ($span in $Timespan)
        {
            $parts = @()
            $seps = @()
            $legend = @()
            if ($span.Days -gt 0)
            {
                if ($span.Days -gt 999)
                {
                    $parts += $span.Days.Tostring('D4')
                }
                elseif ($span.Days -gt 99)
                {
                    $parts += $span.Days.Tostring('D3')
                }
                else
                {
                    $parts += $span.Days.Tostring('D2')
                }
                $legend += "$($span.Days) $($Units.Days), "
                $seps += ':'
            }
            if ($span.Hours -gt 0 -or $parts.Length -gt 0)
            {
                $parts += $span.Hours.Tostring('D2')
                $legend += "$($span.Hours) $($Units.Hours), "
                $seps += ':'
            }
            if ($span.Minutes -gt 0 -or $parts.Length -gt 0)
            {
                $parts += $span.Minutes.Tostring('D2')
                $legend += "$($span.Minutes) $($Units.Minutes), "

                $seps += ':'
            }
            if ($span.Seconds -gt 0 -or $parts.Length -gt 0)
            {
                $sep = if ($IncludeMilliseconds.IsPresent) { '.' }else { '' }
                $sepL = if ($IncludeMilliseconds.IsPresent) { ', ' }else { '' }
                $parts += $span.Seconds.Tostring('D2')
                $legend += "$($span.Seconds) $($Units.Seconds)$sepL"
                $seps += $sep
            }
            if ($IncludeMilliseconds.IsPresent)
            {
                $parts += $span.Milliseconds.ToString('D3')
                $legend += "$($span.Milliseconds) $($Units.Milliseconds)"
            }
            for ($i = 0; $i -lt $parts.Count; $i++)
            {
                $durstring += $parts[$i] + $seps[$i]
                $legstring += $legend[$i]
            }
            if ($DisableLegend.IsPresent)
            {
                $durstring
            }
            else
            {
                ("$durstring ($legstring)")
            }
        }
    }
}
function Get-Info
{
    [CmdletBinding()]
    param (
    )
    $ips = Get-NetIPAddress -AddressState Preferred -InterfaceAlias Ethernet
    $v4 = $ips | Where-Object { $_.AddressFamily -eq 'IPv4' }
    $v6 = $ips | Where-Object { $_.AddressFamily -eq 'IPv6' }
    $cinfo = Get-ComputerInfo
    $cpu, $clock, $socket = $cinfo.CsProcessors | ForEach-Object {
        $_.Name.trim()
        $_.MaxClockSpeed
        $_.SocketDesignation }
    [pscustomobject][ordered]@{
        'IPv4 address'   = if ($v4.count -eq 1) { $v4[0] } else { $v4 }
        'IPv6 address'   = if ($v6.count -eq 1) { $v6[0] } else { $v6 }
        'OS'             = '{0} ({1})' -f $cinfo.OsName, $cinfo.OsArchitecture
        'OS version'     = $cinfo.OsVersion
        'RAM'            = $cinfo.CsTotalPhysicalMemory / 1GB
        'Primary owner'  = $cinfo.CsPrimaryOwnerName
        'CPU'            = $cpu
        'Clock'          = $clock
        'Socket'         = $socket
        'Motherboard'    = '{0} - {1}' -f $cinfo.CsModel, $cinfo.CsManufacturer
        'Bios'           = '{0} - {1} - {2} - {3}' -f $cinfo.BiosFirmwareType, $cinfo.BiosManufacturer, $cinfo.BiosName, $cinfo.BIOSVersion
        'Install date'   = $cinfo.OsInstallDate
        'Current User'   = $env:USERNAME
        'Current Domain' = $env:USERDOMAIN
        'Computer Name'  = $cinfo.CsName
        'Boot time'      = $cinfo.OsLastBootUpTime
        'Uptime'         = Format-TimeSpan ((Get-Date) - $cinfo.OsLastBootUpTime)
    }
}