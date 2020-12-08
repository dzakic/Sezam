using System;

namespace Sezam.Data
{
    public interface ISession
    {
        string GetUsername();

        DateTime GetLoginTime();
    }
}