param([Parameter(Mandatory=$true)][string]$PackagePath)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path $PackagePath).Path
if ([IO.Path]::GetExtension($package) -ne '.nupkg') { throw 'Smoke-NuGet requires a .nupkg file.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($package)
try {
  $nuspecEntry = $archive.Entries | Where-Object FullName -match '\.nuspec$' | Select-Object -First 1
  if ($null -eq $nuspecEntry) { throw 'The package has no nuspec.' }
  $reader = [IO.StreamReader]::new($nuspecEntry.Open()); try { [xml]$nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
  $version = [string]$nuspec.package.metadata.version
  if ([string]::IsNullOrWhiteSpace($version)) { throw 'The nuspec has no version.' }
} finally { $archive.Dispose() }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('delegateby-smoke-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  $project = Join-Path $temp 'Smoke.csproj'; $source = Join-Path $temp 'Program.cs'; $packages = Join-Path $temp 'packages'; $config = Join-Path $temp 'NuGet.config'
  $feed = (Split-Path $package -Parent).Replace('&','&amp;')
  "<configuration><packageSources><clear /><add key=`"local`" value=`"$feed`" /></packageSources></configuration>" | Set-Content $config -Encoding utf8NoBOM
  "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><LangVersion>9.0</LangVersion></PropertyGroup><ItemGroup><PackageReference Include=`"DelegateBy`" Version=`"$version`" /></ItemGroup></Project>" | Set-Content $project -Encoding utf8NoBOM
  @('using DelegateBy;','public interface IGreeter { string Greet(string name); }','public sealed class Greeter : IGreeter { public string Greet(string name) => "Hello " + name; }','[DelegateBy(nameof(_greeter))] public partial class Service { private readonly IGreeter _greeter = new Greeter(); public static void Main() => System.Console.WriteLine(new Service().Greet("smoke")); }') -join "`n" | Set-Content $source -Encoding utf8NoBOM
  & dotnet restore $project --configfile $config --packages $packages --force-evaluate
  if ($LASTEXITCODE -ne 0) { throw 'NuGet smoke restore failed.' }
  $output = @(& dotnet run --project $project --configuration Release --no-restore)
  if ($LASTEXITCODE -ne 0) { throw 'NuGet smoke execution failed.' }
  if (($output -join "`n") -notmatch '(?m)^Hello smoke\s*$') { throw "NuGet smoke output was unexpected: $($output -join ' ')" }
  Write-Output "NuGet smoke passed for $version."
} finally {
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()); $tempFull = [IO.Path]::GetFullPath($temp)
  if ($tempFull.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) { Remove-Item -LiteralPath $tempFull -Recurse -Force }
}
