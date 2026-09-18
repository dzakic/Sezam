using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddPrivateMessageGuidTail : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Emitted as raw SQL because the EF MySQL provider renders computed columns
            // incorrectly. MySQL 8.4 refuses to ADD a STORED generated column to an
            // existing table, but a VIRTUAL column can be added via ALTER. It is
            // auto-maintained and indexable, so the id lookup stays server-side.
            migrationBuilder.Sql(
                "ALTER TABLE `PrivateMessages` " +
                "ADD COLUMN `GuidTail` BINARY(2) " +
                "GENERATED ALWAYS AS (SUBSTRING(`Id`, 15)) VIRTUAL");

            migrationBuilder.CreateIndex(
                name: "IX_PrivateMessages_GuidTail",
                table: "PrivateMessages",
                column: "GuidTail");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PrivateMessages_GuidTail",
                table: "PrivateMessages");

            migrationBuilder.DropColumn(
                name: "GuidTail",
                table: "PrivateMessages");
        }
    }
}
