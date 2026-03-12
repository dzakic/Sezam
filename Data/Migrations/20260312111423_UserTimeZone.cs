using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class UserTimeZone : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "TimeZoneId",
                table: "Users",
                type: "varchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "ConfTopics",
                type: "int",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int")
                .OldAnnotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn);

            migrationBuilder.AddUniqueConstraint(
                name: "AK_UserTopic_TopicId",
                table: "UserTopic",
                column: "TopicId");

            migrationBuilder.AddForeignKey(
                name: "FK_ConfTopics_UserTopic_Id",
                table: "ConfTopics",
                column: "Id",
                principalTable: "UserTopic",
                principalColumn: "TopicId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ConfTopics_UserTopic_Id",
                table: "ConfTopics");

            migrationBuilder.DropUniqueConstraint(
                name: "AK_UserTopic_TopicId",
                table: "UserTopic");

            migrationBuilder.DropColumn(
                name: "TimeZoneId",
                table: "Users");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "ConfTopics",
                type: "int",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int")
                .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn);
        }
    }
}
