# DelegateBy

DelegateBy adds Kotlin-style interface delegation to C# partial classes with an incremental source generator.

```csharp
using DelegateBy;

public interface IGreeter
{
    string Greet(string name);
}

[DelegateBy(nameof(_greeter))]
public partial class GreeterService
{
    private readonly IGreeter _greeter;

    public GreeterService(IGreeter greeter) => _greeter = greeter;
}
```

`GreeterService` receives generated forwarding members for `IGreeter`. The delegate target must be an instance field or readable instance property declared as an interface. The target class must be `partial`; nested containing types must also be `partial`.

## Requirements

- An SDK-style C# project.
- C# 9 or later.
- A supported .NET target framework.

## Install from NuGet

Add the GitHub Packages feed. GitHub requires authentication for NuGet downloads, including public packages:

```powershell
dotnet nuget add source --username YOUR_GITHUB_USERNAME --password YOUR_CLASSIC_PAT --store-password-in-clear-text --name github "https://nuget.pkg.github.com/nanaios/index.json"
dotnet add package DelegateBy --version 0.4.0 --source "https://nuget.pkg.github.com/nanaios/index.json"
```

The personal access token needs the `read:packages` scope.

## Install in Unity

DelegateBy 0.4.0 supports Unity 6 (`6000.0`) and later. In Package Manager, choose **Add package from git URL**:

```text
https://github.com/nanaios/DelegateBy.git#upm/v0.4.0
```

The release page also contains `com.nanaios.delegateby-0.4.0.tgz`, which can be added with **Add package from tarball**. The package provides the attributes and analyzer as precompiled DLLs. If an assembly definition enables **Override References**, add the package's precompiled `DelegateBy.Attributes.dll` to its Assembly References.

Do not install the NuGet and UPM distributions together in the same Unity project.
