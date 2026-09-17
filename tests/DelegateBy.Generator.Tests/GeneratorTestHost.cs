using System.Collections.Immutable;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using DelegateBy;

namespace DelegateBy.Generator.Tests;

internal static class GeneratorTestHost
{
    private static readonly ImmutableArray<MetadataReference> References =
        ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
        .Split(Path.PathSeparator)
        .Select(path => MetadataReference.CreateFromFile(path))
        .ToImmutableArray<MetadataReference>();

    private static readonly MetadataReference AttributesReference =
        MetadataReference.CreateFromFile(typeof(DelegateByAttribute).Assembly.Location);

    internal static GeneratorResult Run(string source) => Run(source, LanguageVersion.Preview, false);

    internal static GeneratorResult RunCSharp9(string source) => Run(source, LanguageVersion.CSharp9, false);

    internal static GeneratorResult RunWithAttributesSymbol(string source) =>
        Run(source, LanguageVersion.Preview, true);

    private static GeneratorResult Run(string source, LanguageVersion languageVersion, bool keepAttributes)
    {
        var parseOptions = new CSharpParseOptions(
            languageVersion,
            preprocessorSymbols: keepAttributes ? new[] { "DELEGATEBY_ATTRIBUTES" } : null);
        var syntaxTree = CSharpSyntaxTree.ParseText(source, parseOptions);
        var compilation = CSharpCompilation.Create(
            "GeneratorTests",
            new[] { syntaxTree },
            References.Add(AttributesReference),
            new CSharpCompilationOptions(
                OutputKind.DynamicallyLinkedLibrary,
                nullableContextOptions: NullableContextOptions.Enable,
                allowUnsafe: true));

        GeneratorDriver driver = CSharpGeneratorDriver.Create(
            generators: new[] { new DelegateByGenerator().AsSourceGenerator() },
            parseOptions: parseOptions);
        driver = driver.RunGeneratorsAndUpdateCompilation(
            compilation,
            out var outputCompilation,
            out var generatorDiagnostics);

        var runResult = driver.GetRunResult();
        var generated = runResult.Results
            .SelectMany(result => result.GeneratedSources)
            .ToDictionary(
                sourceResult => sourceResult.HintName,
                sourceResult => sourceResult.SourceText.ToString(),
                StringComparer.Ordinal);

        return new GeneratorResult(
            outputCompilation,
            generatorDiagnostics.AddRange(runResult.Diagnostics),
            generated);
    }
}

internal sealed class GeneratorResult
{
    internal GeneratorResult(
        Compilation compilation,
        ImmutableArray<Diagnostic> generatorDiagnostics,
        IReadOnlyDictionary<string, string> generatedSources)
    {
        Compilation = compilation;
        GeneratorDiagnostics = generatorDiagnostics;
        GeneratedSources = generatedSources;
    }

    internal Compilation Compilation { get; }
    internal ImmutableArray<Diagnostic> GeneratorDiagnostics { get; }
    internal IReadOnlyDictionary<string, string> GeneratedSources { get; }

    internal string DelegationSource => GeneratedSources
        .Single(pair => pair.Key.EndsWith(".DelegateBy.g.cs", StringComparison.Ordinal))
        .Value;

    internal ImmutableArray<Diagnostic> Errors => Compilation.GetDiagnostics()
        .Concat(GeneratorDiagnostics)
        .Where(diagnostic => diagnostic.Severity == DiagnosticSeverity.Error)
        .Distinct(DiagnosticComparer.Instance)
        .ToImmutableArray();

    private sealed class DiagnosticComparer : IEqualityComparer<Diagnostic>
    {
        internal static readonly DiagnosticComparer Instance = new();

        public bool Equals(Diagnostic? x, Diagnostic? y) =>
            x?.Id == y?.Id && x?.Location.SourceSpan == y?.Location.SourceSpan;

        public int GetHashCode(Diagnostic diagnostic) =>
            HashCode.Combine(diagnostic.Id, diagnostic.Location.SourceSpan);
    }
}
