param(
  [Parameter(Mandatory=$true)]
  [string]$NewVersion
)

Write-Host "Bumping version to $NewVersion..."

# 1. Update index.html (APP_VERSION)
(Get-Content index.html) -replace 'const APP_VERSION = "v[0-9]+"' , "const APP_VERSION = `"$NewVersion`"" |
  Set-Content index.html

# 2. Update service-worker.js (CACHE_VERSION)
(Get-Content service-worker.js) -replace "const CACHE_VERSION = 'v[0-9]+'", "const CACHE_VERSION = '$NewVersion'" |
  Set-Content service-worker.js

# 3. Update package.json version
(Get-Content package.json) -replace '"version":\s*"[0-9\.]+"' , "`"version`": `"$NewVersion`"" |
  Set-Content package.json

Write-Host "✅ Versions updated to $NewVersion."
