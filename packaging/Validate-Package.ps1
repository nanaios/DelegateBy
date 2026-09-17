param([Parameter(Mandatory=$true)][string]$PackagePath)
$ErrorActionPreference = 'Stop'
$path = (Resolve-Path $PackagePath).Path
function Assert-Safe([string[]]$Names) {
  if ($Names | Where-Object { $_ -match '(^|/)\.\.?(/|$)' -or $_ -match '^/' }) { throw 'Archive contains an unsafe path.' }
}
if ([IO.Path]::GetExtension($path) -eq '.nupkg') {
  Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip = [IO.Compression.ZipFile]::OpenRead($path)
  try {
    $entries = @($zip.Entries | ForEach-Object FullName); Assert-Safe $entries
    $required = @('README.md','DelegateBy.nuspec','analyzers/dotnet/cs/DelegateBy.Generator.dll','lib/netstandard2.0/DelegateBy.Attributes.dll')
    foreach ($name in $required) { if ($entries -notcontains $name) { throw "Missing NuGet entry: $name" } }
    $nuspec = $zip.Entries | Where-Object FullName -eq 'DelegateBy.nuspec'; $reader=[IO.StreamReader]::new($nuspec.Open()); try {[xml]$xml=$reader.ReadToEnd()} finally {$reader.Dispose()}
    if ($xml.package.metadata.developmentDependency -eq 'true') { throw 'developmentDependency must not be true.' }
    if ($entries | Where-Object { $_ -match 'Microsoft.CodeAnalysis|System.Collections.Immutable' }) { throw 'Roslyn dependencies must not be bundled.' }
    foreach ($name in $entries) { if ($name -match '\.dll$' -and $name -notin @('analyzers/dotnet/cs/DelegateBy.Generator.dll','lib/netstandard2.0/DelegateBy.Attributes.dll')) { throw "Unexpected NuGet DLL: $name" } }
  } finally { $zip.Dispose() }
} elseif ([IO.Path]::GetExtension($path) -eq '.tgz') {
  if (!(Get-Command tar -ErrorAction SilentlyContinue)) { throw 'tar is required.' }
  $temp = Join-Path ([IO.Path]::GetTempPath()) ('delegateby-validate-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force -Path $temp | Out-Null
  try {
    $listing = @(& tar -tzf $path); if ($LASTEXITCODE -ne 0) { throw 'Invalid tgz archive.' }; Assert-Safe $listing
    & tar -xzf $path -C $temp; if ($LASTEXITCODE -ne 0) { throw 'Unable to extract tgz archive.' }
    $package = Join-Path $temp 'package'; if (!(Test-Path $package)) { throw 'UPM archive must contain package/.' }
    if ($listing | Where-Object { $_ -notmatch '^package/' }) { throw 'UPM entries must be under package/.' }
    foreach ($required in @('package/package.json','package/LICENSE','package/README.md','package/Runtime/DelegateByAttribute.cs','package/Runtime/DelegateByAttribute.cs.meta','package/Runtime/DelegateBy.Attributes.asmdef','package/Runtime/DelegateBy.Attributes.asmdef.meta','package/Analyzers/DelegateBy.Generator.dll','package/Analyzers/DelegateBy.Generator.dll.meta')) { if ($listing -notcontains $required) { throw "Missing UPM entry: $required" } }
    $manifest = Get-Content (Join-Path $package 'package.json') -Raw | ConvertFrom-Json
    $expectedVersion = ([IO.Path]::GetFileNameWithoutExtension($path) -replace '^com\.nanaios\.delegateby-','')
    if ($manifest.name -ne 'com.nanaios.delegateby' -or $manifest.unity -ne '6000.0' -or $manifest.version -ne $expectedVersion) { throw 'Invalid UPM manifest name, version, or Unity version.' }
    $asmdef = Get-Content (Join-Path $package 'Runtime/DelegateBy.Attributes.asmdef') -Raw | ConvertFrom-Json
    if ($asmdef.name -ne 'DelegateBy.Attributes' -or !$asmdef.autoReferenced -or !$asmdef.noEngineReferences) { throw 'Invalid UPM asmdef.' }
    $dll = @(Get-ChildItem $package -Recurse -File -Filter '*.dll'); if ($dll.Count -ne 1 -or $dll[0].Name -ne 'DelegateBy.Generator.dll') { throw 'UPM contains unexpected DLLs.' }
    $metaPath = $dll[0].FullName + '.meta'; if (!(Test-Path $metaPath)) { throw 'Generator .meta is missing.' }; $meta = Get-Content $metaPath -Raw
    foreach ($platform in @('Any', 'Editor')) {
      if ($meta -notmatch "(?m)^      ${platform}:[^\r\n]*\r?\n    second:\r?\n      enabled: 0\s*$") {
        throw 'Generator meta lacks analyzer/editor exclusion.'
      }
    }
    if ($meta -notmatch '(?m)^- RoslynAnalyzer\s*$' -or $meta -match '(?m)^\s+enabled: [1-9]') { throw 'Generator meta lacks analyzer/editor exclusion.' }
    $expectedGuids = @{
      'DelegateBy.Generator.dll.meta' = '5e6c7609c29e4a20b9b4f6b8d9b72a2a'
      'DelegateBy.Attributes.asmdef.meta' = '9e0d7c7f5f2e4b2a8d9b6c1e3a4f5071'
      'DelegateByAttribute.cs.meta' = '3c8f3f81c6f04e9aa0e3c0d0c8f5c112'
      'Runtime.meta' = '2b5e2f8a9a4a47d9b2c4e3f0a1b68732'
      'Analyzers.meta' = '4d7f3b9c1e5a48f0b2c6d8e9a3f70451'
      'package.json.meta' = '7b1f75d2e7f845f9b6cf0c6cb2ea6f31'
      'README.md.meta' = 'd5b0f0d7c5e54e2e8e8a7e0bd0d9b742'
      'LICENSE.meta' = 'f2d6e3a4c8f94e91a8d0d2f3b4c5e617'
    }
    $metas = @(Get-ChildItem $package -Recurse -File -Filter '*.meta'); $guids = @($metas | ForEach-Object { if ((Get-Content $_.FullName -Raw) -match '(?m)^guid: ([0-9a-f]+)') { $Matches[1] } }); if ($guids.Count -ne $metas.Count -or ($guids | Sort-Object -Unique).Count -ne $guids.Count) { throw 'UPM metas must contain unique GUIDs.' }
    foreach ($metaName in $expectedGuids.Keys) { $metaFile = $metas | Where-Object Name -eq $metaName; if ($null -eq $metaFile -or (Get-Content $metaFile.FullName -Raw) -notmatch "(?m)^guid: $($expectedGuids[$metaName])\r?$") { throw "Unexpected GUID for $metaName." } }
    if (Get-ChildItem $package -Recurse -File | Where-Object { $_.FullName -match '(^|[/\\])(obj|bin)([/\\])|\.pdb$' }) { throw 'UPM contains build artifacts.' }
  } finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()); $tempFull = [IO.Path]::GetFullPath($temp)
    if ($tempFull.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) { Remove-Item -LiteralPath $tempFull -Recurse -Force }
  }
} else { throw "Unsupported package type: $path" }
Write-Output "Package validation passed: $path"
