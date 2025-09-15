<#
bump-version.ps1
Updates:
- package.json "version" (SemVer only, strips any leading "v")
- index.html APP_VERSION constant
- service-worker.js CACHE_VERSION (forces PWA refresh)
- CHANGELOG.md (prepends new section with commit messages since last tag or recent history)

Usage:
  .\bump-version.ps1 -NewVersion v13
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$NewVersion,
  [int]$HistoryFallbackCount = 100
)

function Assert-Git {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git not found on PATH. Install Git or open Git Bash/Developer PowerShell."
  }
}

function Normalize-SemVer([string]$v) {
  $v = $v.Trim()
  if ($v -match '^[vV](.+)$') { $v = $Matches[1] }
  if ($v -match '^\d+$') { return "$v.0.0" }
  if ($v -match '^\d+\.\d+$') { return "$v.0" }
  if ($v -match '^\d+\.\d+\.\d+$') { return $v }
  throw "Invalid version: '$NewVersion'. Use like: 1, 1.2, 1.2.3, or v13."
}

function Read-JsonFile([string]$path) {
  if (-not (Test-Path $path)) { throw "$path not found." }
  return Get-Content $path -Raw | ConvertFrom-Json
}

function Write-Text([string]$path, [string]$content, [switch]$NoNewline=$false) {
  $nn = $NoNewline.IsPresent
  if ($nn) {
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8 -NoNewline
  } else {
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8
  }
}

function Update-PackageJson([string]$path, [string]$semver) {
  $json = Read-JsonFile $path
  $json.version = $semver
  ($json | ConvertTo-Json -Depth 100) | Write-Text -path $path
  Write-Host "ok: package.json version -> $semver"
}

function Update-IndexHtml([string]$path, [string]$display) {
  if (-not (Test-Path $path)) { Write-Host "skip: $path not found"; return }
  $text = Get-Content $path -Raw
  if ($text -notmatch 'const\s+APP_VERSION\s*=') {
    # Insert just after the opening <script type="text/babel">
    $text = $text -replace '(?s)(<script[^>]*type=["'']text/babel["''][^>]*>\s*)',
        "`$1const APP_VERSION = `"$display`";`n"
  } else {
    $text = [regex]::Replace(
      $text,
      'const\s+APP_VERSION\s*=\s*["''][^"'']+["'']',
      "const APP_VERSION = `"$display`"",
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
  }
  Write-Text -path $path -content $text -NoNewline
  Write-Host "ok: index.html APP_VERSION -> $display"
}

function Update-ServiceWorker([string]$path, [string]$display) {
  if (-not (Test-Path $path)) { Write-Host "skip: $path not found"; return }
  $text = Get-Content $path -Raw

  if ($text -notmatch 'CACHE_VERSION') {
    Write-Host "info: CACHE_VERSION not found; adding near top."
    $text = $text -replace '(^\s*(?://.*\R)*)', "`$1const CACHE_VERSION = '$display';`n"
  } else {
    $text = [regex]::Replace(
      $text,
      'CACHE_VERSION\s*=\s*["''][^"'']+["'']',
      "CACHE_VERSION = '$display'",
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
  }

  Write-Text -path $path -content $text -NoNewline
  Write-Host "ok: service-worker.js CACHE_VERSION -> $display"
}

function Get-LastTag() {
  $last = (& git describe --tags --abbrev=0 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($last)) { return $null }
  return $last.Trim()
}

function Get-CommitLines([string]$sinceRef, [int]$fallbackCount) {
  if ($sinceRef) {
    & git log "$sinceRef..HEAD" --pretty=format:"%s"
  } else {
    & git log -n $fallbackCount --pretty=format:"%s"
  }
}

function Update-Changelog([string]$display, [int]$fallbackCount) {
  $changelogPath = "CHANGELOG.md"
  if (-not (Test-Path $changelogPath)) {
    "# Changelog`n`nAll notable changes to this project will be documented in this file.`n" |
      Write-Text -path $changelogPath
  }

  $lastTag = Get-LastTag
  $sinceRef = $lastTag
  $lines = Get-CommitLines -sinceRef $sinceRef -fallbackCount $fallbackCount
  if (-not $lines) {
    Write-Host "info: No commits found for changelog; creating empty section."
    $section = "## $display - $(Get-Date -Format 'yyyy-MM-dd')`n`n- (no notable changes)`n`n"
  } else {
    $bullets = ($lines | ForEach-Object { "- $_" }) -join "`n"
    $section = "## $display - $(Get-Date -Format 'yyyy-MM-dd')`n`n$bullets`n`n"
  }

  $existing = Get-Content $changelogPath -Raw
  ($section + $existing) | Write-Text -path $changelogPath
  Write-Host "ok: CHANGELOG.md updated (prepended section for $display)"
}

# ---------------- main ----------------
try {
  Assert-Git

  $semver  = Normalize-SemVer $NewVersion     # e.g., "12.0.0"
  $display = ($NewVersion.Trim().ToLower().StartsWith('v')) ? $NewVersion.Trim() : "v$NewVersion"

  if (-not (Test-Path "package.json")) { throw "package.json not found in current directory." }

  Update-PackageJson -path "package.json" -semver $semver
  Update-IndexHtml -path "index.html" -display $display
  Update-ServiceWorker -path "service-worker.js" -display $display
  Update-Changelog -display $display -fallbackCount $HistoryFallbackCount

  Write-Host ""
  Write-Host "Next steps:"
  Write-Host "  git add ."
  Write-Host "  git commit -m \"chore(release): $display\""
  Write-Host "  git tag $display"
  Write-Host "  git push && git push --tags"
  Write-Host ""
  Write-Host "Then rebuild desktop:"
  Write-Host "  npm run dist"
}
catch {
  Write-Error $_
  exit 1
}
