# DelegateBy

`DelegateBy` brings Kotlin-style interface delegation to C# through an incremental source generator.

[![CI](https://github.com/nanaios/DelegateBy/actions/workflows/ci.yml/badge.svg)](https://github.com/nanaios/DelegateBy/actions/workflows/ci.yml)
[![GitHub package](https://img.shields.io/badge/GitHub%20Packages-DelegateBy-blue)](https://github.com/nanaios?tab=packages)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

```csharp
using DelegateBy;

[DelegateBy(nameof(_greeter))]
public partial class GreeterService
{
    private readonly IGreeter _greeter;

    public GreeterService(IGreeter greeter) => _greeter = greeter;
}
```

The generator infers `IGreeter` from the declared type of `_greeter`, adds it to the partial class, and forwards its instance members to `_greeter`. A compatible public member written on the class or inherited from its base class takes precedence over generated delegation. The delegate field or readable property must be declared as an interface type; unbound generic interfaces, concrete types, `object`, `dynamic`, and type parameters are rejected. Constructed generic interfaces such as `IService<T>` are supported. A nullable interface is accepted with a `DBY010` warning and is null-forgiven when forwarded.

## Requirements

- An SDK-style C# project
- A `partial` target class (and `partial` containing types when nested)
- An instance field or readable instance property assignable to the delegated interface

The generator targets `netstandard2.0` and is built against
`Microsoft.CodeAnalysis.CSharp` `4.3.0-3.final`. The supported language surface
is tested with C# 9 for Unity compatibility; `scoped` and
`ref readonly` parameters are outside the supported surface.

## Install from GitHub Packages

Add the GitHub Packages NuGet feed. GitHub currently requires authentication for NuGet package downloads, including public packages:

```powershell
dotnet nuget add source --username YOUR_GITHUB_USERNAME --password YOUR_CLASSIC_PAT --store-password-in-clear-text --name github "https://nuget.pkg.github.com/nanaios/index.json"
dotnet add package DelegateBy --version 0.3.0 --source github
```

The classic personal access token needs the `read:packages` scope.

## Build a local package

```powershell
dotnet pack src/DelegateBy.Generator/DelegateBy.Generator.csproj -c Release
```

Reference the resulting `DelegateBy` package normally. It contains the source
generator under `analyzers/dotnet/cs` and the attribute runtime assembly under
`lib/netstandard2.0`.

## Install in Unity

DelegateBy is distributed as a Unity Package Manager package for Unity 6
(`6000.0`) and later. In Package Manager, choose **Add package from git URL**:

```text
https://github.com/nanaios/DelegateBy.git#upm/v0.3.0
```

Release pages also contain `com.nanaios.delegateby-0.3.0.tgz`, which can be
added with **Add package from tarball**. The package includes the attributes
source and assembly definition in `Runtime`; the Roslyn analyzer is kept in
`Analyzers` and is labelled `RoslynAnalyzer` in its Unity metadata. If an
assembly definition is used by your project, reference
`DelegateBy.Attributes` from its `references` array.

Unity Editor and Player execution are not part of this repository's automated
tests, and this release has not been verified in Unity. CI checks .NET code
generation and package structure without launching Unity.

### Migrating from 0.2.x

Keep installing the single `DelegateBy` NuGet package and keep the same attribute
syntax. The public attribute now lives in `DelegateBy.Attributes` rather than
being injected by the generator, so the package is no longer analyzer-only.
Direct project references need both a normal reference to the attributes project
and an analyzer reference to the generator. Do not install both the UPM and NuGet
distributions in the same Unity project. `DELEGATEBY_ATTRIBUTES` still controls
whether attribute usages are retained in compiled metadata; generation works
with or without the symbol. OpenUPM distribution is not provided.

## Publishing a release

1. Prepare and test changes on `main`.
2. Open a pull request from `main` to `release`.
3. Set the pull request title to the exact SemVer package version, for example `0.3.0` or `0.3.0-beta.1`.
4. Merge the pull request.

The publish workflow validates the title, runs the .NET test suite, packs the
NuGet and UPM artifacts, validates both, publishes NuGet to GitHub Packages,
and completes a GitHub Release with both archives, keeping it as a draft until
publication succeeds. It also maintains the
`upm` branch and `upm/v<version>` tag for Git URL installation. Existing tags,
and release assets are checked for matching content before anything
is changed; a different artifact for an existing version fails the workflow.
Direct pushes to `release` do not publish packages.

## Ambiguous delegation

If two different delegate targets expose the same interface member signature, DelegateBy asks you to implement that member on the class. This makes the chosen behavior explicit rather than depending on attribute order.
