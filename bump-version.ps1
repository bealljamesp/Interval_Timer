param(
  [Parameter(Mandatory = $true)]
  [string]$NewVersion,      # accepts v12, 12, 12.3, 12.3.4, v12.3.4
  [switch]$NoCommit,
  [switch]$NoTag
)

function Normalize-SemVer([string]$v) {
  $display = $v
  if ($display -notmatch '^[vV]') { $display = "v$display" }

  $core = $v -replace '^[vV]', ''
  if ($core -match '^\d+$') {
    $core = "$core.0.0"
  } elseif ($core -match '^\d+\.\d+$') {
    $core = "$core.0"
  } elseif ($core -notmatch '^\d+\.\d+\.\d+$') {
    throw "NewVersion '$v' is not a valid SemVer (use v12, 12, 12.3, 12.3.4, or v12.3.4)."
  }

  return @{ Display = $display; SemVer = $core }
}

function Update-IndexHtml([string]$path, [string]$display) {
  if (-not (Test-Path $path)) { Write-Host "skip: $path not found"; return }
  $text = Get-Content $path -Raw
  if ($text -notmatch 'const\s+APP_VERSION\s*=\s*["'']') {
    Write-Host "info: APP_VERSION not found; inserting near top of script."
    $text = $text -replace '(<script[^>]*type="text/babel"[^>]*>\s*)', "`$1`n    const APP_VERSION = `"$display`";`n"
  } else {
    $text = [regex]::Replace(
      $text,
      'const\s+APP_VERSION\s*=\s*["''][^"'']+["'']\s*;',
      "const APP_VERSION = `"$display`";",
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
  }
  Set-Content $path $text -NoNewline
  Write-Host "ok: index.html APP_VERSION -> $display"
}

function Update-ServiceWorker([string]$path, [string]$display) {
  if (-not (Test-Path $path)) { Write-Host "skip: $path not found"; return }
  $text = Get-Content $path -Raw
  if ($text -notmatch 'CACHE_VERSION') {
    Write-Host "info: CACHE_VERSION not found; adding near top."
    $text = $text -replace '(^\s*//[^\n]*\n)', "`$1const CACHE_VERSION = '$display';`n"
  } else {
    $text = [regex]::Replace(
      $text,
      'CACHE_VERSION\s*=\s*["''][^"'']+["'']',
      "CACHE_VERSION = '$display'",
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
  }
  Set-Content $path $text -NoNewline
  Write-Host "ok: service-worker.js CACHE_VERSION -> $display"
}

function Update-PackageJson([string]$path, [string]$semver) {
  if (-not (Test-Path $path)) { Write-Host "skip: $path not found"; return }
  $json = Get-Content $path -Raw | ConvertFrom-Json
  $json.version = $semver
  $json | ConvertTo-Json -Depth 20 | Set-Content $path -NoNewline
  Write-Host "ok: package.json version -> $semver"
}

function Get-LastTag() {
  $tag = (& git describe --tags --abbrev=0 2>$null)
  if ($LASTEXITCODE -ne 0) { return $null }
  return $tag
}

function Build-ChangelogSection([string]$sinceRef, [string]$version, [datetime]$date) {
  $range = "HEAD"
  if ($sinceRef) { $range = "$sinceRef..HEAD" }

  $lines = & git log $range --pretty="%s"
  if ($LASTEXITCODE -ne 0) { throw "git log failed" }

  $groups = @{
    feat     = New-Object System.Collections.Generic.List[string]
    fix      = New-Object System.Collections.Generic.List[string]
    perf     = New-Object System.Collections.Generic.List[string]
    refactor = New-Object System.Collections.Generic.List[string]
    docs     = New-Object System.Collections.Generic.List[string]
    chore    = New-Object System.Collections.Generic.List[string]
    build    = New-Object System.Collections.Generic.List[string]
    ci       = New-Object System.Collections.Generic.List[string]
    style    = New-Object System.Collections.Generic.List[string]
    test     = New-Object System.Collections.Generic.List[string]
    revert   = New-Object System.Collections.Generic.List[string]
    other    = New-Object System.Collections.Generic.List[string]
  }

  foreach ($s in $lines) {
    $m = [regex]::Match($s, '^(?<type>\w+)(\([^)]+\))?(!)?:\s*(?<msg>.+)$')
    if ($m.Success) {
      $t   = $m.Groups['type'].Value.ToLower()
      $msg = $m.Groups['msg'].Value
      if (-not $groups.ContainsKey($t)) { $t = 'other' }
      $groups[$t].Add($msg)
    } else {
      $groups['other'].Add($s)
    }
  }

  $sb = New-Object System.Text.StringBuilder
  $dateStr = $date.ToString('yyyy-MM-dd')
  [void]$sb.AppendLine("## $version - $dateStr")

  $order = @('feat','fix','perf','refactor','docs','test','build','ci','style','chore','revert','other')
  foreach ($t in $order) {
    if ($groups[$t].Count -gt 0) {
      $title = 'Other'
      switch ($t) {
        'feat'     { $title = 'Features' }
        'fix'      { $title = 'Bug Fixes' }
        'perf'     { $title = 'Performance' }
        'refactor' { $title = 'Refactors' }
        'docs'     { $title = 'Docs' }
        'test'     { $title = 'Tests' }
        'build'    { $title = 'Build' }
        'ci'       { $title = 'CI' }
        'style'    { $title = 'Style' }
        'chore'    { $title = 'Chores' }
        'revert'   { $title = 'Reverts' }
      }
      [void]$sb.AppendLine("### $title")
      foreach ($msg in $groups[$t]) { [void]$sb.AppendLine("- $msg") }
      [void]$sb.AppendLine()
    }
  }

  if (-not $lines -or $lines.Count -eq 0) {
    [void]$sb.AppendLine("- minor maintenance`n")
  }

  return $sb.ToString()
}

function Prepend-ToFile([string]$path, [string]$content, [string]$header = "# Changelog`n`n") {
  if (Test-Path $path) {
    $old = Get-Content $path -Raw
    ($content + $old) | Set-Content $path -NoNewline
  } else {
    ($header + $content) | Set-Content $path -NoNewline
  }
}

# --- MAIN ---
$ver = Normalize-SemVer $NewVersion
$display = $ver.Display
$semver  = $ver.SemVer

Write-Host "Bumping to: UI=$display  package.json=$semver" -ForegroundColor Cyan

Update-IndexHtml     -path "index.html"        -display $display
Update-ServiceWorker -path "service-worker.js" -display $display
Update-PackageJson   -path "package.json"      -semver  $semver

$lastTag = Get-LastTag
$section = Build-ChangelogSection -sinceRef $lastTag -version $semver -date (Get-Date)
Prepend-ToFile -path "CHANGELOG.md" -content $section

if (-not $NoCommit) {
  & git add index.html service-worker.js package.json CHANGELOG.md | Out-Null
  & git commit -m "chore(release): v$semver"
  if ($LASTEXITCODE -ne 0) { Write-Host "warn: git commit failed or nothing to commit." -ForegroundColor Yellow }
}

if (-not $NoTag) {
  & git tag -a "v$semver" -m "Release v$semver"
  if ($LASTEXITCODE -ne 0) { Write-Host "warn: git tag failed (tag may already exist)." -ForegroundColor Yellow }
}

Write-Host "Done. Next:" -ForegroundColor Green
Write-Host "  git push --follow-tags" -ForegroundColor Green
Write-Host "  (Optional) gh release create v$semver -t ""Exercise Timer v$semver"" --generate-notes" -ForegroundColor Green
