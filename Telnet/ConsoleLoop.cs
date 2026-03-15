using System.Threading.Tasks;

namespace Sezam
{
    class ConsoleLoop(Server server)
    {
        /// <summary>Returns true if ESC was pressed (shutdown requested).</summary>
        public Task<bool> RunAsync() => Task.Run(Loop);

        private bool Loop()
        {
            while (System.Console.WindowHeight + System.Console.WindowWidth > 0)
            {
                if (!server.RunConsoleSession())
                    return true;
            }
            return false;
        }
    }
}
