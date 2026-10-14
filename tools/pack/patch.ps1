param([ValidateSet('Apply','Revert')][string]$Mode,[string]$InstallDir=$env:XINGHUI_INSTALL_ROOT,[string]$PatchDir)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding
function ReadJson($path) { Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }
function WriteJson($path,$data) { $data | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $path -Encoding UTF8 }
function SafePath($root,$relative) {
  if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains('\') -or $relative.Contains(':') -or $relative.StartsWith('/') -or $relative.Split('/') -contains '..') { throw '补丁路径无效' }
  if ($relative -in @('install-state.json','revert.bat','.patch.lock')) { throw '补丁载荷禁止覆盖控制元数据' }
  if ($relative -match '(^|/)(backup|voices|pet)(/|$)|\.(db|sqlite|sqlite3|key|pem)$|(^|/)auth_token.txt$') { throw '补丁禁止包含用户资产或凭据' }
  $full=[IO.Path]::GetFullPath((Join-Path $root $relative))
  if (-not $full.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '补丁路径越界' }
  $current=$full
  while($current.Length -ge $root.Length) {
    if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '补丁路径不允许链接或重解析点' }
    $current=Split-Path $current -Parent
    if (-not $current) { break }
  }
  return $full
}
function FileHash($path) {
  $stream=[IO.File]::OpenRead($path)
  $algorithm=[Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
  finally { $stream.Dispose();$algorithm.Dispose() }
}
function MatchFile($path,$entry) {
  return (Test-Path -LiteralPath $path -PathType Leaf) -and ((Get-Item -LiteralPath $path).Length -eq $entry.size) -and ((FileHash $path) -eq $entry.sha256)
}
function Idle {
  if (Get-Process -Name xinghui_companion -ErrorAction SilentlyContinue) { throw 'App 正在运行，请先关闭 App 再应用或回退补丁' }
  $python=Join-Path $root 'backend\python\python.exe'
  if (Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $python }) { throw '本地后端正在运行，请先关闭本地后端' }
}
function RestoreFiles($receipt,$folder) {
  foreach($entry in $receipt.files) {
    $target=SafePath $root $entry.path
    if ($entry.existed) {
      $source=SafePath (Join-Path $folder 'files') $entry.path
      if (-not (MatchFile $source $entry)) { throw '回退备份损坏，中止；请保留 backup 目录' }
    }
  }
  foreach($entry in $receipt.files) {
    $target=SafePath $root $entry.path
    if ($entry.existed) {
      New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
      Copy-Item -LiteralPath (SafePath (Join-Path $folder 'files') $entry.path) -Destination $target -Force
      if (-not (MatchFile $target $entry)) { throw '回退文件校验失败' }
    } elseif(Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
  }
  Copy-Item -LiteralPath (Join-Path $folder 'install-state.json') -Destination $statePath -Force
}
try {
  if (-not $InstallDir) { throw '请指定完整解压后的底座目录' }
  $root=[IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw '底座目录不存在' }
  $statePath=Join-Path $root 'install-state.json'
  $state=ReadJson $statePath
  if ($state.schema -ne 1) { throw '底座版本状态无效' }
  Idle
  $lockPath=Join-Path $root '.patch.lock'
  $lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  try {
    if($Mode -eq 'Revert') {
      if (-not $state.patch_id) { throw '当前没有可回退的补丁' }
      if($state.patch_id -notmatch '^m[0-9]+-b[0-9]+$') { throw '批次标识无效' }
      $folder=Join-Path $root ('backup\'+$state.patch_id)
      $receipt=ReadJson (Join-Path $folder 'receipt.json')
      if ($receipt.patch_id -ne $state.patch_id -or $receipt.base_git_hash -ne $state.base_git_hash) { throw '回退链不匹配' }
      RestoreFiles $receipt $folder
      Write-Output ('已回退批次 '+$state.patch_id)
    } else {
      if (-not $PatchDir) { $PatchDir=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')) }
      $PatchDir=[IO.Path]::GetFullPath($PatchDir).TrimEnd('\')
      if (-not (Test-Path -LiteralPath (Join-Path $PatchDir 'manifest.json'))) {
        if ($env:XINGHUI_PATCH_TEST) { throw '补丁清单不存在' }
        $PatchDir=[IO.Path]::GetFullPath((Read-Host '补丁解压目录')).TrimEnd('\')
      }
      $manifest=ReadJson (Join-Path $PatchDir 'manifest.json')
      if ($manifest.schema -ne 1 -or $manifest.patch_id -notmatch '^m[0-9]+-b[0-9]+$') { throw '补丁清单格式无效' }
      if ($manifest.base_git_hash -ne $state.base_git_hash) { throw '底座版本不匹配，中止' }
      if ($manifest.previous_patch -ne $state.patch_id) { throw '补丁链不匹配，中止；不能跳批或重复应用' }
      $files=@($manifest.files)
      if ($files.Count -ne $manifest.file_count) { throw '补丁文件数不一致，中止' }
      $seen=@{}
      $payload=Join-Path $PatchDir 'payload'
      $actual=@(Get-ChildItem -LiteralPath $payload -File -Recurse)
      if ($actual.Count -ne $manifest.file_count) { throw '补丁载荷文件数不一致，中止' }
      foreach($entry in $files) {
        $source=SafePath $payload $entry.path
        $target=SafePath $root $entry.path
        if ($seen.ContainsKey($entry.path)) { throw '补丁包含重复路径' };$seen[$entry.path]=$true
        if (-not (MatchFile $source $entry)) { throw '补丁文件大小或哈希不一致，中止' }
        if ($entry.before_sha256) {
          if (-not (Test-Path -LiteralPath $target) -or (FileHash $target) -ne $entry.before_sha256) { throw '待替换文件与底座不匹配，中止' }
        } elseif(Test-Path -LiteralPath $target) { throw '新增文件已有同名内容，中止' }
      }
      $folder=Join-Path $root ('backup\'+$manifest.patch_id)
      if(Test-Path -LiteralPath $folder) { throw '本批备份已存在，中止，禁止覆盖旧备份' }
      New-Item -ItemType Directory -Path $folder | Out-Null
      $saved=@()
      foreach($entry in $files) {
        $target=SafePath $root $entry.path
        $existed=Test-Path -LiteralPath $target
        $size=0;$hash=$null
        if($existed) {
          $size=(Get-Item -LiteralPath $target).Length;$hash=(FileHash $target)
          $destination=SafePath (Join-Path $folder 'files') $entry.path
          New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
          Copy-Item -LiteralPath $target -Destination $destination
        }
        $saved+=@{path=$entry.path;existed=$existed;size=$size;sha256=$hash}
      }
      Copy-Item -LiteralPath $statePath -Destination (Join-Path $folder 'install-state.json')
      $receipt=@{patch_id=$manifest.patch_id;base_git_hash=$manifest.base_git_hash;files=$saved}
      WriteJson (Join-Path $folder 'receipt.json') $receipt
      try {
        foreach($entry in $files) {
          $target=SafePath $root $entry.path
          New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
          Copy-Item -LiteralPath (SafePath $payload $entry.path) -Destination $target -Force
        }
        $verified=0
        foreach($entry in $files) { if(-not (MatchFile (SafePath $root $entry.path) $entry)) { throw '覆盖后大小或哈希不一致，中止并回退' };$verified++ }
        if ($verified -ne $manifest.file_count) { throw '覆盖后文件数不一致，中止并回退' }
        $next=@{schema=1;module=$manifest.module;batch=$manifest.batch;git_hash=$manifest.git_hash;base_git_hash=$state.base_git_hash;patch_id=$manifest.patch_id}
        WriteJson $statePath $next
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'revert.bat') -Destination (Join-Path $root 'revert.bat') -Force
      } catch { RestoreFiles $receipt $folder;throw }
      Write-Output ('补丁已应用，版本 '+$manifest.patch_id)
    }
  } finally { $lock.Dispose() }
  exit 0
} catch { Write-Output ('补丁操作中止：'+$_.Exception.Message);exit 1 }
