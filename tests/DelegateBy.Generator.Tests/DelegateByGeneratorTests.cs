using Microsoft.CodeAnalysis;
using Xunit;

namespace DelegateBy.Generator.Tests;

public sealed class DelegateByGeneratorTests
{
    [Fact]
    public void GeneratesRefReturnsOverloadsAndValueTasks()
    {
        const string source = """
            using System.Threading.Tasks;
            using DelegateBy;

            public interface IAdvanced
            {
                ref int Current { get; }
                ref int Get();
                int Get(int offset);
                ValueTask<string> LoadAsync();
            }

            public sealed class Advanced : IAdvanced
            {
                private int _value = 3;
                public ref int Current => ref _value;
                public ref int Get() => ref _value;
                public int Get(int offset) => _value + offset;
                public ValueTask<string> LoadAsync() => new("done");
            }

            [DelegateBy(nameof(_advanced))]
            public partial class Wrapper
            {
                private readonly IAdvanced _advanced = new Advanced();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.Contains("public ref int Current", result.DelegationSource);
        Assert.Contains("get => ref ((global::IAdvanced)this._advanced).Current;", result.DelegationSource);
        Assert.Contains("public ref int Get()", result.DelegationSource);
        Assert.Contains("public int Get(int offset)", result.DelegationSource);
        Assert.Contains("global::System.Threading.Tasks.ValueTask<string> LoadAsync()", result.DelegationSource);
        Assert.DoesNotContain("public async ", result.DelegationSource, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GeneratesMethodsPropertiesIndexersEventsAndInheritedDefaults()
    {
        const string source = """
            using System;
            using DelegateBy;

            public interface IBase
            {
                int Twice(int value) => value * 2;
            }

            public interface IWorker : IBase
            {
                string? Name { get; set; }
                int this[int index] { get; }
                event EventHandler? Changed;
                T Convert<T>(ref T value, out int count, string label = "x") where T : class, new();
            }

            public sealed class Worker : IWorker
            {
                public string? Name { get; set; }
                public int this[int index] => index;
                public event EventHandler? Changed;
                public T Convert<T>(ref T value, out int count, string label = "x") where T : class, new()
                {
                    count = label.Length;
                    Changed?.Invoke(this, EventArgs.Empty);
                    return value;
                }
            }

            [DelegateBy(nameof(_worker))]
            public partial class Service
            {
                private readonly IWorker _worker = new Worker();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.Contains("partial class Service : global::IWorker", result.DelegationSource);
        Assert.Contains("public string? Name", result.DelegationSource);
        Assert.Contains("public int this[int index]", result.DelegationSource);
        Assert.Contains("public event global::System.EventHandler? Changed", result.DelegationSource);
        Assert.True(result.DelegationSource.Contains("Convert<T>(ref T value"), result.DelegationSource);
        Assert.Contains("public int Twice(int value)", result.DelegationSource);
    }

    [Fact]
    public void CompatibleUserMemberOverridesDelegation()
    {
        const string source = """
            using DelegateBy;
            public interface IValue { int Get(); }
            public sealed class Value : IValue { public int Get() => 1; }

            [DelegateBy(nameof(_value))]
            public partial class Wrapper
            {
                private readonly IValue _value = new Value();
                public int Get() => 42;
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.DoesNotContain("public int Get()", result.DelegationSource);
        Assert.Contains("partial class Wrapper : global::IValue", result.DelegationSource);
    }

    [Fact]
    public void CompatibleBaseMemberOverridesDelegation()
    {
        const string source = """
            using DelegateBy;
            public interface IValue { int Get(); }
            public sealed class Value : IValue { public int Get() => 1; }
            public class Base { public int Get() => 7; }

            [DelegateBy(nameof(_value))]
            public partial class Wrapper : Base
            {
                private readonly IValue _value = new Value();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.DoesNotContain("public int Get()", result.DelegationSource);
    }

    [Fact]
    public void DifferentDelegateTargetsWithSameSignatureRequireUserImplementation()
    {
        const string source = """
            using DelegateBy;
            public interface ILeft { void Reset(); }
            public interface IRight { void Reset(); }
            public sealed class Left : ILeft { public void Reset() { } }
            public sealed class Right : IRight { public void Reset() { } }

            [DelegateBy(nameof(_left))]
            [DelegateBy(nameof(_right))]
            public partial class Wrapper
            {
                private readonly ILeft _left = new Left();
                private readonly IRight _right = new Right();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Contains(result.Errors, diagnostic => diagnostic.Id == "DBY007");
    }

    [Fact]
    public void UserImplementationResolvesDifferentDelegateTargetsWithSameSignature()
    {
        const string source = """
            using DelegateBy;
            public interface ILeft { void Reset(); }
            public interface IRight { void Reset(); }
            public sealed class Left : ILeft { public void Reset() { } }
            public sealed class Right : IRight { public void Reset() { } }

            [DelegateBy(nameof(_left))]
            [DelegateBy(nameof(_right))]
            public partial class Wrapper
            {
                private readonly ILeft _left = new Left();
                private readonly IRight _right = new Right();
                public void Reset() => _left.Reset();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
    }

    [Theory]
    [InlineData("public class Wrapper", "private readonly IFoo _foo = null!;", "DBY001")]
    [InlineData("public partial class Wrapper", "private readonly object _foo = new();", "DBY002")]
    [InlineData("public partial class Wrapper", "private IFoo Foo { set { } }", "DBY004")]
    public void ReportsInvalidTargetOrDelegate(string declaration, string member, string diagnosticId)
    {
        var source = $$"""
            using DelegateBy;
            public interface IFoo { void Run(); }
            [DelegateBy("{{(member.Contains("Foo") ? "Foo" : "_foo")}}")]
            {{declaration}}
            {
                {{member}}
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Contains(result.Errors, diagnostic => diagnostic.Id == diagnosticId);
    }

    [Fact]
    public void ReportsMissingDelegateAndDuplicateInterface()
    {
        const string missing = """
            using DelegateBy;
            public interface IFoo { void Run(); }
            [DelegateBy("missing")]
            public partial class Wrapper { }
            """;
        const string duplicate = """
            using DelegateBy;
            public interface IFoo { void Run(); }
            public sealed class Foo : IFoo { public void Run() { } }
            [DelegateBy(nameof(_one))]
            [DelegateBy(nameof(_two))]
            public partial class Wrapper
            {
                private readonly IFoo _one = new Foo();
                private readonly IFoo _two = new Foo();
            }
            """;

        Assert.Contains(GeneratorTestHost.Run(missing).Errors, diagnostic => diagnostic.Id == "DBY003");
        Assert.Contains(GeneratorTestHost.Run(duplicate).Errors, diagnostic => diagnostic.Id == "DBY006");
    }

    [Fact]
    public void ReportsExistingMemberWithIncompatibleVisibility()
    {
        const string source = """
            using DelegateBy;
            public interface IFoo { int Run(); }
            public sealed class Foo : IFoo { public int Run() => 1; }
            [DelegateBy(nameof(_foo))]
            public partial class Wrapper
            {
                private readonly IFoo _foo = new Foo();
                private int Run() => 2;
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Contains(result.Errors, diagnostic => diagnostic.Id == "DBY008");
    }

    [Fact]
    public void SupportsNestedGenericAndRecordClasses()
    {
        const string source = """
            using DelegateBy;
            public interface IFoo { string Run(); }
            public sealed class Foo : IFoo { public string Run() => "ok"; }

            public partial class Outer<T> where T : class
            {
                [DelegateBy(nameof(_foo))]
                public partial class Nested
                {
                    private readonly IFoo _foo = new Foo();
                }
            }

            [DelegateBy(nameof(_foo))]
            public partial record class RecordWrapper
            {
                private readonly IFoo _foo = new Foo();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.Equal(2, result.GeneratedSources.Keys.Count(key => key.EndsWith(".DelegateBy.g.cs", StringComparison.Ordinal)));
    }

    [Fact]
    public void StaticAbstractAndInitOnlyMembersRequireUserImplementations()
    {
        const string staticSource = """
            using DelegateBy;
            public interface IFoo { static abstract int Value { get; } }
            public sealed class Foo : IFoo { public static int Value => 1; }
            [DelegateBy(nameof(_foo))]
            public partial class Wrapper { private readonly IFoo _foo = new Foo(); }
            """;
        const string initSource = """
            using DelegateBy;
            public interface IFoo { string Name { get; init; } }
            public sealed class Foo : IFoo { public string Name { get; init; } = "x"; }
            [DelegateBy(nameof(_foo))]
            public partial class Wrapper { private readonly IFoo _foo = new Foo(); }
            """;

        Assert.Contains(GeneratorTestHost.Run(staticSource).Errors, diagnostic => diagnostic.Id == "DBY009");
        Assert.Contains(GeneratorTestHost.Run(initSource).Errors, diagnostic => diagnostic.Id == "DBY009");
    }

    [Fact]
    public void InfersInterfaceFromDelegateMemberAndSuppressesNullableAccess()
    {
        const string source = """
            using DelegateBy;
            public interface IFoo { int Run(); }
            public sealed class Foo : IFoo { public int Run() => 1; }

            [DelegateBy(nameof(_foo))]
            public partial class Wrapper
            {
                private readonly IFoo? _foo = new Foo();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.Contains(result.GeneratorDiagnostics, diagnostic => diagnostic.Id == "DBY010");
        Assert.Contains("partial class Wrapper : global::IFoo", result.DelegationSource);
        Assert.Contains("((global::IFoo)this._foo!).Run()", result.DelegationSource);
    }

    [Fact]
    public void InfersInterfaceFromReadableProperty()
    {
        const string source = """
            using DelegateBy;
            public interface IFoo { int Run(); }
            public sealed class Foo : IFoo { public int Run() => 1; }

            [DelegateBy(nameof(Foo))]
            public partial class Wrapper
            {
                public IFoo Foo { get; } = new Foo();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.Contains("partial class Wrapper : global::IFoo", result.DelegationSource);
        Assert.Contains("this.Foo).Run()", result.DelegationSource);
    }

    [Fact]
    public void InfersConstructedGenericInterfaceContainingTypeParameter()
    {
        const string source = """
            using DelegateBy;
            public interface IService<T> { T Get(T value); }
            public sealed class Service<T> : IService<T> { public T Get(T value) => value; }

            [DelegateBy(nameof(_service))]
            public partial class Wrapper<T>
            {
                private readonly IService<T> _service = new Service<T>();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Empty(result.Errors);
        Assert.Contains("partial class Wrapper<T> : global::IService<T>", result.DelegationSource);
    }

    [Theory]
    [InlineData("private readonly Foo _foo = new();")]
    [InlineData("private readonly object _foo = new();")]
    [InlineData("private readonly dynamic _foo = new object();")]
    [InlineData("private readonly T _foo;\n                public Wrapper(T foo) => _foo = foo;")]
    public void ReportsNonInterfaceDelegateTypes(string member)
    {
        var source = $$"""
            using DelegateBy;
            public interface IFoo { void Run(); }
            public sealed class Foo : IFoo { public void Run() { } }
            [DelegateBy(nameof(_foo))]
            public partial class Wrapper{{(member.Contains(" T ") ? "<T>" : "")}}
            {
                {{member}}
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Contains(result.Errors, diagnostic => diagnostic.Id == "DBY002");
    }

    [Fact]
    public void RejectsTheRemovedTwoArgumentAttributeSyntax()
    {
        const string source = """
            using DelegateBy;
            public interface IFoo { void Run(); }
            public sealed class Foo : IFoo { public void Run() { } }
            [DelegateBy(typeof(IFoo), nameof(_foo))]
            public partial class Wrapper
            {
                private readonly IFoo _foo = new Foo();
            }
            """;

        var result = GeneratorTestHost.Run(source);

        Assert.Contains(result.Errors, diagnostic => diagnostic.Id == "CS1729");
        Assert.DoesNotContain(result.GeneratedSources.Keys,
            key => key.EndsWith(".DelegateBy.g.cs", StringComparison.Ordinal));
    }
}
