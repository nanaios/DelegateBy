using DelegateBy;

var backend = new Greeter("Hello");
var service = new GreeterService(backend);

service.Greeted += (_, name) => Console.WriteLine($"Observed greeting for {name}");
Console.WriteLine(service.Greet("Codex"));
Console.WriteLine($"Count: {service.Count}");

public interface IGreeter
{
    int Count { get; }
    event EventHandler<string>? Greeted;
    string Greet(string name);
}

public sealed class Greeter : IGreeter
{
    private readonly string _prefix;

    public Greeter(string prefix) => _prefix = prefix;

    public int Count { get; private set; }
    public event EventHandler<string>? Greeted;

    public string Greet(string name)
    {
        Count++;
        Greeted?.Invoke(this, name);
        return $"{_prefix}, {name}!";
    }
}

[DelegateBy(nameof(_greeter))]
public partial class GreeterService
{
    private readonly IGreeter _greeter;

    public GreeterService(IGreeter greeter) => _greeter = greeter;
}
