Import-Module -Force .\functions.psm1

Start-Transcript .\migration.log

$noDryRun = $True

$wavFormat = Get-ModuleWAVFormat
Write-Output "WAV format: $wavFormat"
Write-Output "No dry run?: $noDryRun"

$csv = Import-Csv -Path ".\Track List - yt-dlp.csv"

$possiblePriorGenres = @{
  'Hardcore' = @(
    'Hard Techno',
    'Hardgroove'
  )
  'Hard Techno' = @(
    'Hardcore',
    'Techno'
  )
  'Hardgroove' = @(
    'Hardcore',
    'Hard Techno'
  )
  'Techno' = @(
    'Hard Techno'
  )
  'DnB' = @(
    'Breakcore',
    'Liquid DnB'
  )
  'Liquid DnB' = @(
    'DnB',
    'Breakcore'
  )
  'Breakcore' = @(
    'DnB',
    'Liquid DnB'
  )
  'Dubstep' = @(
    'Riddim'
  )
  'Riddim' = @(
    'Dubstep'
  )
  # DEPRECATED
  'Deep Dark Minimal' = @(
    'Midtempo',
    'Bass House',
    'Riddim',
    'House'
  )
  'Midtempo' = @(
    'Deep Dark Minimal',
    'Bass House',
    'Riddim'
  )
  'Bass House' = @(
    'Midtempo',
    'Deep Dark Minimal',
    'Riddim',
    'House'
  )
  # DEPRECATED
  'Cyberpunk' = @(
    'Midtempo',
    'Bass House',
    'Riddim'
  )
}

foreach ($song in $csv) {
  # First we need to validate if this is a valid record and skip it if not
  $result = validateRecord -Record $song
  $newSongId = "$($song.Title) by $($song.Artist)"
  if (-Not $result.Okay) {
    Write-Output "Failed to parse record `"$newSongId`": $($result.Result)"
    continue
  }

  # Next, we need to identify duplicate records in the filesystem.
  # The old format of filename will be the md5 sum of the file including genre
  # while the new filename will be the sha256 sum of the file, excluding genre.
  # This poses a problem because we changed the genre for songs alreay in
  # the source data, however we did not record the prior genre information.
  # This essentially means we need to brute force the old filename hash
  # based on our best guess of the prior genre.

  # To do this, we created a rainbow table of sorts where each current genre
  # is mapped to an array of possible prior genres (our best guesses).
  # We will check them all to determine their disposition within the filesystem.

  $newSongIdHash = computeHash -String $newSongId -Algo sha256
  $newGenrePath = "$wavFormat\$($song.Genre)"
  $newSongWebmPath = "webm\$($newSongIdHash).webm"

  if (-Not (Test-Path -Path $newGenrePath -PathType Container)) {
    New-Item -Path $newGenrePath -ItemType Directory
  }
  $newSongPath = "$wavFormat\$($song.Genre)\$($newSongIdHash).$($wavFormat)"

  # Always see if the prior song hash exists for the genre currently assigned
  # to the record.
  $priorGenreCheckList = @($song.Genre)
  if ($song.Genre -in $possiblePriorGenres) {
    $priorGenreCheckList += $possiblePriorGenres[$song.Genre]
  }
  foreach ($possiblePriorGenre in $priorGenreCheckList) {
    # First we search for the record in the old format
    $oldSongId = "$($song.Title) by $($song.Artist) in ($possiblePriorGenre)"
    $possibleOldSongIdHash = computeHash -String $oldSongId -Algo md5
    $possiblePriorPath = "$wavFormat\$possiblePriorGenre\$($possibleOldSongIdHash).$($wavFormat)"
    if (Test-Path -Path $possiblePriorPath) {
      Write-Output "Migrating old formatted record for `"$newSongId`" in filesystem: $possiblePriorPath"
      if ($noDryRun) {
        Move-Item -Path $possiblePriorPath -Destination $newSongPath -Force
      }
    }
    $possiblePriorWebmPath = "webm\$($possibleOldSongIdHash).webm"
    if (Test-Path -Path $possiblePriorWebmPath) {
      Write-Output "Migrating old webm file for `"$newSongId`" in filesystem: $possiblePriorWebmPath"
      if ($noDryRun) {
        Move-Item -Path $possiblePriorWebmPath -Destination $newSongWebmPath -Force
      }
    }
  }
  foreach ($possiblePriorGenre in $possiblePriorGenres[$song.Genre]) {
    # Next we search for it in the new format but still assuming a prior genre
    $possiblePriorPath = "$wavFormat\$possiblePriorGenre\$($newSongIdHash).$($wavFormat)"
    if (Test-Path -Path $possiblePriorPath) {
      Write-Output "Migrating record after genre change for `"$newSongId`" in filesystem: $possiblePriorPath"
      if ($noDryRun) {
        Move-Item -Path $possiblePriorPath -Destination $newSongPath -Force
      }
    }
  }
  $selectResult =  .\ffmpeg.exe -i $newSongPath -f ffmetadata - 2>$null |`
    Select-String -Pattern genre=$($song.Genre) -SimpleMatch -Quiet
  if (-Not $selectResult) {
    Write-Output "$($newSongPath): $newSongId Missing Genre On Disk"
    if ($noDryRun) {
      webmToWav -Record $song -Hash $newSongIdHash
    }
  }
}