using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class UserTopic_SeenTime : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SeenMsgNo",
                table: "UserTopic");

            migrationBuilder.AddColumn<DateTime>(
                name: "SeenTime",
                table: "UserTopic",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SeenTime",
                table: "UserTopic");

            migrationBuilder.AddColumn<int>(
                name: "SeenMsgNo",
                table: "UserTopic",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }
    }
}
