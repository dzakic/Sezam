using System;

namespace Sezam.Data.EF
{
    [Flags]
    public enum Role
    {
        User = 1,
        Superuser = 2
    }
}
