namespace Sezam.Commands
{
    [Command]
    public class Mail : CommandSet
    {
        public Mail(Session session)
           : base(session)
        {
        }

        [Command(Description = "Read Mail")]
        public void Read()
        {
            throw new System.NotImplementedException("No Mail support yet");
        }
    }
}