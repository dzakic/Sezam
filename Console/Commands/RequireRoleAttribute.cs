using Sezam.Data.EF;
using System;

namespace Sezam.Commands
{
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = false)]
    public class RequireRoleAttribute : Attribute
    {
        public Role RequiredRole { get; }

        public RequireRoleAttribute(Role role)
        {
            RequiredRole = role;
        }
    }
}
