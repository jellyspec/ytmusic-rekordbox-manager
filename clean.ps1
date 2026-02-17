Import-Module .\functions.psm1 -Force

$vars = Get-RBUtilsVars
$csv = Import-TrackListCsv

# Copy and paste output into LocalFilePath column

$songs = @{}
foreach ($song in $csv) {
  $result = Validate-Song $song
  $fileName = Get-SongFileName $song
  $songIdHash = Get-SongHash $song
  $songs[$fileName] = $True
  # Delete any files for which sync is disabled but still exist in the output dir
  if ($result.Result -eq 'Sync is disabled') {
    if ($song.LocalFilePath -And (Test-Path -Path $song.LocalFilePath)) {
      Write-Warning "Deleting $($song.LocalFilePath) because sync off for $songIdHash"
      Remove-Item -Path $song.LocalFilePath
    }
    $songPath = "$($vars.OutputPath)\$fileName"
    if (Test-Path -Path $songPath) {
      Write-Warning "Deleting $songPath because sync off for $songIdHash"
      Remove-Item -Path $songPath
    }
  }
  if ($result.Okay) {
    if (-Not $song.LocalFilePath) {
      Write-Output ""
    } else {
      # Ensure every song with a LocalFilePath set only has one copy available
      $duplicateOutFile = "$($vars.OutputPath)\$($songIdHash).aiff"
      if (Test-Path -Path $duplicateOutFile) {
        Write-Warning "$duplicateOutFile exists as duplicate on disk, deleting"
        Remove-Item -Path $duplicateOutFile
      }
      Write-Output $song.LocalFilePath
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