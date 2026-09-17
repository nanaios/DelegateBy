using System;

namespace DelegateBy
{
    /// <summary>Marks a partial class for interface delegation through a member.</summary>
    [System.Diagnostics.Conditional("DELEGATEBY_ATTRIBUTES")]
    [AttributeUsage(AttributeTargets.Class, AllowMultiple = true, Inherited = false)]
    public sealed class DelegateByAttribute : Attribute
    {
        /// <summary>Creates a delegation mapping for the named field or readable property.</summary>
        /// <param name="memberName">The delegate member name.</param>
        public DelegateByAttribute(string memberName) => MemberName = memberName;

        /// <summary>Gets the field or property that supplies the delegated interface.</summary>
        public string MemberName { get; }
    }
}
