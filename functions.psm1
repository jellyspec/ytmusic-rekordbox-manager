$script:LogPath = "logs"
$script:WavFormat = "aiff"
$script:WebmPath = "C:\Users\jelly\Downloads\ytmusic\webm"
$script:OutputPath = "C:\Users\jelly\Downloads\ytmusic\$($script:WAVFormat)"

enum HashAlgo {
  md5 = 1
  sha256 = 2
}

function Get-RBUtilsVars {
  # Create required directories if they don't exist
  if (-Not (Test-Path -Path $script:LogPath -PathType Container)) {
    New-Item -Path $script:LogPath -ItemType Directory
  }
  $vars = @{
    'LogPath' = $script:LogPath
    'WavFormat' = $script:WavFormat
    'WebmPath' = $script:WebmPath
    'OutputPath' = $script:OutputPath
  }
  Write-Warning ($vars | Out-String)
  return $vars
}

function computeHash {
  param (
    [String]$string,
    [HashAlgo]$algo
  )
  switch ($algo) {
    md5 {
      $string | ForEach-Object {
        $stream = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.Write($_)
        $writer.Flush()
        $stream.Position = 0
        Get-FileHash -InputStream $stream -Algorithm MD5 | Select-Object -ExpandProperty Hash
        $writer.Dispose()
        $stream.Dispose()
      }
    }
    sha256 {
      $sha256 = [System.Security.Cryptography.SHA256]::Create()
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($string)
      $hashBytes = $sha256.ComputeHash($bytes)
      ($hashBytes | ForEach-Object { $_.ToString("X2") }) -join ""
    }
    default {
      Throw "Unknown algo type: $algo"
    }
  }
}

function Get-SongHash {
  param (
    [PSCustomObject] $song
  )
  $songId = "$($song.Title) by $($song.Artist)"
  return computeHash -String $songId -Algo sha256
}

function Write-SongHash {
  param (
    [PSCustomObject] $song
  )
  $songIdHash = Get-SongHash $song
  Write-Output "$songIdHash"
}

function Validate-Song {
  param (
    [PSCustomObject] $record
  )
  $result = @{
    'Okay' = $True
    'Record' = $record
    'Hash' = (Get-SongHash $record)
  }
  if ([string]::IsNullOrEmpty($record.Title) `
    -Or [string]::IsNullOrEmpty($record.Artist) `
    -Or [string]::IsNullOrEmpty($record.Genre) `
    -Or [string]::IsNullOrEmpty($record.URL)) {
    $result.Okay = $False
    $result.Result = 'Missing required field(s)'
  }
  if (-Not [string]::IsNullOrEmpty($record.Sync)) {
    $result.Okay = $False
    $result.Result = 'Sync is disabled'
  }
  if (-Not $result.Okay) {
    Write-Warning ($result | Out-String)
  }
  return $result
}

<#
An example of the metadata produced by ffmpeg:
  Name                           Value
  ----                           -----
  artist                         Gonzi
  title                          Turn It Up
  genre                          Hard Techno
  encoder                        Lavf62.4.100
#>
function Get-WavMetadata {
  param (
    [String]$path
  )
  $result = @{}
  $ffmpegResult = .\ffmpeg.exe -i $path -f ffmetadata - 2>$null
  foreach ($line in $ffmpegResult) {
    if ($line -match "^([a-z]+)=(.+)$") {
      $result[$Matches[1]] = $Matches[2]
    }
  }
  return $result
}

function Get-SongFileName {
  param (
    [PSCustomObject] $record
  )
  if (-Not $record.LocalFilePath) {
    $hash = Get-SongHash $record
    return "$($hash).$($script:WavFormat)"
  } else {
    return $record.LocalFilePath
  }
}

function Convert-WebmToWav {
  param (
    [PSCustomObject] $record
  )
  $hash = Get-SongHash $record
  $webmPath = "$($script:WebmPath)\$($hash).webm"
  $outputFile = Get-SongFileName $record
  $outputPath = "$($script:OutputPath)\$outputFile"
  $wavMetadata = Get-WavMetadata -Path $outputPath
  if (-Not ( `
    (Test-Path -Path $outputPath -PathType Leaf) `
    -And $wavMetadata.genre -eq $record.Genre `
    -And $wavMetadata.title -eq $record.Title
  )) {
    Write-Warning "Output file for $hash does not exist or genre was changed (`"$($record.Genre)`" vs `"$($wavMetadata.genre)`" on disk), re-encoding"
    $logPath = "$($script:LogPath)\$($hash).log"
    # TODO: Backfill BPM into aiff metadata
    .\ffmpeg.exe -y -i $webmPath -write_id3v2 1 `
      -metadata "Artist=$($record.Artist)" `
      -metadata "Title=$($record.Title)" `
      -metadata "Genre=$($record.Genre)" `
      $outputPath *>$logPath
    if (-Not $? -And $LASTEXITCODE -ne 0) {
      Write-Warning "ffmpeg encountered an error ($LASTEXITCODE), log is $logPath"
    } else {
      Remove-Item -Path $logPath
    }
  }
}

function Import-TrackListCsv {
  Import-Csv -Path ".\Track List - yt-dlp.csv"
}