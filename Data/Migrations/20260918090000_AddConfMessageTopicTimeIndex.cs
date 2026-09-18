using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddConfMessageTopicTimeIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Messages are now referenced by a 4-hex GUID moniker and MsgNo is an
            // optional selector, so messages are ordered chronologically by Time
            // instead of MsgNo. The composite (TopicId, Time) index scopes the
            // ordered scan to a single topic, making per-topic listings and the
            // web page pagination index range scans instead of filesorts.
            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_TopicId_Time",
                table: "ConfMessages",
                columns: new[] { "TopicId", "Time" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ConfMessages_TopicId_Time",
                table: "ConfMessages");
        }
    }
}
