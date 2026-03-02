Set-Location "c:\Users\ionic\Desktop\hireup"

$extensions = @(
  '.dart','.ts','.js','.sql','.kts','.kt','.swift','.m','.mm','.c','.cc','.cpp','.h','.hpp','.cmake',
  '.yaml','.yml','.json','.html','.css','.scss','.gradle','.properties','.xml','.pbxproj','.xcconfig',
  '.plist','.sh','.bat','.ps1'
)

function Get-SegmentStats {
  param(
    [string]$Root,
    [string[]]$ExcludeTokens
  )

  $files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $ext = $_.Extension.ToLowerInvariant()
    if ($extensions -notcontains $ext) { return $false }

    foreach ($token in $ExcludeTokens) {
      if ($_.FullName -like "*$token*") {
        return $false
      }
    }

    return $true
  }

  $lines = 0
  foreach ($file in $files) {
    try {
      $lines += (Get-Content -Path $file.FullName -ErrorAction Stop | Measure-Object -Line).Lines
    } catch {
    }
  }

  return [PSCustomObject]@{
    files = $files.Count
    lines = $lines
  }
}

$db = Get-SegmentStats -Root 'db' -ExcludeTokens @('\node_modules\')
$backend = Get-SegmentStats -Root 'backend' -ExcludeTokens @('\node_modules\','\dist\','\uploads\')

$frontendFiles = Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
  $ext = $_.Extension.ToLowerInvariant()
  if ($extensions -notcontains $ext) { return $false }

  if (
    $_.FullName -like '*\backend\*' -or
    $_.FullName -like '*\db\*' -or
    $_.FullName -like '*\build\*' -or
    $_.FullName -like '*\.dart_tool\*' -or
    $_.FullName -like '*\.git\*' -or
    $_.FullName -like '*\.idea\*' -or
    $_.FullName -like '*\.vscode\*' -or
    $_.FullName -like '*\node_modules\*' -or
    $_.FullName -like '*\dist\*'
  ) {
    return $false
  }

  return $true
}

$frontendLines = 0
foreach ($file in $frontendFiles) {
  try {
    $frontendLines += (Get-Content -Path $file.FullName -ErrorAction Stop | Measure-Object -Line).Lines
  } catch {
  }
}

$result = [PSCustomObject]@{
  db = [PSCustomObject]@{ files = $db.files; lines = $db.lines }
  backend = [PSCustomObject]@{ files = $backend.files; lines = $backend.lines }
  frontend = [PSCustomObject]@{ files = $frontendFiles.Count; lines = $frontendLines }
  total = [PSCustomObject]@{
    files = ($db.files + $backend.files + $frontendFiles.Count)
    lines = ($db.lines + $backend.lines + $frontendLines)
  }
}

$result | ConvertTo-Json -Depth 5 | Set-Content -Path 'loc_count_result.json' -Encoding UTF8
Write-Output 'loc_count_result.json generated'
