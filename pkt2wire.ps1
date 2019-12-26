param($inputFile,$outFile)

$myInput = Get-Content $inputFile

$myData = $myInput | Where {$_ -match "^(       |\t)0x"}

New-Item -Name $outFile -ItemType File

$myData | % {
    $_ -replace "(        |\t)0x","00" -replace ":  "," "  -replace " ([a-f0-9][a-f0-9])([a-f0-9][a-f0-9])",' $1 $2' | Out-File -Append -encoding ascii $outFile
}
