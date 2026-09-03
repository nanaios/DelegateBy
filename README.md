# DelegateBy

`DelegateBy` brings Kotlin-style interface delegation to C# through an incremental source generator.

```csharp
using DelegateBy;

[DelegateBy(typeof(IGreeter), nameof(_greeter))]
public partial class GreeterService
{
    private readonly IGreeter _greeter;

    public GreeterService(IGreeter greeter) => _greeter = greeter;
}
```

The generator adds `IGreeter` to the partial class and forwards its instance members to `_greeter`. A compatible public member written on the class or inherited from its base class takes precedence over generated delegation.

## Requirements

- An SDK-style C# project
- A `partial` target class (and `partial` containing types when nested)
- An instance field or readable instance property assignable to the delegated interface

## Install from a local build

```powershell
dotnet pack src/DelegateBy.Generator/DelegateBy.Generator.csproj -c Release
```

Reference the resulting `DelegateBy` package normally. It contributes only an analyzer; no runtime assembly is required.

## Ambiguous delegation

If two different delegate targets expose the same interface member signature, DelegateBy asks you to implement that member on the class. This makes the chosen behavior explicit rather than depending on attribute order.
