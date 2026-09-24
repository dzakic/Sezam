using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddConfMessageGuidTail : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Emitted as raw SQL because the EF MySQL provider renders computed columns
            // incorrectly (it can emit STORED, which MySQL 8.4 refuses to ADD to an
            // existing table). A VIRTUAL column can be added via ALTER; it is
            // auto-maintained and indexable, so the #hex id lookup stays server-side.
            // The composite (TopicId, GuidTail) index scopes the lookup to a topic.
            migrationBuilder.Sql(
                "ALTER TABLE `ConfMessages` " +
                "ADD COLUMN `GuidTail` BINARY(2) " +
                "GENERATED ALWAYS AS (SUBSTRING(`Id`, 15)) VIRTUAL");

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_TopicId_GuidTail",
                table: "ConfMessages",
                columns: new[] { "TopicId", "GuidTail" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ConfMessages_TopicId_GuidTail",
                table: "ConfMessages");

            migrationBuilder.DropColumn(
                name: "GuidTail",
                table: "ConfMessages");
        }
    }
}
