function Resolve-Bool {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [string] $A
    )
    $A -imatch '(1|true|yes|enabled|ja|da|tak|jak najbardziej|jeszcze jak|zgoda|dawaj|affirmative|let''s dance|graj muzyko|ehe|yhym)'
}
function Limit-Object {
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
    begin {
        if ($null -eq $Maximum -and $null -eq $Minimum) { Write-Warning 'Both bounds are set to null, no limiting will be done.' }
        elseif ($null -ne $Maximum -and $null -ne $Minimum) {
            if ($Minimum -eq $Maximum) { Write-Warning 'The limiting range is zero, as minimum equals to maximum.' }
            elseif ($Minimum -gt $Maximum) {
                Write-Warning 'Specified Maximum is larger than Minimum. Values have been swapped.'
                $a = $Minimum
                $Minimum = $Maximum
                $Maximum = $a
            }
        }
        Write-Debug "Limiting objects to range: < $(if($null -eq $Minimum){'N/A'}else{$Minimum}) ; $(if($null -eq $Maximum){'N/A'}else{$Maximum}) >"
    }
    process {
        foreach ($item in $InputObject) {
            if ($null -ne $Maximum -and $item -gt $Maximum) {
                $Maximum
            } elseif ($null -ne $Maximum -and $item -lt $Minimum) {
                $Minimum
            } else {
                $item
            }
        }
    }
}
New-Alias Limit Limit-Object
function Group-ObjectFaster {
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
    begin {
        $hashy = @{}
        $counter = 0
        #If the value is not from pipeline we know how many elements there are
        if (-not $PSCmdlet.MyInvocation.ExpectingInput) {
            $TotalCount = $InputObject.Count
        }
        if ($UpdatesNumber -le 0) {
            $UpdatesNumber = 100
        }
        $UpdateThreshold = Limit-Object ([int][Math]::Floor($TotalCount / $UpdatesNumber)) 1 100000
        Write-Verbose "Update threshold is $UpdateThreshold"
        if (-not $UpdateThreshold -and (-not $HideProgressBar.IsPresent)) {
            Write-Progress -Id 1 -Activity 'Grouping objects...' -Status 'Unknown number of objects' -PercentComplete -1
        }
    }
    process {
        foreach ($obj in $InputObject) {
            $props = $Properties | ForEach-Object { [string]($obj.$_) }
            $key = -join $props
            if (-not $hashy[$key]) {
                $hashy[$key] = New-Object Collections.Generic.List[PSCustomObject]
                Write-Verbose "$counter - Added key: $key"
            }
            $hashy[$key].Add($obj)
            if ((-not $HideProgressBar.IsPresent) -and $UpdateThreshold -gt 0 -and $counter % $UpdateThreshold -eq 0) {
                Write-ProgressThrottled -Id 1 'Grouping objects...' -Total $TotalCount -Current $counter -UpdateThreshold $UpdateThreshold
            }
            $counter++
        }
    }
    end {
        if ($UpdateThreshold -gt 0) {
            Write-Progress -Id 1 -Activity 'Grouping objects...' -Completed
        }
        Write-Output $hashy
    }
}
function Get-Info {
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
Function Write-InformationColored {
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

function Get-UnixPath {
    <#
    .SYNOPSIS
    Converts given Windows path to Unix-like path (for WSL).
    .DESCRIPTION
    Converts the the given Windows path to a path that can be used for the WSL instance.
    Changes backslashes to forward slashes.
    Assumes that each Windows partition are available in WSL as /mnt/{DriveLetter}.
    Can optionally make the path absolute first.
    .PARAMETER EscapeType
    Controls the type of escaping spaces. Possible values are Quotes and Backslash
    Quotes: c:\name with space -> "/mnt/c/name with space"
    Backslash: c:\name with space -> /mnt/c/name\ with\ space
    .PARAMETER ForceQuotes
    Forces the output to be encased in quotes regardless of whether there is a space in the path or not.
    Also overrides -EscapeType to Quotes
    .PARAMETER WindowsPath
    Path string.
    .PARAMETER AbsolutePath
    Switch to control whether the path should be made absolute with current directory as base.
    .PARAMETER UsePsObject
    Switch controlling the output type of the function.
    .OUTPUTS
    string
        Ordinary string by default
    PSObject
        PSObject containing the original Windows path and Unix string
    #>
    [OutputType([string], ParameterSetName = 'default')]
    [OutputType([psobject], ParameterSetName = 'pso')]
    [CmdletBinding(DefaultParameterSetName = 'default', PositionalBinding = $False)]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias('Path', 'Fullname')]
        [string[]]
        $WindowsPath,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        [ValidateSet('Backslash', 'Quotes')]
        $EscapeType = 'Quotes',
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $ForceQuotes,
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $AbsolutePath,
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'pso', Mandatory)]
        [switch]
        $UsePsObject
    )
    process {
        foreach ($element in $WindowsPath) {
            if ($AbsolutePath.IsPresent) {
                $element = [IO.Path]::GetFullPath($element)
            }
            if ($ForceQuotes.IsPresent) {
                $EscapeType = 'Quotes'
            }
            $original = $element
            if ($element -match '(?<Drive>\w+):[\\\/]') {
                $element = $element.Replace($Matches[0], "/mnt/$($Matches['Drive'].ToLower())/")
            }
            $unix = $element -replace '\\', '/'
            if ($unix.Contains(' ') -or $ForceQuotes.IsPresent) {
                if ($EscapeType -eq 'Quotes') {
                    $unix = '"{0}"' -f $unix
                } else {
                    $unix = $unix -replace ' ', '\ '
                }
            }
            if ($UsePsObject.IsPresent) {
                [PSCustomObject]@{
                    Path     = $original
                    UnixPath = $unix
                }
            } else {
                $unix
            }
        }
    }
}
function Test-File {
    <#
    .DESCRIPTION
    Uses the default WSL on the machine to execute the 'file' app and return its output
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Fullname')]
        [string[]]
        $Path
    )
    begin {
        where.exe wsl /Q | Out-Null
        if ($LASTEXITCODE) {
            Write-Error "WSL could not be found. Cannot use 'file' to test files..."
            break
        }
    }
    process {
        $Path | Resolve-Path -PipelineVariable resolved | Get-UnixPath -PipelineVariable file -UsePsObject | ForEach-Object { wsl file $_.UnixPath --brief } | ForEach-Object {
            [PSCustomObject]@{
                Path   = $resolved.Path
                Result = $_
            } }
    }
}

function Test-FileFolderCount {
    <#
    .SYNOPSIS
    Recursively counts all files in the given folder.
    Files to be counted can be limited with IncludePattern
    .PARAMETER UsePsObject
    Switch controlling the output type of the function.
    #>
    [OutputType([int], ParameterSetName = 'default')]
    [OutputType([psobject], ParameterSetName = 'pso')]
    [CmdletBinding(DefaultParameterSetName = 'default', PositionalBinding = $False)]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        [Alias('Fullname', 'PSPath')]
        [string]
        $Path = '.',
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $IncludePattern,
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'pso', Mandatory)]
        [switch]
        $UsePsObject
    )
    process {
        $root = Get-Item $Path
        $par = @{
            Path    = $Path
            Recurse = $true
            File    = $true

        }
        if ($IncludePattern) {
            $par.Include = $IncludePattern
        }
        $all = Get-ChildItem @par
        if ($UsePsObject.IsPresent) {

            [PSCustomObject]@{
                Directory = $root
                Files     = $all.count
            }
        } else {
            $all.count
        }
    }
}

function Get-Xd {
    <#
    .DESCRIPTION
    Gets xD
    xDDDDDDDDD
    #>
    '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::x:::::::::::::::::::::::::::::::::::::::::::::::::::::::::x::::::::::::::::::::::::
::::::::xdxx::::::::::::::::::xddddxxx::::::::::::::::::::::::::::xdxx::::::::::::::::::xddddxxx::::::::::::::::::
:::::::::dddx::::::::::::::::xddddddddddxxx::::::::::::::::::::::::dddx::::::::::::::::xddddddddddxxx:::::::::::::
:::::::::xddd::::::::x:::::::ddddddddddddddddx:::::::::::::::::::::xddd::::::::x:::::::ddddddddddddddddx::::::::::
:::::::::xdddx:::::xddddxx::xdddddxxdddddddddddxx::::::::::::::::::xdddx:::::xddddxx::xdddddxxdddddddddddxx:::::::
::::::::::dddx:::xddddddx::xdddddx::::xxdddddddddx::::::::::::::::::dddx:::xddddddx::xdddddx::::xxdddddddddx::::::
::::::::::xdddxxdddddxx:::xdddddx::::::::xddddddddx:::::::::::::::::xdddxxdddddxx:::xdddddx::::::::xddddddddx:::::
:::::::::::ddddddddx::::::dddddx::::::::::xdddddddd::::::::::::::::::ddddddddx::::::dddddx::::::::::xdddddddd:::::
::::::::::xddddddx:::::::xddddx::::::::::::xdddddddx::::::::::::::::xddddddx:::::::xddddx::::::::::::xdddddddx::::
:::::::xxddddddd::::::::xddddd:::::::::::::xdddddddx:::::::::::::xxddddddd::::::::xddddd:::::::::::::xdddddddx::::
:::::xdddddxxddd:::::::xddddd::::::::::::::dddddddd::::::::::::xdddddxxddd:::::::xddddd::::::::::::::dddddddd:::::
::::xddddx:::dddx:::::xdddddx:::::::::::::xdddddddx:::::::::::xddddx:::dddx:::::xdddddx:::::::::::::xdddddddx:::::
::::::xx:::::xddx:::::dddddx:::::::::::::xdddddddx::::::::::::::xx:::::xddx:::::dddddx:::::::::::::xdddddddx::::::
:::::::::::::xddd::::xddddx:::::::::::::xdddddddx::::::::::::::::::::::xddd::::xddddx:::::::::::::xdddddddx:::::::
::::::::::::::dddx::xddddx:::::::::::::xdddddddx::::::::::::::::::::::::dddx::xddddx:::::::::::::xdddddddx::::::::
:::::::::::::::xxx:xddddx::::::::::::xxdddddddx::::::::::::::::::::::::::xxx:xddddx::::::::::::xxdddddddx:::::::::
:::::::::::::::::::xdddddxx::::::::xxdddddddxx:::::::::::::::::::::::::::::::xdddddxx::::::::xxdddddddxx::::::::::
::::::::::::::::::::::xdddddxxxxxxdddddddddx::::::::::::::::::::::::::::::::::::xdddddxxxxxxdddddddddx::::::::::::
:::::::::::::::::::::::::xxdddddddddddddxx:::::::::::::::::::::::::::::::::::::::::xxdddddddddddddxx::::::::::::::
:::::::::::::::::::::::::::::xxxxxxxxx:::::::::::::::::::::::::::::::::::::::::::::::::xxxxxxxxx::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
}

New-Alias xD get-xd

function Get-FileMeta {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, Position = 0)]
        [string[]]
        $Path,
        [Parameter( Mandatory, Position = 0)]
        [Alias('Index')]
        [string[]]
        $Column
    )
    begin {
        $objShell = New-Object -ComObject Shell.Application
    }
    process {
        foreach ($outputDirectory in $Path) {
            $outputDirectory = $outputDirectory | Get-Item -ErrorAction SilentlyContinue
            if ($outputDirectory -is [System.IO.DirectoryInfo]) {
                Write-Error "$outputDirectory is not a file"
                continue
            } elseif ($outputDirectory -isnot [System.IO.FileInfo] -or -not $outputDirectory.Exists) {
                Write-Error "$outputDirectory does not exist"; continue
            } else {
                # fileinfo
                $objFolder = $objShell.Namespace($outputDirectory.DirectoryName)
                $objFile = $objFolder.ParseName($outputDirectory.Name)
                $result = @{File = $outputDirectory }
                foreach ($col in $Column) {
                    $value = $objFolder.GetDetailsOf($objFile, $col)
                    $result[$col] = $value
                }
                [pscustomobject]$result
            }
        }
    }
}

