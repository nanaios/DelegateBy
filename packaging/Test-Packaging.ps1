param([string]$ArchivePath = (Join-Path $PSScriptRoot '..\artifacts\com.nanaios.delegateby-0.3.0.tgz'))
$ErrorActionPreference = 'Stop'
$archive = (Resolve-Path $ArchivePath).Path
$validator = Join-Path $PSScriptRoot 'Validate-Package.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('delegateby-negative-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force -Path $temp | Out-Null
try {
  & pwsh -NoProfile -File $validator -PackagePath $archive
  if ($LASTEXITCODE -ne 0) { throw 'Baseline packaging validation failed.' }
  function Expect-Failure([string]$Name, [string]$Expected, [scriptblock]$Mutate) {
    $case = Join-Path $temp $Name; New-Item -ItemType Directory -Force -Path (Join-Path $case 'package') | Out-Null
    & tar -xzf $archive -C $case; if ($LASTEXITCODE -ne 0) { throw 'Unable to extract baseline archive.' }
    & $Mutate $case
    $out = Join-Path $case ([IO.Path]::GetFileName($archive)); Push-Location $case
    try { & tar -czf $out package; if ($LASTEXITCODE -ne 0) { throw 'Unable to create tampered archive.' } } finally { Pop-Location }
    $result = @(& pwsh -NoProfile -File $validator -PackagePath $out 2>&1)
    if ($LASTEXITCODE -eq 0 -or ($result -join "`n") -notmatch [regex]::Escape($Expected)) { throw "Negative packaging test did not produce expected error: $Name`n$($result -join "`n")" }
  }
  Expect-Failure 'wrong-unity' 'Invalid UPM manifest' { param($root) $file=Join-Path $root 'package/package.json'; $json=Get-Content $file -Raw | ConvertFrom-Json; $json.unity='2022.3'; $json | ConvertTo-Json | Set-Content $file -Encoding utf8NoBOM }
  Expect-Failure 'rogue-dll' 'Unexpected DLL' { param($root) Set-Content (Join-Path $root 'package/Runtime/Rogue.dll') 'bad' }
  Expect-Failure 'missing-source' 'Missing UPM entry' { param($root) Remove-Item (Join-Path $root 'package/Runtime/DelegateByAttribute.cs') }
  Expect-Failure 'editor-enabled' 'analyzer/editor exclusion' { param($root) $file=Join-Path $root 'package/Analyzers/DelegateBy.Generator.dll.meta'; $text=Get-Content $file -Raw; $text=[regex]::Replace($text,'(?s)(Editor:.*?enabled:) 0','$1 1',1); Set-Content $file $text -Encoding utf8NoBOM }
  Expect-Failure 'any-enabled' 'analyzer/editor exclusion' { param($root) $file=Join-Path $root 'package/Analyzers/DelegateBy.Generator.dll.meta'; $text=Get-Content $file -Raw; $text=[regex]::Replace($text,'(?s)(Any:.*?enabled:) 0','$1 1',1); Set-Content $file $text -Encoding utf8NoBOM }
  $repackRoot = Join-Path $temp 'repack'
  New-Item -ItemType Directory -Path $repackRoot | Out-Null
  & tar -xzf $archive -C $repackRoot
  if ($LASTEXITCODE -ne 0) { throw 'Repack extraction failed.' }
  Get-ChildItem (Join-Path $repackRoot 'package') -Recurse -File | ForEach-Object { $_.LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(1) }
  $repacked = Join-Path $repackRoot ([IO.Path]::GetFileName($archive))
  & tar -czf $repacked -C $repackRoot package
  if ($LASTEXITCODE -ne 0) { throw 'Repack failed.' }
  & (Join-Path $PSScriptRoot 'Compare-Archives.ps1') -Expected $archive -Actual $repacked
  Add-Content (Join-Path $repackRoot 'package/README.md') 'Changed package content'
  & tar -czf $repacked -C $repackRoot package
  if ($LASTEXITCODE -ne 0) { throw 'Changed repack failed.' }
  $mismatchRejected = $false
  try { & (Join-Path $PSScriptRoot 'Compare-Archives.ps1') -Expected $archive -Actual $repacked }
  catch { if ($_.Exception.Message -notmatch 'Archive contents differ') { throw }; $mismatchRejected = $true }
  if (!$mismatchRejected) { throw 'Changed archive was not rejected.' }
  Write-Output 'Packaging tests passed: five invalid packages, equivalent repack, changed-content rejection.'
} finally {
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()); $tempFull = [IO.Path]::GetFullPath($temp)
  if ($tempFull.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) { Remove-Item -LiteralPath $tempFull -Recurse -Force }
}
$global:LASTEXITCODE = 0
