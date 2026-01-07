Import-Module -Force .\functions.psm1

$wavFormat = Get-ModuleWAVFormat
$webmPath = Get-ModuleWebmPath
$outputPath = Get-ModuleOutputPath

Write-Output "WAV format: $wavFormat"
Write-Output "WAV format: $webmPath"
Write-Output "WAV format: $outputPath"

$csv = Import-TrackListCsv
foreach ($song in $csv) {
  $result = validateRecord -Record $song
  if (-Not $result.Okay) {
    Write-Output "N/A"
    continue
  }
  $songIdHash = Get-SongHash -Song $song
  Write-Output $songIdHash
}