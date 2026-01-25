Import-Module .\functions.psm1 -Force

$vars = Get-RBUtilsVars
$csv = Import-TrackListCsv

# Copy and paste output into LocalFilePath column

$songs = @{}
foreach ($song in $csv) {
  $fileName = Get-SongFileName $song
  $songs[$fileName] = $True
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
      # Delete any files for which sync is disabled but still exist in the output dir
      if ($result.Result -eq 'Sync is disabled') {
        if (Test-Path -Path $song.LocalFilePath) {
          Write-Warning "Deleting $($song.LocalFilePath) because sync off for $songIdHash"
          Remove-Item -Path $song.LocalFilePath
        }
        $songPath = "$($vars.OutputPath)\$($songIdHash).aiff"
        if (Test-Path -Path $songPath) {
          Write-Warning "Deleting $songPath because sync off for $songIdHash"
          Remove-Item -Path $songPath
        }
      }
    }
  }
}

# Now for every file in the output dir, ensure it matches an actual song
$files = Get-ChildItem -Path $vars.OutputPath
foreach ($file in $files) {
  if (-Not $songs[$file.Name]) {
    Write-Warning "$($file.Name) is missing from library, deleting"
    Remove-Item -Path "$($vars.OutputPath)/$($file.Name)"
  }
}