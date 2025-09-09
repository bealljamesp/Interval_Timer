param(
  [Parameter(Mandatory=$true)]
  [string]$NewVersion   # e.g. v11 or 11 or 11.2.3
)

Write-Host "Bumping versions… input = $NewVersion"

# Derive display and semver
$display = $NewVersion
$semver = $NewVersion.TrimStart('v')

# Normalize to X.Y.Z
if ($semver -match '^\d+$') {
  $semver = "$semver.0.0"
} elseif ($semver -match '^\d+\.\d+$') {
  $semver = "$semver.0"
} elseif ($semver -notmatch '^\d+\.\d+\.\d+$') {
  throw "Invalid version format: $NewVersion. Use vNN, NN, NN.NN, or NN.NN.NN"
}

# 1) index.html APP_VERSION
(Get-Content index.html -Raw) `
  -replace 'const APP_VERSION\s*=\s*"(?:v)?\d+(?:\.\d+){0,2}"', "const APP_VERSION = `"$display`"" `
  | Set-Content index.html

# 2) service-worker.js CACHE_VERSION
(Get-Content service-worker.js -Raw) `
  -replace "const CACHE_VERSION\s*=\s*'[^']+'", "const CACHE_VERSION = '$display'" `
  | Set-Content service-worker.js

# 3) package.json version (SemVer only)
(Get-Content package.json -Raw) `
  -replace '"version"\s*:\s*"[^\"]+"', "`"version`": `"$semver`"" `
  | Set-Content package.json

Write-Host "✅ Set APP_VERSION/CACHE_VERSION to $display and package.json version to $semver"
