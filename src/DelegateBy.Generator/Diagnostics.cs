using Microsoft.CodeAnalysis;

namespace DelegateBy.Generator;

internal static class Diagnostics
{
    private const string Category = "DelegateBy";

    internal static readonly DiagnosticDescriptor PartialRequired = Create(
        "DBY001", "The delegated class must be partial",
        "Type '{0}' and every containing type must be declared partial");

    internal static readonly DiagnosticDescriptor InterfaceRequired = Create(
        "DBY002", "A closed interface type is required",
        "The delegate member type '{0}' must be a closed interface type");

    internal static readonly DiagnosticDescriptor DelegateNotFound = Create(
        "DBY003", "Delegate member was not found",
        "Type '{0}' does not contain an instance field or readable property named '{1}'");

    internal static readonly DiagnosticDescriptor InvalidDelegate = Create(
        "DBY004", "Delegate member is not usable",
        "Member '{0}' must be one unambiguous instance field or readable instance property");

    internal static readonly DiagnosticDescriptor IncompatibleDelegate = Create(
        "DBY005", "Delegate member has an incompatible type",
        "Member '{0}' of type '{1}' is not implicitly convertible to '{2}'");

    internal static readonly DiagnosticDescriptor DuplicateInterface = Create(
        "DBY006", "Interface is delegated more than once",
        "Interface '{0}' is assigned to more than one delegation attribute");

    internal static readonly DiagnosticDescriptor AmbiguousDelegation = Create(
        "DBY007", "Delegated member is ambiguous",
        "Member '{0}' is supplied by multiple delegate targets; add a compatible public implementation to '{1}'");

    internal static readonly DiagnosticDescriptor ExistingMemberMismatch = Create(
        "DBY008", "Existing member does not implement the interface contract",
        "Existing member '{0}' conflicts with '{1}' but does not satisfy its interface contract");

    internal static readonly DiagnosticDescriptor UnsupportedMember = Create(
        "DBY009", "Interface member requires a user implementation",
        "Member '{0}' cannot be delegated automatically; add a compatible implementation to '{1}'");

    internal static readonly DiagnosticDescriptor NullableInterface = new(
        "DBY010",
        "Nullable interface delegate",
        "Delegate member '{0}' is a nullable interface '{1}'; delegation will throw if it is null",
        Category,
        DiagnosticSeverity.Warning,
        isEnabledByDefault: true);

    private static DiagnosticDescriptor Create(string id, string title, string message) =>
        new(id, title, message, Category, DiagnosticSeverity.Error, isEnabledByDefault: true);
}
