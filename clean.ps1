Import-Module .\functions.psm1 -Force -Verbose

$vars = Get-RBUtilsVars
$csv = Import-TrackListCsv

# Copy and paste output into LocalFilePath column

foreach ($song in $csv) {
  # Ensure every song with a LocalFilePath set only has one copy available
  if (-Not $song.LocalFilePath) {
    Write-Output ""
  } else {
    $result = Validate-Song $song
    if ($result.Okay) {
      Write-Output $song.LocalFilePath
      $songIdHash = Get-SongHash $song
      $duplicateOutFile = "$($vars.OutputPath)\$($songIdHash).aiff"
      if (Test-Path -Path $duplicateOutFile) {
        Write-Warning "$duplicateOutFile exists as duplicate on disk, deleting"
        Remove-Item -Path $duplicateOutFile
      }
    }
  }
}