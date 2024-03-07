function Get-SessionDate {
    [OutputType([datetime])]
    [datetime]$sessionDate = Get-Date
    #if it is the begininng of a new day, check if there was a session near the end of the previous day.
    if ($sessionStartDate.Hour -le 2) {
        $yesterday = $sessionDate.Subtract([timespan]::FromDays(1))
        $yesterdaySessionFolderName = $yesterday.ToString('yyyyMMdd')
        $oldFold = Get-ChildItem -Path $tempFolder -Directory -Filter $yesterdaySessionFolderName
        if ($oldFold -and $oldFold.CreationTime.Hour -gt 22) {
            $sessionDate = $yesterday
            Write-Verbose "Reusing folder $($oldFold.Name) from previous session"
        }
    }
    $sessionDate
}