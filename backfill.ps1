Import-Module -Force .\functions.psm1

$wavFormat = Get-ModuleWAVFormat
$webmPath = Get-ModuleWebmPath
$outputPath = Get-ModuleOutputPath

Write-Output "WAV format: $wavFormat"
Write-Output "WAV format: $webmPath"
Write-Output "WAV format: $outputPath"

# Construct a mapping of every track we need to locate the file for
$lines = Get-Content '..\..\Documents\CUE Analysis Playlist.m3u8'
$songHash = @{}
$lastSong = $null
foreach ($line in $lines) {
  if ($lastSong -ne $null) {
    # Assign filename to "artist - songname"
    $songHash[$lastSong] = $line
    $lastSong = $null
  }
  if ($line -match "^#EXTINF:[0-9]+,(.+)$") {
    $lastSong = "$($Matches[1])"
  }
}

$csv = Import-TrackListCsv
$processed = 0
# Create a mapping of artist + song and the correct file hash
foreach ($song in $csv) {
  $result = validateRecord -Record $song
  if (-Not $result.Okay) {
    Write-Output ""
    continue
  }
  # Note that this is a different ID than what gets hashed
  $songId = "$($song.Artist) - $($song.Title)"
  $songIdHash = Get-SongHash -Song $song
  $oldPath = $songHash[$songId]
  if (-Not $oldPath) {
    Write-Output ""
    continue
  }
  $oldPath = Split-Path -Path $oldPath -Leaf
  Write-Output $oldPath
  $processed++
}

Write-Output "Total songs processed: $processed"