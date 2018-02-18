using System;

namespace Sezam.Library
{
    public interface ISession
    {
        string getUsername();

        DateTime getLoginTime();
    }
}