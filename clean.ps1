Import-Module .\functions.psm1 -Force -Verbose

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