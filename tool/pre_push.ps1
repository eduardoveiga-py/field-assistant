$ErrorActionPreference = 'Stop'

Write-Host '==> Checking Dart formatting...'
dart format --output=none --set-exit-if-changed lib test integration_test
if ($LASTEXITCODE -ne 0) {
  Write-Error "dart format failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}

Write-Host '==> Running flutter analyze...'
flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Error "flutter analyze failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}

Write-Host '==> Pre-push checks passed!'
exit 0
