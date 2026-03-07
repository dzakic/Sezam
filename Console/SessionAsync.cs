using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using Sezam.Console;
using Sezam.Data;
using Sezam.Data.EF;
using Sezam.Commands;

namespace Sezam
{
    /// <summary>
    /// Async variant of <see cref="Session"/>. Now that Session is fully async,
    /// this class just delegates to the base implementation. Kept for compatibility.
    /// </summary>
    public class SessionAsync : Session
    {
        public SessionAsync(ITerminal terminal) : base(terminal)
        {
        }

        /// <summary>
        /// Starts processing the connection. Delegates to base.Start().
        /// </summary>
        public Task RunAsync()
        {
            return Start();
        }
    }
}