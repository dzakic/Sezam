using System;

namespace Sezam.Web.Api.DTO
{
    public class StatusInfo
    {
        public string Status { get; set; } = "OK";
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        public DatabaseStatus Database { get; set; } = new DatabaseStatus();
        public DateTime? LastLogin { get; set; }
    }

    public class DatabaseStatus
    {
        public bool Connected { get; set; }
        public string? Error { get; set; }
    }
}
