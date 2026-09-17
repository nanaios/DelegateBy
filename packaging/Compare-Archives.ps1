param(
  [Parameter(Mandatory=$true)][string]$Expected,
  [Parameter(Mandatory=$true)][string]$Actual
)
$ErrorActionPreference = 'Stop'
$left = (Resolve-Path $Expected).Path
$right = (Resolve-Path $Actual).Path
if ([IO.Path]::GetExtension($left) -ne [IO.Path]::GetExtension($right)) {
  throw 'Archive formats must match.'
}
& (Join-Path $PSScriptRoot 'Validate-Package.ps1') -PackagePath $left | Out-Null
& (Join-Path $PSScriptRoot 'Validate-Package.ps1') -PackagePath $right | Out-Null
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('delegateby-compare-' + [guid]::NewGuid().ToString('N'))
function Expand-ArchiveContent([string]$path, [string]$destination) {
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  if ($path -match '\.tgz$') {
    & tar -xzf $path -C $destination
    if ($LASTEXITCODE -ne 0) { throw "Unable to extract $path" }
  } else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($path, $destination)
  }
}
function Get-ContentMap([string]$root, [bool]$upm) {
  $map = @{}
  Get-ChildItem $root -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($root.Length + 1).Replace('\','/')
    # OPC bookkeeping uses fresh IDs/timestamps on each dotnet pack. Compare
    # the nuspec and every payload file, excluding only that ZIP bookkeeping.
    if (!$upm -and ($relative -match '^(_rels/\.rels$|package/services/metadata/core-properties/[^/]+\.psmdcp$|\[Content_Types\]\.xml$)')) { return }
    $map[$relative] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  }
  return $map
}
try {
  $a = Join-Path $tmp 'a'; $b = Join-Path $tmp 'b'
  Expand-ArchiveContent $left $a; Expand-ArchiveContent $right $b
  $upm = $left -match '\.tgz$'
  $ma = Get-ContentMap $a $upm; $mb = Get-ContentMap $b $upm
  $names = @($ma.Keys + $mb.Keys | Sort-Object -Unique)
  foreach ($name in $names) {
    if (!$ma.ContainsKey($name) -or !$mb.ContainsKey($name) -or $ma[$name] -ne $mb[$name]) { throw "Archive contents differ at $name" }
  }
  Write-Output 'Archives contain matching normalized content.'
} finally {
  $resolved = [IO.Path]::GetFullPath($tmp)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (!$resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup path.' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
