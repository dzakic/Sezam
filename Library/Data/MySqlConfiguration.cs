namespace Sezam.Library
{
    using System.Data.Entity;

    public class MySqlConfiguration : DbConfiguration
   {
      public MySqlConfiguration()
      {
         SetHistoryContext("MySql.Data.MySqlClient", (conn, schema) => new MySqlHistoryContext(conn, schema));
      }
   }
}