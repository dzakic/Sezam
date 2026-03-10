using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace Sezam.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Conferences",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    Name = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: true),
                    VolumeNo = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    FromDate = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    ToDate = table.Column<DateTime>(type: "datetime(6)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Conferences", x => x.Id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MessageText",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    Text = table.Column<string>(type: "longtext", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MessageText", x => x.Id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    Username = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: true),
                    FullName = table.Column<string>(type: "varchar(32)", maxLength: 32, nullable: true),
                    StreetAddress = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: true),
                    PostCode = table.Column<string>(type: "varchar(6)", maxLength: 6, nullable: true),
                    City = table.Column<string>(type: "varchar(16)", maxLength: 16, nullable: true),
                    AreaCode = table.Column<string>(type: "varchar(6)", maxLength: 6, nullable: true),
                    Phone = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: true),
                    Company = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: true),
                    DateOfBirth = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    MemberSince = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    LastCall = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    PaidUntil = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    Password = table.Column<string>(type: "longtext", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ConfTopics",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    ConferenceId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false),
                    TopicNo = table.Column<int>(type: "int", nullable: false),
                    RedirectToId = table.Column<int>(type: "int", nullable: true),
                    Status = table.Column<int>(type: "int", nullable: false),
                    NextSequence = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConfTopics", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConfTopics_ConfTopics_RedirectToId",
                        column: x => x.RedirectToId,
                        principalTable: "ConfTopics",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ConfTopics_Conferences_ConferenceId",
                        column: x => x.ConferenceId,
                        principalTable: "Conferences",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "UserConf",
                columns: table => new
                {
                    UserId = table.Column<int>(type: "int", nullable: false),
                    ConferenceId = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserConf", x => new { x.UserId, x.ConferenceId });
                    table.ForeignKey(
                        name: "FK_UserConf_Conferences_ConferenceId",
                        column: x => x.ConferenceId,
                        principalTable: "Conferences",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserConf_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "UserTopic",
                columns: table => new
                {
                    UserId = table.Column<int>(type: "int", nullable: false),
                    TopicId = table.Column<int>(type: "int", nullable: false),
                    SeenMsgNo = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserTopic", x => new { x.UserId, x.TopicId });
                    table.ForeignKey(
                        name: "FK_UserTopic_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ConfMessages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    AuthorId = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    TopicId = table.Column<int>(type: "int", nullable: false),
                    MsgNo = table.Column<int>(type: "int", nullable: false),
                    ParentMessageId = table.Column<int>(type: "int", nullable: true),
                    Time = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Filename = table.Column<string>(type: "varchar(32)", maxLength: 32, nullable: true),
                    MessageTextId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConfMessages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConfMessages_ConfMessages_ParentMessageId",
                        column: x => x.ParentMessageId,
                        principalTable: "ConfMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ConfMessages_ConfTopics_TopicId",
                        column: x => x.TopicId,
                        principalTable: "ConfTopics",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ConfMessages_MessageText_MessageTextId",
                        column: x => x.MessageTextId,
                        principalTable: "MessageText",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ConfMessages_Users_AuthorId",
                        column: x => x.AuthorId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Conferences_Name_VolumeNo",
                table: "Conferences",
                columns: new[] { "Name", "VolumeNo" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_AuthorId_TopicId_MsgNo",
                table: "ConfMessages",
                columns: new[] { "AuthorId", "TopicId", "MsgNo" });

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_Filename",
                table: "ConfMessages",
                column: "Filename");

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_MessageTextId",
                table: "ConfMessages",
                column: "MessageTextId");

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_ParentMessageId",
                table: "ConfMessages",
                column: "ParentMessageId");

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_Time",
                table: "ConfMessages",
                column: "Time");

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_TopicId_AuthorId_MsgNo",
                table: "ConfMessages",
                columns: new[] { "TopicId", "AuthorId", "MsgNo" });

            migrationBuilder.CreateIndex(
                name: "IX_ConfMessages_TopicId_MsgNo",
                table: "ConfMessages",
                columns: new[] { "TopicId", "MsgNo" });

            migrationBuilder.CreateIndex(
                name: "IX_ConfTopics_ConferenceId_Name",
                table: "ConfTopics",
                columns: new[] { "ConferenceId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ConfTopics_ConferenceId_TopicNo",
                table: "ConfTopics",
                columns: new[] { "ConferenceId", "TopicNo" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ConfTopics_RedirectToId",
                table: "ConfTopics",
                column: "RedirectToId");

            migrationBuilder.CreateIndex(
                name: "IX_UserConf_ConferenceId",
                table: "UserConf",
                column: "ConferenceId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_LastCall",
                table: "Users",
                column: "LastCall");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Username",
                table: "Users",
                column: "Username",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ConfMessages");

            migrationBuilder.DropTable(
                name: "UserConf");

            migrationBuilder.DropTable(
                name: "UserTopic");

            migrationBuilder.DropTable(
                name: "ConfTopics");

            migrationBuilder.DropTable(
                name: "MessageText");

            migrationBuilder.DropTable(
                name: "Users");

            migrationBuilder.DropTable(
                name: "Conferences");
        }
    }
}
