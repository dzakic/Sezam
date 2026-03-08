using System;
using System.Threading.Tasks;

namespace Sezam.Data
{
    public interface ISession
    {
        string Username { get; }

        /// <summary>
        /// Gets the date and time when the connection was established.
        /// </summary>
        /// <remarks>This property provides the timestamp of the connection, which can be useful for
        /// logging and monitoring connection durations.</remarks>
        DateTime ConnectTime { get; }

        /// <summary>
        /// Gets the date and time when the user logged in.
        /// </summary>
        /// <remarks>This property provides the timestamp of the user's login, which can be useful for
        /// tracking user sessions or auditing purposes.</remarks>
        DateTime LoginTime { get; }

        /// <summary>
        /// Get Session Guid.  This is a unique identifier for the session that can be used 
        /// to track it across requests and manage its lifecycle.  The implementation should 
        /// ensure that the Guid is unique for each session and can be used to correlate 
        /// requests from the same session.
        /// </summary>
        /// <returns></returns>
        Guid Id { get; }

        /// <summary>
        /// Request that the session terminate and release its resources.  The
        /// implementation may be synchronous or asynchronous, but callers can
        /// invoke it without awaiting.
        /// </summary>
        void Close();

        /// <summary>
        /// Start the session.  This method is called after the session is created and 
        /// added to the session manager, but before it is used to handle any requests.  
        /// The implementation can perform any necessary initialization here, such as 
        /// setting up resources or starting background tasks.  The method can be synchronous 
        /// or asynchronous, but callers can invoke it without awaiting.  If the session 
        /// fails to start, it should throw an exception to indicate that it cannot be used.
        /// </summary>
        Task Start();
        void Broadcast(string from, string message);

    }
}