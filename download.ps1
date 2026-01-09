Import-Module .\functions.psm1 -Force

$vars = Get-RBUtilsVars
$csv = Import-TrackListCsv

# Copy and paste output into SongIdHash column

foreach ($song in $csv) {
  $result = Validate-Song $song
  if (-Not $result.Okay) {
    Write-Output "N/A"
  } else {
    $songIdHash = Get-SongHash $song
    Write-Output $songIdHash
    $webmFile = "$($vars.WebmPath)\$($songIdHash).webm"
    if (-Not (Test-Path -Path $webmFile)) {
      Write-Warning "Webm file for $songIdHash does not exist, downloading"
      $logPath = "$($vars.LogPath)\$($songIdHash).log"
      .\yt-dlp.exe -f bestaudio $song.URL -o $webmFile *>$logPath
      if ($LASTEXITCODE -ne 0) {
        Write-Warning "yt-dlp encountered an error ($LASTEXITCODE), log is $logPath"
      } else {
        Remove-Item -Path $logPath
      }
    }
    Convert-WebmToWav -Record $song
  }
}