param(
  [Parameter(Mandatory=$true)][string]$Version,
  [string]$OutputDirectory = "artifacts",
  [string]$RepositoryRoot = (Join-Path $PSScriptRoot "..")
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $RepositoryRoot).Path
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') { throw "Invalid SemVer: $Version" }
$stage = Join-Path ([IO.Path]::GetTempPath()) ("delegateby-upm-" + [guid]::NewGuid().ToString('N'))
$package = Join-Path $stage 'package'
try {
New-Item -ItemType Directory -Force -Path (Join-Path $package 'Runtime'), (Join-Path $package 'Analyzers') | Out-Null
Copy-Item (Join-Path $root 'packaging/upm/package.json') (Join-Path $package 'package.json')
Copy-Item (Join-Path $root 'packaging/upm/Runtime/DelegateBy.Attributes.asmdef') (Join-Path $package 'Runtime/DelegateBy.Attributes.asmdef')
Copy-Item (Join-Path $root 'src/DelegateBy.Attributes/DelegateByAttribute.cs') (Join-Path $package 'Runtime/DelegateByAttribute.cs')
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $package 'LICENSE')
Copy-Item (Join-Path $root 'README.md') (Join-Path $package 'README.md')
$jsonPath = Join-Path $package 'package.json'
$json = Get-Content $jsonPath -Raw | ConvertFrom-Json
$json.version = $Version
$json | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding utf8NoBOM
$dll = Join-Path $root 'src/DelegateBy.Generator/bin/Release/netstandard2.0/DelegateBy.Generator.dll'
if (!(Test-Path $dll)) { throw "Build the generator before packaging: $dll" }
Copy-Item $dll (Join-Path $package 'Analyzers/DelegateBy.Generator.dll')
$meta = @(
  "fileFormatVersion: 2",
  "guid: 5e6c7609c29e4a20b9b4f6b8d9b72a2a",
  "labels:",
  "- RoslynAnalyzer",
  "PluginImporter:",
  "  serializedVersion: 2",
  "  isPreloaded: 0",
  "  isOverridable: 1",
  "  isExplicitlyReferenced: 0",
  "  validateReferences: 1",
  "  platformData:",
  "  - first:",
  "      Any:",
  "    second:",
  "      enabled: 0",
  "      settings: {}",
  "  - first:",
  "      Editor: Editor",
  "    second:",
  "      enabled: 0",
  "      settings: {}",
  "  - first:",
  "      Windows Store Apps:",
  "    second:",
  "      enabled: 0",
  "      settings: {}",
  "  userData: ",
  "  assetBundleName: ",
  "  assetBundleVariant: "
) -join "`n"
Set-Content (Join-Path $package 'Analyzers/DelegateBy.Generator.dll.meta') ($meta + "`n") -Encoding utf8NoBOM
$runtimeAsmdefMeta = @(
  "fileFormatVersion: 2",
  "guid: 9e0d7c7f5f2e4b2a8d9b6c1e3a4f5071"
) -join "`n"
Set-Content (Join-Path $package 'Runtime/DelegateBy.Attributes.asmdef.meta') ($runtimeAsmdefMeta + "`n") -Encoding utf8NoBOM
$attributeMeta = @(
  "fileFormatVersion: 2",
  "guid: 3c8f3f81c6f04e9aa0e3c0d0c8f5c112",
  "MonoImporter:",
  "  externalObjects: {}",
  "  serializedVersion: 2",
  "  defaultReferences: []",
  "  executionOrder: 0",
  "  icon: {instanceID: 0}",
  "  userData: ",
  "  assetBundleName: ",
  "  assetBundleVariant: "
) -join "`n"
Set-Content (Join-Path $package 'Runtime/DelegateByAttribute.cs.meta') ($attributeMeta + "`n") -Encoding utf8NoBOM
$textMeta = @(
  "fileFormatVersion: 2",
  "guid: 7b1f75d2e7f845f9b6cf0c6cb2ea6f31",
  "TextScriptImporter:",
  "  externalObjects: {}",
  "  userData: ",
  "  assetBundleName: ",
  "  assetBundleVariant: "
) -join "`n"
Set-Content (Join-Path $package 'package.json.meta') ($textMeta + "`n") -Encoding utf8NoBOM
Set-Content (Join-Path $package 'README.md.meta') ($textMeta.Replace('7b1f75d2e7f845f9b6cf0c6cb2ea6f31','d5b0f0d7c5e54e2e8e8a7e0bd0d9b742') + "`n") -Encoding utf8NoBOM
Set-Content (Join-Path $package 'LICENSE.meta') ($textMeta.Replace('7b1f75d2e7f845f9b6cf0c6cb2ea6f31','f2d6e3a4c8f94e91a8d0d2f3b4c5e617') + "`n") -Encoding utf8NoBOM
$folderMeta = @{
  (Join-Path $package 'Runtime') = '2b5e2f8a9a4a47d9b2c4e3f0a1b68732'
  (Join-Path $package 'Analyzers') = '4d7f3b9c1e5a48f0b2c6d8e9a3f70451'
}
foreach ($folder in $folderMeta.Keys) {
  Set-Content ($folder + '.meta') ("fileFormatVersion: 2`nguid: $($folderMeta[$folder])`nfolderAsset: yes`nDefaultImporter:`n  externalObjects: {}`n  userData: `n  assetBundleName: `n  assetBundleVariant: `n") -Encoding utf8NoBOM
}
$asmdefMeta = @(
  "fileFormatVersion: 2",
  "guid: 9e0d7c7f5f2e4b2a8d9b6c1e3a4f5071",
  "AssemblyDefinitionImporter:",
  "  externalObjects: {}",
  "  userData: ",
  "  assetBundleName: ",
  "  assetBundleVariant: "
) -join "`n"
Set-Content (Join-Path $package 'Runtime/DelegateBy.Attributes.asmdef.meta') ($asmdefMeta + "`n") -Encoding utf8NoBOM
$out = (Resolve-Path (New-Item -ItemType Directory -Force -Path (Join-Path $root $OutputDirectory))).Path
$archive = Join-Path $out ("com.nanaios.delegateby-$Version.tgz")
if (Get-Command tar -ErrorAction SilentlyContinue) {
  Push-Location $stage
  try {
    # Windows bsdtar does not implement GNU reproducibility switches. The
    # publish workflow compares extracted package contents on reruns, so
    # archive metadata never decides whether an existing version is reused.
    & tar -czf $archive package
    if ($LASTEXITCODE -ne 0) { throw "tar failed" }
  }
  finally { Pop-Location }
} else { throw 'tar is required to create UPM archives' }
Write-Output $archive
} finally {
  $resolved = [IO.Path]::GetFullPath($stage)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (!$resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup path.' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
