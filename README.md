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

## Install from GitHub Packages

Add the GitHub Packages NuGet feed. GitHub currently requires authentication for NuGet package downloads, including public packages:

```powershell
dotnet nuget add source --username YOUR_GITHUB_USERNAME --password YOUR_CLASSIC_PAT --store-password-in-clear-text --name github "https://nuget.pkg.github.com/nanaios/index.json"
dotnet add package DelegateBy --version 0.2.0 --source github
```

The classic personal access token needs the `read:packages` scope.

## Build a local package

```powershell
dotnet pack src/DelegateBy.Generator/DelegateBy.Generator.csproj -c Release
```

Reference the resulting `DelegateBy` package normally. It contributes only an analyzer; no runtime assembly is required.

## Publishing a release

1. Prepare and test changes on `main`.
2. Open a pull request from `main` to `release`.
3. Set the pull request title to the exact SemVer package version, for example `0.2.0` or `0.2.0-beta.1`.
4. Merge the pull request.

The publish workflow validates the title, runs the test suite, packs that version, publishes it to GitHub Packages, and creates a matching `v<version>` tag and GitHub Release. Direct pushes to `release` do not publish packages.

## Ambiguous delegation

If two different delegate targets expose the same interface member signature, DelegateBy asks you to implement that member on the class. This makes the chosen behavior explicit rather than depending on attribute order.
