using System;

namespace Sezam.Data
{
    public interface ISession
    {
        string GetUsername();

        DateTime GetLoginTime();

        /// <summary>
        /// Request that the session terminate and release its resources.  The
        /// implementation may be synchronous or asynchronous, but callers can
        /// invoke it without awaiting.
        /// </summary>
        void Close();
    }
}