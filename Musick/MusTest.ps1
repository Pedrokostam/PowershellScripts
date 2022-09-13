ipmo .\Musick\Musick.psd1 -Force
# update-formatdata ./Musick/CueSheet.ps1xml
# "E:\FLACBAZA\RawRips\220907\Pearl Jam - Ten.cue" |Test-Accurip
ls 'E:\FLACBAZA\rawRips\220908','E:\FLACBAZA\rawRips\220907'  -Filter *.cue |Test-Accurip -PipelineVariable cue| ? 'Accurate Rip' -eq $false | % {notepad++.exe ($cue.'Cue path' -replace '\.cue','.accurip')}