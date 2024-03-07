function Get-PipelineItemCount {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [object]
        $InputObject,
        [Parameter()]
        [switch]
        $ToHost,
        [Parameter()]
        [switch]
        $PassThru,
        [Parameter()]
        [Alias('Format')]
        [string]
        $FormatString = $null,
        [Parameter()]
        [Alias('Provider')]
        [System.IFormatProvider]
        $FormatProvider = $null
    )
    begin {
        $count = 0
    }
    process {
        $count++
        if ($PassThru.IsPresent) {
            $InputObject
        }
    }
    end {
        $message = $count
        if ($FormatProvider -is $null -and -not $FormatString) {
            $message = $count
        }
        if ($ToHost.IsPresent) {
            Write-Host $message
        } else {
            $message
        }
    }
}

Set-Alias -name count -Value Get-PipelineItemCount