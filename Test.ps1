try
{
    Import-Module C:\Users\Pedro\Documents\GitHub\PowershellScripts\Musick\Musick.psd1 -Force
    Get-MediaDuration -Path 'E:\FLACBAZA\Kolekcja\Depeche Mode\1990 - Violator (Sire~Reprise CD 26081)\07 - Policy Of Truth.flac'
    # Test-Accurip -path 'E:\FLACBAZA\RawRips\coyp\' -ea Break
    # Start-ProcessWithProgress -path C:\Programy\CueTools\CUETools.Flake.exe -argument 'C:\Users\Pedro\sound.wav -f' -activity 'Converting song...' -ea break
    # #$files = ls  E:\FLACBAZA\RawRips\ -Recurse -Filter *.cue
    # #$files | Test-Accurip #-ea Stop
}
finally
{
    #Clear-Host
}