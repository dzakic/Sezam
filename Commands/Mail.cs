namespace Sezam.Commands
{
   [Command]
   public class Mail : CommandProcessor
   {
      public Mail(Session session)
         : base(session)
      {
      }

      [Command]
      public void Read()
      {
      }
   }
}