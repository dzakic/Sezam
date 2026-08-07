using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddPrivateMessage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PrivateMessages",
                columns: table => new
                {
                    Id = table.Column<byte[]>(type: "binary(16)", nullable: false),
                    SenderId = table.Column<int>(type: "int", nullable: false),
                    RecipientId = table.Column<int>(type: "int", nullable: false),
                    SentTime = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    ReadTime = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    MessageTextId = table.Column<byte[]>(type: "binary(16)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrivateMessages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PrivateMessages_MessageTexts_MessageTextId",
                        column: x => x.MessageTextId,
                        principalTable: "MessageTexts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PrivateMessages_Users_RecipientId",
                        column: x => x.RecipientId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PrivateMessages_Users_SenderId",
                        column: x => x.SenderId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_PrivateMessages_MessageTextId",
                table: "PrivateMessages",
                column: "MessageTextId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PrivateMessages_RecipientId_ReadTime",
                table: "PrivateMessages",
                columns: new[] { "RecipientId", "ReadTime" });

            migrationBuilder.CreateIndex(
                name: "IX_PrivateMessages_SenderId_SentTime",
                table: "PrivateMessages",
                columns: new[] { "SenderId", "SentTime" });

            migrationBuilder.CreateIndex(
                name: "IX_PrivateMessages_SentTime",
                table: "PrivateMessages",
                column: "SentTime");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PrivateMessages");
        }
    }
}
