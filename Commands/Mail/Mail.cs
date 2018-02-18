namespace Sezam.Commands
{
    [Command]
    public class Mail : CommandSet
    {
        public Mail(Session session)
           : base(session)
        {
        }

        [Command]
        public void Read()
        {
            throw new System.NotImplementedException("No Mail support yet");
        }
    }
}