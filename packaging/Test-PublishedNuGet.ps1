param(
  [Parameter(Mandatory = $true)][string]$PackagePath,
  [Parameter(Mandatory = $true)][string]$Owner,
  [string]$OutputPath = $env:GITHUB_OUTPUT
)
$ErrorActionPreference = 'Stop'
$local = (Resolve-Path $PackagePath).Path
$token = $env:GH_TOKEN
$actor = $env:GITHUB_ACTOR
if ([string]::IsNullOrWhiteSpace($token) -or [string]::IsNullOrWhiteSpace($actor)) { throw 'GH_TOKEN and GITHUB_ACTOR are required.' }
if ($Owner -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') { throw 'Invalid GitHub owner.' }
$service = "https://nuget.pkg.github.com/$Owner/index.json"
$temp = Join-Path ([IO.Path]::GetTempPath()) ('delegateby-published-' + [guid]::NewGuid().ToString('N'))
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempFull = [IO.Path]::GetFullPath($temp)
if (!$tempFull.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary path.' }
function Get-AuthHeaders {
  $bytes = [Text.Encoding]::UTF8.GetBytes("${actor}:${token}")
  @{ Authorization = 'Basic ' + [Convert]::ToBase64String($bytes); Accept = 'application/json' }
}
function Assert-GitHubNuGetUrl([string]$uri) {
  $parsed = [Uri]$uri
  if ($parsed.Scheme -ne 'https' -or $parsed.Host -ne 'nuget.pkg.github.com') { throw "Unexpected package feed URL: $($parsed.Host)" }
}
try {
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead($local)
  try {
    $nuspecEntry = $zip.Entries | Where-Object { $_.FullName -match '\.nuspec$' } | Select-Object -First 1
    if (!$nuspecEntry) { throw 'Local package has no nuspec.' }
    $reader = [IO.StreamReader]::new($nuspecEntry.Open())
    try { [xml]$nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
  } finally { $zip.Dispose() }
  $metadata = $nuspec.package.metadata
  $id = [string]$metadata.id; $version = [string]$metadata.version
  if (!$id -or !$version) { throw 'Local nuspec has no package id/version.' }
  $headers = Get-AuthHeaders
  $index = Invoke-WebRequest -Uri $service -Headers $headers -SkipHttpErrorCheck
  if ($index.StatusCode -ne 200) { throw "NuGet service index returned HTTP $($index.StatusCode)." }
  $resources = ($index.Content | ConvertFrom-Json).resources
  $resource = $resources | Where-Object { $_.'@type' -match '^PackageBaseAddress/3\.0\.0' } | Select-Object -First 1
  if (!$resource) { throw 'NuGet service index has no PackageBaseAddress resource.' }
  Assert-GitHubNuGetUrl $resource.'@id'
  $base = $resource.'@id'.TrimEnd('/')
  $remoteUrl = "$base/$($id.ToLowerInvariant())/$($version.ToLowerInvariant())/$($id.ToLowerInvariant()).$($version.ToLowerInvariant()).nupkg"
  Assert-GitHubNuGetUrl $remoteUrl
  $response = Invoke-WebRequest -Uri $remoteUrl -Headers $headers -OutFile (Join-Path $temp 'published.nupkg') -SkipHttpErrorCheck -PassThru
  if ($response.StatusCode -eq 404) {
    if ($OutputPath) { Add-Content -LiteralPath $OutputPath -Value 'exists=false' }
    Write-Output 'Published NuGet package is absent.'
    exit 0
  }
  if ($response.StatusCode -ne 200) { throw "NuGet package lookup returned HTTP $($response.StatusCode)." }
  & (Join-Path $PSScriptRoot 'Compare-Archives.ps1') -Expected $local -Actual (Join-Path $temp 'published.nupkg')
  if ($OutputPath) { Add-Content -LiteralPath $OutputPath -Value 'exists=true' }
  Write-Output 'Published NuGet package matches the local artifact.'
} finally {
  if (Test-Path -LiteralPath $tempFull) { Remove-Item -LiteralPath $tempFull -Recurse -Force }
}
