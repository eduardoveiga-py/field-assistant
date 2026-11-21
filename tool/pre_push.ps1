$ErrorActionPreference = 'Stop'

Write-Host '==> Checking Dart formatting...'
dart format --output=none --set-exit-if-changed lib test integration_test
if ($LASTEXITCODE -ne 0) {
  Write-Error "dart format failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}

Write-Host '==> Running flutter analyze...'
$currentPath = (Get-Location).Path
$hasNonAscii = ($currentPath -match '[^\u0000-\u007F]')

if ($hasNonAscii -and ($env:OS -match 'Windows' -or $IsWindows)) {
  # Flutter analyze LSP has an upstream bug parsing Content-Length on Windows paths with non-ASCII characters.
  # Mount a temporary virtual drive letter to execute flutter analyze safely.
  $freeDrive = 68..90 | ForEach-Object { [char]$_ + ':' } | Where-Object { -not (Test-Path $_) } | Select-Object -First 1
  if ($freeDrive) {
    subst $freeDrive $currentPath
    try {
      Push-Location $freeDrive
      flutter analyze
      if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter analyze failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
      }
    } finally {
      Pop-Location
      subst $freeDrive /d
    }
  } else {
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
      Write-Error "flutter analyze failed with exit code $LASTEXITCODE"
      exit $LASTEXITCODE
    }
  }
} else {
  flutter analyze
  if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter analyze failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
  }
}

Write-Host '==> Pre-push checks passed!'
exit 0
