$WppUpdatePeriod = 100
$WppPersistent = @{}
$DefaultFormat = { $args[0] }
function Write-ProgressPlus
{
    <#
    .SYNOPSIS
    Informs about progress of operation. Can be used in pipeline or outside. Non-pipeline use requires resetting the state of progress bar with Reset-Progress.
    .DESCRIPTION
    This command writes to the progress stream. It automates many function of native Write-Progress.
    The command can be be a part of pipeline, but it can also be used outside of pipeline. By default each invocation will increment the counter, but the user can override it.
    The command can calculates estimated time of completion.
    If the command is in the middle of the line, it automatically passes through all input objects.
    If it is at the end of a pipeline, it does not pass through any objects, unless used with PassThru switch.
    Non-pipeline use requires resetting the state of progress bar with Reset-Progress.
    Command has 3 modes:
        -Pipeline
            Piped.
            Objects are fed through pipeline and are required.
            Each object increses iteration by one.
            Will automatically reset at the end of pipeline.
        -Auto
            Not piped.
            Objects are optional.
            Each call for the specific ID will increase iteration by one.
            Needs to be reset after completion.
        -Manual
            Not piped.
            Objects are optional.
            The current iteration number has to be specified in each call.
            Needs to be reset after completion.
    .PARAMETER InputObject
    Object used in the last iteration of the process.
    .PARAMETER CurrentIteration
    Used to override the automatically calculated iteration.
    .PARAMETER HideObject
    If the switch is present, the input object will not be displayed in the bar.
    It is equivalent to setting ItemFormat to null.
    .PARAMETER ItemFormat
    The ScriptBlock should contain a script outputting a string related to the object.
    The string will be appended to Status (if InputObject is specified).
    The scriptblock should expect one input parameter (which will be the InputObject).
    Examples of scripts: {$args[0]}, {param($a) $a}
    By default it uses base string representation
    .PARAMETER Activity
    Specifies the first line of text in the heading above the status bar.
    This text describes the activity whose progress is being reported.
    .PARAMETER Id
    Specifies an ID that distinguishes each progress bar from the others
    Use this parameter when you are creating more than one progress bar in a single command.
    If the progress bars do not have different IDs, they are superimposed instead of being displayed in a series.
    Negative values are not allowed.
    .PARAMETER ParentId
    Specifies the parent activity of the current activity.
    Use the value -1 if the current activity has no parent activity.
    .PARAMETER PassThru
    If set, the command will pass through input objects to the pipeline.
    Only effective if the command is at the end of the pipeline - if in the middle the object will always be passed through
    .PARAMETER TotalCount
    If set the command will be able to show completion of the process, as well as calculate estimated time remaining.
    If number of iterations exceeds the total count, warning will be included in status.
    .PARAMETER NoEta
    If present the estimated completion time will not be displayed.
    .EXAMPLE
    1..100 | %{sleep -milliseconds 100; $_} | Write-ProgressPlus

    Will display a progress bar labelled Activity and counting iterations
    .EXAMPLE
    1..100 | Write-ProgressPlus -Activity 'Working' -TotalCount 100 -HideObject| %{sleep -milliseconds 100}

    Will display a progress bar labelled Working and counting iterations. Will display percentage of completion, current object, and calculate remaining time. Object are piped along
    .EXAMPLE
    1..100 | %{sleep -milliseconds 100; Write-ProgressPlus}

    Will display a progress bar labelled Activity and counting iterations.
    .EXAMPLE
    1..100 | %{sleep -milliseconds 100; Write-ProgressPlus -CurrentIteration $_*2}

    Will display a progress bar labelled Activity and counting iterations twice as fast.
    .NOTES
    Reset-Progress can be used to reset the state of the progress bar.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Auto')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Pipe')]
        [Parameter(ParameterSetName = 'Manual')]
        [Alias('Item')]
        [object]
        $InputObject,
        [Parameter(Mandatory, ParameterSetName = 'Manual')]
        [Alias('Iteration')]
        [int]
        $CurrentIteration,
        [Parameter()]
        [scriptblock]
        $ItemFormat,
        [Parameter()]
        [Alias('SkipObject', "NoShow'")]
        [switch]
        $HideObject,
        [Parameter(ParameterSetName = 'Pipe')]
        [switch]
        $PassThru,
        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Id = 1,
        [Parameter()]
        [int]
        $ParentId = -1,
        [Parameter()]
        [string]
        $Activity = 'Processing...',
        [Parameter()]
        [Alias('Total')]
        [int64]
        $TotalCount,
        [Parameter()]
        [Alias('SkipRemainingTime', 'SkipETA')]
        [switch]
        $NoEta,
        [Parameter()]
        [switch]
        $SkipCounter
    )
    begin
    {
        Write-Debug "Mode: $($PSCmdlet.ParameterSetName)"
        $IsPipeline = $PSCmdlet.MyInvocation.ExpectingInput
        if (-not $WppPersistent.ContainsKey($Id) -or $IsPipeline)
        {
            Write-Debug 'Creating new state'
            $WppPersistent[$Id] = @{
                StartTime        = Get-Date
                LastXTimes       = @(Get-Date)
                LastDisplayed    = (Get-Date) - ([timespan]::FromMilliseconds($WppUpdatePeriod * 2)) # Arbitrary timespan longer than update period. If it were zero, the first itertion would not be displayed.
                ID               = $Id
                ParentID         = $ParentId
                TotalCount       = if ($PSBoundParameters.ContainsKey('TotalCount')) { $TotalCount } else { -1 }
                CurrentIteration = 0
                ItemFormat       = if ($HideObject.IsPresent) { $null } elseif ($ItemFormat) { $ItemFormat } else { $DefaultFormat }
                Activity         = $Activity
                NoEta            = $NoEta.IsPresent
                AutoIncrement    = $AutoIncrement.IsPresent
                SkipCounter      = $SkipCounter.IsPresent
            }
        }
        else
        {
            Write-Debug 'Using existing state'
        }
        if ($IsPipeline)
        {
            Write-ProgressInternal $Id
            $MiddleOfPipe = $PSCmdlet.MyInvocation.PipelineLength -gt $PSCmdlet.MyInvocation.PipelinePosition
        }
    }
    process
    {
        $WppPersistent[$id].TotalCount = $TotalCount
        $WppPersistent[$id].SkipCounter = $SkipCounter
        if ($PSCmdlet.ParameterSetName -eq 'Manual')
        {
            $WppPersistent[$Id].CurrentIteration = $CurrentIteration
        }
        else #if ($AutoIncrement.IsPresent -or $PSCmdlet.ParameterSetName -eq 'Pipe')
        {
            $WppPersistent[$Id].CurrentIteration++
        }
        Write-ProgressInternal -Id $WppPersistent[$Id].ID -Item $InputObject
        if ($PassThru.IsPresent -or $MiddleOfPipe)
        {
            $InputObject
        }
    }
    end
    {
        if ($IsPipeline)
        {
            Reset-Progress -Id $id
        }
    }

}
function Write-ProgressInternal
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]
        $Id,
        [Parameter()]
        $Item
    )

    $pState = $WppPersistent[$Id]
    $skipCounter = $pState['SkipCounter']
    $pOutput = @{
        ID       = $pState.ID
        Parent   = $pState.ParentID
        Activity = $pState.Activity
        Status   = if ($skipCounter) { ' ' } else { [string]$pState.CurrentIteration }
    }
    if ($pState.TotalCount -gt 0)
    {
        $pOutput.PercentComplete = $pState.CurrentIteration * 100.0 / $pState.TotalCount
        if ($pOutput.PercentComplete -gt 100)
        {
            if (-not $skipCounter)
            {
                $pOutput.Status += ' / '
            }
            $pOutput.Status += "[total count of $($pState.Totalcount) exceeded]"
            $pOutput.PercentComplete = 100
        }
        else
        {
            if (-not $skipCounter)
            {
                $pOutput.Status += ' / '
            }
            $pOutput.Status += '{0} ({1:d2}%)' -f $pState.TotalCount, [int]$pOutput.PercentComplete
            if (-not $pState.NoEta)
            {
                $NewTimes, $eta, $average = Get-Eta -Times $pState.LastXTimes -Total $pState.TotalCount -Current $pState.CurrentIteration
                $pState.LastXTimes = $NewTimes
                $pOutput.SecondsRemaining = $eta
            }
        }
    }
    else
    {
        $diffMs = ((get-date) - $pState.StartTime).TotalMilliseconds / 4
        $difMod = $diffMs % 2000
        $difNorm = $difMod / 1000 * 3.1415
        $pOutput.PercentComplete = [math]::cos($difNorm) * 40 + 50
    }
    if ($null -ne $pState.ItemFormat)
    {
        try
        {
            $string = Invoke-Command -ScriptBlock $pState.ItemFormat -ArgumentList $Item -ErrorAction Stop
            $pOutput.Status += " - $($string)"
        }
        catch
        {
            $pOutput.Status += ' - [Incorrect formatter]'
        }
    }
    $TimeSinceDisplay = (Get-Date) - $pState.LastDisplayed
    if ([long]($TimeSinceDisplay.TotalMilliseconds) -ge $WppUpdatePeriod)
    {
        $pState.LastDisplayed = Get-Date
        Write-Progress @pOutput -ErrorAction Stop
    }
}
function Reset-Progress
{
    <#
    .SYNOPSIS
    Resets the state of the specified progress bar
    .PARAMETER Id
    Id of the progress bar to reset. If negative, resets all progress bars.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $Id = -1
    )
    if ($Id -lt 0)
    {
        $WppPersistent.Clear()
        Write-Debug "Cleared all progress states ($($WppPersistent.Count))"
    }
    else
    {
        if ($WppPersistent.ContainsKey($Id))
        {
            $WppPersistent.Remove($Id)
            Write-Debug "Cleared status of progress $Id "
        }
        else
        {
            Write-Debug "No status with ID $Id to cl ear"
        }
    }
}
function Get-Eta
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Datetime[]]
        $Times,
        [Parameter(Mandatory)]
        [int]
        $Total,
        [Parameter(Mandatory)]
        [int]
        $Current,
        [Parameter()]
        [int]
        $SampleSize = 25
    )
    $Times = @( $Times | Select-Object -Last ($SampleSize - 1)) + (Get-Date)
    $diffs = for ($i = 0; $i -lt $Times.Count - 1; $i++)
    {
           ($Times[$i + 1] - $times[$i]).TotalSeconds
    }
    $diffs = $diffs | Sort-Object
    if ($diffs.Count -ge 5)
    {
        $diffs = $diffs | Select-Object -Skip 2 | Select-Object -SkipLast 2
    }
    $avg = $diffs | Measure-Object -Average | Select-Object -expand Average
    $eta = ($Total - $Current) * $avg
    $Times, $eta, $avg
}

function Test-Wripro
{
    $points = for ($i = 0; $i -lt 10; $i++)
    {
        for ($j = 0; $j -lt 10; $j++)
        {
            [pscustomobject]@{
                X = $i
                Y = $j
            }
        }
    }

    $a = 0;
    $points | Write-ProgressPlus -id 1 -TotalCount 100 -DisplayObject -Activity 'kek' -Debug |
        ForEach-Object { $points |
                Write-ProgressPlus -id 2 -ParentId 1 -TotalCount 100 -DisplayObject -Debug |
                ForEach-Object { Start-Sleep -Milliseconds 100 } }
    Read-Host 'Testing pipeline'
    $points |
        Write-ProgressPlus -ID 1 -Activity 'default' |
        Write-ProgressPlus -ID 2 -ParentID 1 -Activity 'display' -DisplayObject |
        Write-ProgressPlus -ID 3 -ParentID 1 -Activity 'format' -ItemFormat { param($p) "Punkt: $($p.X) ;; $($p.Y)" } |
        Write-ProgressPlus -ID 4 -ParentID 1 -Activity 'total' -TotalCount 100 |
        Write-ProgressPlus -ID 5 -ParentID 4 -Activity 'wrong' -TotalCount 50 |
        Write-ProgressPlus -ID 6 -ParentID 2 -Activity 'wrongdisp' -TotalCount 50 -DisplayObject |
        ForEach-Object { Start-Sleep -Milliseconds 100 ; $_ } |
        Write-ProgressPlus -ID 7 -Activity 'totaleta' -TotalCount 100 -NoEta
    Read-Host 'Testing manual'
    $z = 0
    foreach ($p in $points)
    {
        Write-ProgressPlus -ID 1 -Activity 'default'
        Write-ProgressPlus -ID 2 -Activity 'display' -DisplayObject
        Write-ProgressPlus -ID 3 -Activity 'format' -ItemFormat { param($p) "Punkt: $($p.X) ;; $($p.Y)" }
        Write-ProgressPlus -ID 4 -Activity 'total' -TotalCount 100
        Write-ProgressPlus -ID 5 -Activity 'wrong' -TotalCount 50
        Write-ProgressPlus -ID 6 -Activity 'curr' -CurrentIteration $z
        Write-ProgressPlus -ID 8 -Activity 'input ' -InputObject $p -ItemFormat { param($p) "Punkt: $($p.X) ;; $($p.Y)" }
        Write-ProgressPlus -ID 9 -Activity 'input ' -InputObject $p -DisplayObject
        Start-Sleep -Milliseconds 100
        $z++
    }
    Read-Host 'noreest'
    foreach ($p in $points)
    {
        Write-ProgressPlus -ID 1 -Activity 'default'
        Write-ProgressPlus -ID 2 -Activity 'display' -DisplayObject
        Write-ProgressPlus -ID 3 -Activity 'format' -ItemFormat { param($p) "Punkt: $($p.X) ;; $($p.Y)" }
        Write-ProgressPlus -ID 4 -Activity 'total' -TotalCount 100
        Write-ProgressPlus -ID 5 -Activity 'wrong' -TotalCount 50
        Write-ProgressPlus -ID 6 -Activity 'curr' -CurrentIteration $z
        Write-ProgressPlus -ID 8 -Activity 'input ' -InputObject $p -ItemFormat { param($p) "Punkt: $($p.X) ;; $($p.Y)" }
        Write-ProgressPlus -ID 9 -Activity 'input ' -InputObject $p -DisplayObject
        Start-Sleep -Milliseconds 100
    }
}

New-Alias -Name WriPro Write-ProgressPlus
New-Alias -Name WriProg Write-ProgressPlus
New-Alias -Name ResPro Reset-Progress
