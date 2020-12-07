using System;

namespace Sezam.Library
{
    public interface ISession
    {
        string GetUsername();

        DateTime GetLoginTime();
    }
}