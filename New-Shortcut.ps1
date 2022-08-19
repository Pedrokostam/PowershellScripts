function New-ShortcutImpl
{
    [CmdletBinding(DefaultParameterSetName = 'Fullpath', SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        $ObjShell,
        [Parameter(Mandatory)]
        [ValidateScript(
            { Test-Path $_ },
            ErrorMessage = 'The provided path: {0} does not exist')]
        [string]
        $TargetDestination,
        [Parameter(Mandatory, ParameterSetName = 'Fullpath')]
        [string]
        $ShortcutPath,
        [Parameter(Mandatory, ParameterSetName = 'Components')]
        [string]
        $ShortcutFolder,
        [Parameter(ParameterSetName = 'Components')]
        [string]
        $ShortcutName,
        [Parameter()]
        [string]
        $IconPath,
        [Parameter()]
        [string]
        $Description,
        [Parameter()]
        [switch]
        $Force
    )
    if ($PSCmdlet.ParameterSetName -eq 'Components')
    {
        if ([string]::IsNullOrWhiteSpace($ShortcutName))
        {
            $ShortcutName = [system.io.path]::GetFileNameWithoutExtension($TargetDestination)
            Write-Verbose "Name not specified - using $ShortcutName"
        }
        $ShortcutPath = Join-Path $ShortcutFolder.trim() $ShortcutName.trim()
    }
    $ShortcutPath = [system.io.path]::ChangeExtension($ShortcutPath, 'lnk')
    Write-Verbose "Shortcut path: $ShortcutPath"
    $ShortcutPath = [io.path]::GetFullPath($ShortcutPath).trim()
    Write-Verbose "Resolved shortcut path: $ShortcutPath"
    $ShortcutFolder = Split-Path $ShortcutPath
    $objShortCut = $ObjShell.CreateShortcut($ShortcutPath)
    $objShortCut.TargetPath = $TargetDestination
    if (-not [string]::IsNullOrWhiteSpace($Description))
    {
        Write-Verbose "Setting description to $Description"
        $objShortCut.Description = $Description
    }
    if (-not [string]::IsNullOrWhiteSpace($IconPath))
    {
        if ([System.IO.Path]::IsPathRooted($IconPath))
        {
            if (Test-Path $IconPath)
            {
                Write-Verbose "Setting icon to $IconPath"
                $objShortCut.IconLocation = $IconPath
            }
            else
            {
                Write-Warning "Icon path $IconPath does not exist. Using target's icon."
            }
        }
        else
        {
            Write-Verbose "Icon path is relative: $IconPath"
            try
            {
                $base = (Split-Path $TargetDestination)
                $IconPath = Resolve-Path (Join-Path $base $IconPath) -ErrorAction Stop
                Write-Verbose "Icon path set to $IconPath"
                $objShortCut.IconLocation = $IconPath
            }
            catch
            {
                Write-Warning "Icon path $IconPath relative to $base does not exist. Using target's icon."
            }
        }
    }
    $Vdesc = "Creating shortcut to $targetDestination in $ShortcutPath"
    $VWarn = "Are you sure you want to create a shortcut to $targetDestination in $ShortcutPath`?"
    $makeDir = -not (Test-Path $ShortcutFolder)
    $remOld = Test-Path $ShortcutPath
    if ($remOld)
    {
        $Vdesc += ' (Will remove old shortcut)'
        $VWarn += ' (Will remove old shortcut)'
    }
    if ($makeDir)
    {
        $Vdesc += ' (Will create directory)'
        $VWarn += ' (Will create directory)'
    }

    if ($PSCmdlet.ShouldProcess(
            $Vdesc,
            $VWarn,
            'Create shortcut'))
    {
        if ($makeDir)
        {
            Write-Verbose "Creating folder: $ShortcutFolder"
            New-Item -ItemType Directory -Path $ShortcutFolder -Force -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false | Out-Null
            if (-not (Test-Path $ShortcutFolder))
            {
                throw "Could not create directory $ShortcutFolder"
            }
            Write-Verbose "Created directory: $ShortcutFolder"
        }
        if ($remOld)
        {
            if ($Force.IsPresent)
            {
                Remove-Item $ShortcutPath -WhatIf:$false -Confirm:$false
                Write-Verbose "Removing previous shortcut: $ShortcutPath"
            }
            else
            {
                Write-Error "Shortcut with the same path - $ShortcutPath - already exists. Use -Force to overwrite existing shortcuts"
                return
            }
        }
        $objShortCut.Save()
        Write-Verbose "Created shortcut in $ShortcutPath, targeting $TargetDestination"
        Get-ChildItem $ShortcutPath
    }
    else
    {
        Write-Verbose 'User did not confirm operation'
    }
}
function New-Shortcut
{
    <#
    .Synopsis
    Creates a shortcut in to file in specified location.
    .DESCRIPTION
    Creates a shortcut in to file in specified location. The user can provide the desired path of the shortcut or just the location with optional name.
    .PARAMETER TargetDestination
    The target of the shortcut, which will be launched after opening it
    .PARAMETER ShortcutName
    The name of the shortcut. If not specified, then name of the target will be used
    .PARAMETER ShortcutLocation
    Subfolder in the start menu where the shorctur will be placed. If not specifed, the shortcut will be placed directly in start menu/programs
    .PARAMETER IconPath
    Path to custom icon for the shortcut. If not specified, the icon of the target will be used. The icon path may be relative to the target.
    .PARAMETER Description
    Optional description of the shortcut
    .PARAMETER Force
    If true, existing shortcuts will be overwritten if the path is the same.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Fullpath', SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Target', 'Source')]
        [string]
        $TargetDestination,
        [Parameter(Mandatory, ParameterSetName = 'Fullpath', ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string]
        $ShortcutPath,
        [Parameter(Mandatory, ParameterSetName = 'Components', ValueFromPipelineByPropertyName)]
        [Alias('Folder', 'Directory', 'Location', 'ShortcutDirectory', 'ShortcutLocation')]
        [string]
        $ShortcutFolder,
        [Parameter(ParameterSetName = 'Components', ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]
        $ShortcutName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Icon')]
        [string]
        $IconPath,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Comment')]
        [string]
        $Description,
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        [Alias('F')]
        $Force
    )
    begin
    {
        Write-Debug 'Created WShell object'
        $objShell = New-Object -ComObject ('WScript.Shell')
    }
    process
    {
        $params = @{
            ObjShell          = $objShell
            TargetDestination = $TargetDestination
            IconPath          = $IconPath
            Description       = $Description
            Force             = $Force.IsPresent
        }
        if ($PSCmdlet.ParameterSetName -eq 'Fullpath')
        {
            $params.ShortcutPath = $ShortcutPath
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Components')
        {
            $params.ShortcutFolder = $ShortcutFolder
            $params.ShortcutName = $ShortcutName
        }
        try
        {
            New-ShortcutImpl @params -ErrorAction Stop
        }
        catch
        {
            Write-Error ($_.Exception.Message)
        }
    }
}
function New-StartMenuShortcut
{
    <#
    .SYNOPSIS
    Creates a shortcut in start menu of current user
    .DESCRIPTION
    Creates a shortcut in start menu to the specified file. Basically an extension of New-Shortcut limited to the location. If you want to place a shortcut in an arbitrary path use New-Shortcut.
    .PARAMETER TargetDestination
    The target of the shortcut, which will be launched after opening it
    .PARAMETER ShortcutName
    The name of the shortcut. If not specified, then name of the target will be used
    .PARAMETER ShortcutLocation
    Subfolder in the start menu where the shorctur will be placed. If not specifed, the shortcut will be placed directly in start menu/programs
    .PARAMETER IconPath
    Path to custom icon for the shortcut. If not specified, the icon of the target will be used. The icon path may be relative to the target.
    .PARAMETER Description
    Optional description of the shortcut
    .PARAMETER Force
    If true, existing shortcuts will be overwritten if the path is the same.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Target', 'Source')]
        [string]
        $TargetDestination,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]
        $ShortcutName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Folder', 'Directory', 'Location', 'ShortcutDirectory', 'ShortcutLocation')]
        [string]
        $ShortcutFolder,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $Description,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Icon')]
        [ValidateNotNullOrEmpty()]
        [string]
        $IconPath,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('UseParent')]
        [switch]
        $UseParentNameFolder,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('F')]
        [switch]
        $Force
    )
    begin
    {
        Write-Debug 'Created WShell object'
        $objShell = New-Object -ComObject ('WScript.Shell')
    }
    process
    {
        if (-not $ShortcutFolder)
        {
            if ($UseParentNameFolder.IsPresent)
            {
                Write-Verbose "Location not specified - using parent folder of target: $ShortcutFolder"
                $ShortcutFolder = Split-Path -Path (Split-Path -Path $TargetDestination) -Leaf
            }
            else
            {
                $ShortcutFolder = '.'
                Write-Verbose 'Location not specified - placing shortcut in root of programs'
            }
        }
        $ShortcutFolder = $ShortcutFolder.Trim()
        if ([string]::IsNullOrWhiteSpace($ShortcutName))
        {
            $Name = Split-Path -Path $TargetDestination -Leaf
            Write-Verbose "Shortcut name not specified - using name of target: $Name"
            $Name = $Name -replace '\.[^\.]*$', ''
        }
        $Name = $Name.Trim()
        $pfolder = Join-Path "$env:USERPROFILE\Start Menu\Programs" $ShortcutFolder
        $params = @{
            ObjShell          = $objShell
            TargetDestination = $TargetDestination
            ShortcutFolder    = $pfolder
            ShortcutName      = $Name
            Description       = $Description
            IconPath          = $IconPath
            Force             = $Force.IsPresent
        }
        try
        {
            New-ShortcutImpl @params -ErrorAction Stop
        }
        catch
        {
            Write-Error ($_.Exception.Message)
        }
    }
}
