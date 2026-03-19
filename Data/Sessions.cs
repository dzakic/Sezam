using System;

namespace Sezam.Data
{
    public interface ISession
    {
        string Username { get; }

        /// <summary>
        /// Gets the date and time when the connection was established.
        /// </summary>
        DateTime ConnectTime { get; }

        /// <summary>
        /// Gets the date and time when the user logged in.
        /// </summary>
        DateTime LoginTime { get; }

        /// <summary>
        /// Unique identifier for the session, used to track it across nodes
        /// and manage its lifecycle.
        /// </summary>
        Guid Id { get; }

        /// <summary>
        /// Request that the session terminate and release its resources.
        /// </summary>
        void Close();

        /// <summary>
        /// Deliver a message to this session's terminal.
        /// Only meaningful for local sessions.
        /// </summary>
        void Deliver(string from, string to, string message);
    }
}